#!/bin/bash
set -euo pipefail

# --- macOS DMG Installer Builder ---
# Packages Aferapokitaysky.app into a styled .dmg with Applications shortcut.

echo -e "\033[1;36m====================================================\033[0m"
echo -e "\033[1;35m  BUILDING AFERAPOKITAYSKY MAC-OS DMG INSTALLER  \033[0m"
echo -e "\033[1;36m====================================================\033[0m"

APP_PATH="Aferapokitaysky.app"
DMG_NAME="Aferapokitaysky.dmg"
VOL_NAME="Aferapokitaysky"
TMP_DMG="tmp_pack.dmg"

# Check if App bundle exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "\033[0;31mError: $APP_PATH not found. Please run ./build.sh first.\033[0m"
    exit 1
fi

echo -e "\033[0;33mEjecting any conflicting volumes...\033[0m"
hdiutil detach "/Volumes/$VOL_NAME" -force || true

echo -e "\033[0;33mCleaning old build outputs...\033[0m"
rm -f "$DMG_NAME" "$TMP_DMG"
rm -rf dmg_temp
mkdir -p dmg_temp

echo -e "\033[0;33mPreparing installer files and generating background...\033[0m"
python3 scratch/generate_background.py
mkdir -p dmg_temp/.background
cp docs/dmg_background.png dmg_temp/.background/background.png
cp -R "$APP_PATH" dmg_temp/
ln -s /Applications dmg_temp/Applications

# Create raw writable DMG
echo -e "\033[0;33mCreating temporary writable image...\033[0m"
hdiutil create -size 30m -fs HFS+ -volname "$VOL_NAME" -ov "$TMP_DMG"

# Mount the temporary image
echo -e "\033[0;33mMounting image...\033[0m"
MOUNT_DIR="/Volumes/$VOL_NAME"
hdiutil attach -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" "$TMP_DMG"

echo -e "\033[0;33mCopying files to volume...\033[0m"
cp -R dmg_temp/. "$MOUNT_DIR/"

# Finder styling script via AppleScript
echo -e "\033[0;33mStyling DMG window layout with AppleScript...\033[0m"
sleep 2

osascript <<EOF || true
tell application "Finder"
    tell disk "$VOL_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        
        -- Window bounds: {left, top, right, bottom} (width: 540, height: 360)
        set the bounds of container window to {400, 200, 940, 560}
        
        set icon size of the icon view options of container window to 80
        set arrangement of the icon view options of container window to not arranged
        
        -- Set background picture
        set background picture of icon view options of container window to file ".background:background.png"
        
        -- Icon positioning coordinates
        set position of item "Aferapokitaysky.app" to {140, 150}
        set position of item "Applications" to {400, 150}
        
        close
    end tell
end tell
EOF

echo -e "\033[0;33mClosing Finder window and cooling down...\033[0m"
osascript -e 'tell application "Finder" to close every window of disk "'"$VOL_NAME"'"' || true
sleep 4

# Unmount volume
echo -e "\033[0;33mFinalizing and detaching image...\033[0m"
hdiutil detach -force "$MOUNT_DIR" || diskutil unmountDisk force "$MOUNT_DIR" || true

# Convert to read-only UDZO compressed format
echo -e "\033[0;33mConverting to compressed DMG: $DMG_NAME...\033[0m"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

# Clean up
echo -e "\033[0;33mCleaning up temporary directories...\033[0m"
rm -f "$TMP_DMG"
rm -rf dmg_temp

echo -e "\033[1;32m====================================================\033[0m"
echo -e "\033[1;32m  DMG CREATED SUCCESSFULLY: ./$DMG_NAME\033[0m"
echo -e "\033[1;32m====================================================\033[0m"
