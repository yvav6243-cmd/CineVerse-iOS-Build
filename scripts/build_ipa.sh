#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CineVerse — Automated Release arm64 IPA Builder (macOS / Xcode)
# Supports:
#   1. Sideloadly / AltStore unsigned Release arm64 IPA (default: --sideload)
#   2. Signed Release arm64 IPA via Apple Development / Ad Hoc / Distribution
#      Usage: ./scripts/build_ipa.sh --signed <TEAM_ID> [development|ad-hoc|app-store]
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

MODE="${1:---sideload}"
TEAM_ID="${2:-}"
EXPORT_METHOD="${3:-development}"

BUILD_DIR="$ROOT_DIR/build"
RELEASES_DIR="$ROOT_DIR/Releases"
DERIVED_DATA="$BUILD_DIR/DerivedData"
ARCHIVE_PATH="$BUILD_DIR/CineVerse.xcarchive"
PAYLOAD_DIR="$BUILD_DIR/Payload"
IPA_OUTPUT="$RELEASES_DIR/CineVerse.ipa"
ROOT_IPA_OUTPUT="$ROOT_DIR/CineVerse.ipa"

mkdir -p "$BUILD_DIR" "$RELEASES_DIR"

if command -v xcodegen >/dev/null 2>&1; then
    echo "==> Generating Xcode project via XcodeGen..."
    xcodegen generate
fi

if [[ "$MODE" == "--sideload" ]]; then
    echo "==> Building Release arm64 CineVerse.app for Sideloadly / AltStore..."
    xcodebuild \
        -project CineVerse.xcodeproj \
        -scheme CineVerse \
        -configuration Release \
        -sdk iphoneos \
        -derivedDataPath "$DERIVED_DATA" \
        ARCHS="arm64" \
        ONLY_ACTIVE_ARCH=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGN_ENTITLEMENTS="CineVerse/Resources/CineVerse-Sideload.entitlements" \
        clean build

    APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/CineVerse.app"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "ERROR: Built CineVerse.app not found at $APP_PATH"
        exit 1
    fi

    # Remove embedded PlugIns (.appex) for Sideloadly/AltStore free Apple ID compatibility
    rm -rf "$APP_PATH/PlugIns"

    # Ad-hoc pseudo-sign Mach-O binary so iOS & Sideloadly/AltStore inspect a valid signature blob
    if command -v codesign >/dev/null 2>&1; then
        codesign --force --sign - --timestamp=none "$APP_PATH" || true
    fi

    rm -rf "$PAYLOAD_DIR" "$IPA_OUTPUT"
    mkdir -p "$PAYLOAD_DIR"
    cp -R "$APP_PATH" "$PAYLOAD_DIR/CineVerse.app"

    echo "==> Packaging Payload/CineVerse.app into Releases/CineVerse.ipa..."
    (cd "$BUILD_DIR" && zip -qry "$IPA_OUTPUT" Payload)
    rm -rf "$PAYLOAD_DIR"

elif [[ "$MODE" == "--signed" ]]; then
    if [[ -z "$TEAM_ID" ]]; then
        echo "ERROR: TEAM_ID is required for --signed mode."
        echo "Usage: ./scripts/build_ipa.sh --signed <TEAM_ID> [development|ad-hoc|app-store]"
        exit 1
    fi

    case "$EXPORT_METHOD" in
        ad-hoc)
            EXPORT_PLIST="$ROOT_DIR/Config/ExportOptions-AdHoc.plist"
            ;;
        app-store)
            EXPORT_PLIST="$ROOT_DIR/Config/ExportOptions-AppStore.plist"
            ;;
        *)
            EXPORT_PLIST="$ROOT_DIR/Config/ExportOptions-Development.plist"
            ;;
    esac

    echo "==> Archiving signed Release arm64 CineVerse with Team ID $TEAM_ID ($EXPORT_METHOD)..."
    rm -rf "$ARCHIVE_PATH"
    xcodebuild \
        -project CineVerse.xcodeproj \
        -scheme CineVerse \
        -configuration Release \
        -sdk iphoneos \
        -archivePath "$ARCHIVE_PATH" \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        CODE_SIGN_STYLE=Automatic \
        -allowProvisioningUpdates \
        clean archive

    echo "==> Exporting signed IPA..."
    EXPORT_DIR="$BUILD_DIR/Export"
    rm -rf "$EXPORT_DIR"
    xcodebuild \
        -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist "$EXPORT_PLIST" \
        -allowProvisioningUpdates

    cp "$EXPORT_DIR/CineVerse.ipa" "$IPA_OUTPUT"
else
    echo "Unknown mode: $MODE (expected --sideload or --signed)"
    exit 1
fi

echo "==> Running IPA verification checks..."
bash "$ROOT_DIR/scripts/verify_ipa.sh" "$IPA_OUTPUT"
cp "$IPA_OUTPUT" "$ROOT_IPA_OUTPUT"

echo "==> SUCCESS: Ready-to-install IPA saved at:"
echo "    - $ROOT_IPA_OUTPUT"
echo "    - $IPA_OUTPUT"
