# ==============================================================================
# CineVerse — Автоматическая облачная сборка CineVerse.ipa на Windows (без Git и без Mac)
# Скрипт через официальный GitHub API создаёт приватный репозиторий в вашем аккаунте,
# запускает облачный macOS-15 с Xcode, компилирует arm64 Release-сборку и
# скачивает готовый CineVerse.ipa на Рабочий стол, в корень проекта и в Releases/.
# ==============================================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "  CineVerse iOS (arm64) — Автосборка CineVerse.ipa для Sideloadly" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan

$token = $env:GH_BUILD_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host ""
    Write-Host "Для запуска нужен бесплатный GitHub Personal Access Token (Classic)"
    Write-Host "с галочками 'repo' и 'workflow':"
    Write-Host "  https://github.com/settings/tokens/new?scopes=repo,workflow&description=CineVerseBuilder" -ForegroundColor Cyan
    Write-Host ""
    $token = Read-Host "Вставьте ваш GitHub Token (ghp_...)"
}
$token = $token.Trim()
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Токен не введён. Выход." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization"        = "Bearer $token"
    "Accept"               = "application/vnd.github+json"
    "User-Agent"           = "CineVerse-Windows-IPA-Builder"
    "X-GitHub-Api-Version" = "2022-11-28"
}

function Get-GitBlobSha1([byte[]]$bytes) {
    $header = [System.Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $combined = New-Object byte[] ($header.Length + $bytes.Length)
    [Buffer]::BlockCopy($header, 0, $combined, 0, $header.Length)
    [Buffer]::BlockCopy($bytes, 0, $combined, $header.Length, $bytes.Length)
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    $hash = $sha1.ComputeHash($combined)
    return (-join ($hash | ForEach-Object { $_.ToString("x2") }))
}

Write-Host "[1/5] Проверка аккаунта GitHub..." -ForegroundColor Cyan
$user = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers $headers -Method Get
$owner = $user.login
$repoName = "CineVerse-iOS-Build"
Write-Host "      Авторизован как: $owner" -ForegroundColor Green

Write-Host "[2/5] Подготовка приватного репозитория $owner/$repoName..." -ForegroundColor Cyan
try {
    $repo = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName" -Headers $headers -Method Get
} catch {
    $body = @{
        name        = $repoName
        private     = $true
        auto_init   = $true
        description = "CineVerse iOS arm64 IPA cloud builder"
    } | ConvertTo-Json
    $repo = Invoke-RestMethod -Uri "https://api.github.com/user/repos" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    Start-Sleep -Seconds 3
}

$defaultBranch = if ($repo.default_branch) { $repo.default_branch } else { "main" }
$ref = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/git/ref/heads/$defaultBranch" -Headers $headers -Method Get
$baseCommitSha = $ref.object.sha
$baseCommit = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/git/commits/$baseCommitSha" -Headers $headers -Method Get

# Load existing tree to skip unchanged blobs on incremental rebuilds
$existingBlobs = @{}
try {
    $remoteTree = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/git/trees/$($baseCommit.tree.sha)?recursive=1" -Headers $headers -Method Get
    foreach ($entry in $remoteTree.tree) {
        if ($entry.type -eq "blob") {
            $existingBlobs[$entry.path] = $entry.sha
        }
    }
} catch {}

Write-Host "[3/5] Синхронизация исходников CineVerse с облачным сборщиком..." -ForegroundColor Cyan
$includeDirs = @("CineVerse", "Shared", "CineVerseWidgets", "CineVerseTests", "Config", "scripts", ".github", "CineVerse.xcodeproj")
$includeRootFiles = @("project.yml", "codemagic.yaml", "README.md", "SECURITY.md", ".gitignore")

$allFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($d in $includeDirs) {
    $dirPath = Join-Path $root $d
    if (Test-Path $dirPath) {
        Get-ChildItem -Path $dirPath -Recurse -File | ForEach-Object { $allFiles.Add($_) }
    }
}
foreach ($rf in $includeRootFiles) {
    $fp = Join-Path $root $rf
    if (Test-Path $fp) { $allFiles.Add((Get-Item $fp)) }
}

$treeEntries = [System.Collections.Generic.List[object]]::new()
$uploadedCount = 0
$reusedCount = 0
$binaryExts = @(".png", ".jpg", ".jpeg", ".ico", ".icns", ".pdf", ".zip", ".mp4")

foreach ($file in $allFiles) {
    $relPath = $file.FullName.Substring($root.Length + 1).Replace('\', '/')
    if ($relPath -like "*Secrets.xcconfig*") { continue }
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    $ext = $file.Extension.ToLowerInvariant()
    $isBinary = $binaryExts -contains $ext
    if (-not $isBinary -and $relPath -like "scripts/*.sh") {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes).Replace("`r`n", "`n")
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($text)
    }
    $localSha = Get-GitBlobSha1 $bytes
    $mode = if ($relPath -like "scripts/*.sh") { "100755" } else { "100644" }

    if ($existingBlobs.ContainsKey($relPath) -and $existingBlobs[$relPath] -eq $localSha) {
        $treeEntries.Add(@{
            path = $relPath
            mode = $mode
            type = "blob"
            sha  = $localSha
        })
        $reusedCount++
    } elseif ($isBinary) {
        $b64 = [Convert]::ToBase64String($bytes)
        $blobBody = @{ content = $b64; encoding = "base64" } | ConvertTo-Json
        $blob = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/git/blobs" -Headers $headers -Method Post -Body $blobBody -ContentType "application/json"
        $treeEntries.Add(@{
            path = $relPath
            mode = $mode
            type = "blob"
            sha  = $blob.sha
        })
        $uploadedCount++
    } else {
        $utf8Text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $treeEntries.Add(@{
            path    = $relPath
            mode    = $mode
            type    = "blob"
            content = $utf8Text
        })
        $uploadedCount++
    }
}
Write-Host "      Подготовлено к коммиту: новых/изменённых $uploadedCount, без изменений $reusedCount (всего $($treeEntries.Count))." -ForegroundColor Green

$treeBody = @{
    tree = $treeEntries
} | ConvertTo-Json -Depth 6 -Compress
$treeBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($treeBody)
$newTree = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/git/trees" -Headers $headers -Method Post -Body $treeBytes -ContentType "application/json; charset=utf-8"

$commitBody = @{
    message = "Build CineVerse arm64 IPA ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
    tree    = $newTree.sha
    parents = @($baseCommitSha)
} | ConvertTo-Json
$newCommit = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/git/commits" -Headers $headers -Method Post -Body $commitBody -ContentType "application/json"

$updateRefBody = @{ sha = $newCommit.sha; force = $true } | ConvertTo-Json
Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/git/refs/heads/$defaultBranch" -Headers $headers -Method Patch -Body $updateRefBody -ContentType "application/json" | Out-Null

Write-Host "[4/5] Запуск workflow сборки Xcode (macos-15) в GitHub Actions (commit $($newCommit.sha.Substring(0,8)))..." -ForegroundColor Cyan
Start-Sleep -Seconds 3
$dispatchBody = @{ ref = $defaultBranch } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/actions/workflows/build-ipa.yml/dispatches" -Headers $headers -Method Post -Body $dispatchBody -ContentType "application/json" | Out-Null
} catch {
    Write-Host "      Примечание при dispatch: $($_.Exception.Message)" -ForegroundColor Yellow
}
Start-Sleep -Seconds 5

$artifactId = $null
$runId = $null
for ($attempt = 1; $attempt -le 72; $attempt++) {
    $runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/actions/runs?per_page=10" -Headers $headers -Method Get
    $latestRun = $runs.workflow_runs | Where-Object { $_.head_sha -eq $newCommit.sha } | Select-Object -First 1
    if ($latestRun) {
        $runId = $latestRun.id
        Write-Host ("      Статус: {0} / {1} (проверка {2}/72)" -f $latestRun.status, $latestRun.conclusion, $attempt)
        if ($latestRun.status -eq "completed") {
            if ($latestRun.conclusion -eq "success") {
                $arts = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/actions/runs/$($latestRun.id)/artifacts" -Headers $headers -Method Get
                $ipaArt = $arts.artifacts | Where-Object { $_.name -eq "CineVerse-iOS-arm64-IPA" } | Select-Object -First 1
                if ($ipaArt) {
                    $artifactId = $ipaArt.id
                    break
                }
            } else {
                Write-Host "Сборка завершилась со статусом '$($latestRun.conclusion)'. Загружаем лог ошибок..." -ForegroundColor Red
                New-Item -ItemType Directory -Force -Path (Join-Path $root "build") | Out-Null
                $jobs = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/actions/runs/$($latestRun.id)/jobs" -Headers $headers -Method Get
                foreach ($job in $jobs.jobs) {
                    $logFile = Join-Path $root "build\ci_job_$($job.id).log"
                    try {
                        $logUrl = "https://api.github.com/repos/$owner/$repoName/actions/jobs/$($job.id)/logs"
                        $req = [System.Net.HttpWebRequest]::Create($logUrl)
                        $req.Method = "GET"
                        $req.AllowAutoRedirect = $false
                        $req.UserAgent = "CineVerse-Windows-IPA-Builder"
                        $req.Headers.Add("Authorization", "Bearer $token")
                        $req.Accept = "application/vnd.github+json"
                        $resp = $req.GetResponse()
                        $redirectUrl = $resp.Headers["Location"]
                        $resp.Close()
                        if ($redirectUrl) {
                            Invoke-WebRequest -Uri $redirectUrl -OutFile $logFile
                        }
                    } catch {
                        Invoke-WebRequest -Uri "https://api.github.com/repos/$owner/$repoName/actions/jobs/$($job.id)/logs" -Headers $headers -OutFile $logFile
                    }
                    Write-Host "=== ОШИБКИ ИЗ ЛОГА ($logFile) ===" -ForegroundColor Yellow
                    Select-String -Path $logFile -Pattern 'error:|FAIL:|BUILD FAILED|fatal error' | Select-Object -First 60 | ForEach-Object { Write-Host $_.Line }
                }
                exit 1
            }
        }
    } else {
        Write-Host "      Ожидание старта workflow (проверка $attempt/72)..."
    }
    Start-Sleep -Seconds 10
}

if (-not $artifactId) {
    Write-Host "Превышено время ожидания сборки (Run ID: $runId)." -ForegroundColor Red
    exit 1
}

Write-Host "[5/5] Скачивание готового CineVerse.ipa..." -ForegroundColor Cyan
$zipOut = Join-Path $root "CineVerse-Artifact.zip"
$artUrl = "https://api.github.com/repos/$owner/$repoName/actions/artifacts/$artifactId/zip"
$artReq = [System.Net.HttpWebRequest]::Create($artUrl)
$artReq.Method = "GET"
$artReq.AllowAutoRedirect = $false
$artReq.UserAgent = "CineVerse-Windows-IPA-Builder"
$artReq.Headers.Add("Authorization", "Bearer $token")
$artReq.Accept = "application/vnd.github+json"
$artResp = $artReq.GetResponse()
$artRedirect = $artResp.Headers["Location"]
$artResp.Close()
if ($artRedirect) {
    Invoke-WebRequest -Uri $artRedirect -OutFile $zipOut
} else {
    Invoke-WebRequest -Uri $artUrl -Headers $headers -OutFile $zipOut
}

$extractDir = Join-Path $root "build\artifact_extract"
if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $zipOut -DestinationPath $extractDir -Force
Remove-Item $zipOut -Force

$downloadedIpa = Get-ChildItem -Path $extractDir -Recurse -Filter "CineVerse.ipa" | Select-Object -First 1
if ($downloadedIpa) {
    $desktopPath = Join-Path (Split-Path -Parent $root) "CineVerse.ipa"
    Copy-Item $downloadedIpa.FullName -Destination (Join-Path $root "CineVerse.ipa") -Force
    Copy-Item $downloadedIpa.FullName -Destination (Join-Path $root "Releases\CineVerse.ipa") -Force
    Copy-Item $downloadedIpa.FullName -Destination $desktopPath -Force
    Remove-Item $extractDir -Recurse -Force
    $sizeMB = [math]::Round((Get-Item $desktopPath).Length / 1MB, 2)
    Write-Host ""
    Write-Host "==================================================================" -ForegroundColor Green
    Write-Host "  ГОТОВО! Настоящий CineVerse.ipa ($sizeMB MB) сохранён в 3 места:" -ForegroundColor Green
    Write-Host "  1) На Рабочий стол: $desktopPath" -ForegroundColor White
    Write-Host "  2) В корень папки:  $root\CineVerse.ipa" -ForegroundColor White
    Write-Host "  3) В Releases:      $root\Releases\CineVerse.ipa" -ForegroundColor White
    Write-Host "  Теперь перетащите CineVerse.ipa в окно Sideloadly и нажмите Start!" -ForegroundColor Green
    Write-Host "==================================================================" -ForegroundColor Green
} else {
    Write-Host "Не удалось найти CineVerse.ipa внутри артефакта." -ForegroundColor Red
    exit 1
}
