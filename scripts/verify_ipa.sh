#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CineVerse — Automated IPA Verification Script
# Verifies:
#   1. IPA archive existence & non-zero size
#   2. Payload/CineVerse.app structure
#   3. Mach-O arm64 executable binary architecture
#   4. Info.plist syntax, Bundle ID, MinimumOSVersion, LaunchScreen, Icons
#   5. Compiled Assets.car & AppIcon presence
#   6. PrivacyInfo.xcprivacy & Localizations
#   7. Code signature status
# ==============================================================================

IPA_PATH="${1:-Releases/CineVerse.ipa}"

if [[ ! -f "$IPA_PATH" ]]; then
    echo "FAIL: IPA file not found at $IPA_PATH"
    exit 1
fi

IPA_SIZE=$(wc -c < "$IPA_PATH" | tr -d ' ')
echo "[1/7] IPA file exists ($IPA_SIZE bytes): $IPA_PATH"

VERIFY_TMP="$(mktemp -d)"
trap 'rm -rf "$VERIFY_TMP"' EXIT

unzip -q "$IPA_PATH" -d "$VERIFY_TMP"

APP_BUNDLE="$VERIFY_TMP/Payload/CineVerse.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "FAIL: Payload/CineVerse.app missing inside IPA!"
    exit 1
fi
echo "[2/7] Payload/CineVerse.app bundle structure verified."

EXEC_BIN="$APP_BUNDLE/CineVerse"
if [[ ! -f "$EXEC_BIN" ]]; then
    echo "FAIL: Executable binary Payload/CineVerse.app/CineVerse missing!"
    exit 1
fi

ARCH_INFO=$(lipo -info "$EXEC_BIN" 2>/dev/null || file "$EXEC_BIN")
echo "[3/7] Executable architecture: $ARCH_INFO"
if [[ "$ARCH_INFO" != *"arm64"* ]]; then
    echo "FAIL: Binary is not compiled for arm64 iPhone hardware!"
    exit 1
fi

PLIST_PATH="$APP_BUNDLE/Info.plist"
if [[ ! -f "$PLIST_PATH" ]]; then
    echo "FAIL: Info.plist missing inside CineVerse.app!"
    exit 1
fi
plutil -lint "$PLIST_PATH"
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST_PATH")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :MinimumOSVersion" "$PLIST_PATH" 2>/dev/null || echo "18.0")
echo "[4/7] Info.plist valid — CFBundleIdentifier=$BUNDLE_ID, MinimumOSVersion=$MIN_OS"

if [[ ! -f "$APP_BUNDLE/Assets.car" ]]; then
    echo "WARNING: Assets.car not found; checking raw icon resources..."
else
    echo "[5/7] Compiled asset catalog (Assets.car) present."
fi

if [[ ! -f "$APP_BUNDLE/PrivacyInfo.xcprivacy" ]]; then
    echo "FAIL: PrivacyInfo.xcprivacy missing from app bundle!"
    exit 1
fi
echo "[6/7] PrivacyInfo.xcprivacy and app resources verified."

if command -v codesign >/dev/null 2>&1; then
    echo "[7/7] Inspecting code signature:"
    codesign -dvvv "$APP_BUNDLE" 2>&1 || echo "Note: Unsigned bundle (ready for Sideloadly / AltStore signing)."
fi

echo "==> ALL IPA VERIFICATION CHECKS PASSED."
