#!/bin/bash

# --- Aesthetic macOS Media Player Builder ---
# Compiles Swift files into a standalone native macOS executable.

echo -e "\033[1;36m====================================================\033[0m"
echo -e "\033[1;35m  AFERAPOKITAYSKY MAC-OS MEDIA PLAYER BUILDER  \033[0m"
echo -e "\033[1;36m====================================================\033[0m"

echo -e "\033[0;33m[1/2]\033[0m Finding macOS SDK..."
SDK_PATH=$(xcrun --show-sdk-path)

if [ -z "$SDK_PATH" ]; then
    echo -e "\033[0;31mError: macOS SDK not found. Make sure Xcode Command Line Tools are installed.\033[0m"
    exit 1
fi
echo -e "\033[0;32mFound SDK: $SDK_PATH\033[0m"

echo -e "\033[0;33m[2/2]\033[0m Compiling Swift sources..."
swiftc \
    -sdk "$SDK_PATH" \
    $(find Sources -name "*.swift") \
    -o Aferapokitaysky

if [ $? -eq 0 ]; then
    echo -e "\033[1;32m====================================================\033[0m"
    echo -e "\033[1;32m  BUILD SUCCESSFUL! \033[0m"
    
    # Create the macOS .app bundle structure
    APP_NAME="Aferapokitaysky.app"
    mkdir -p "$APP_NAME/Contents/MacOS"
    mkdir -p "$APP_NAME/Contents/Resources"
    
    mv Aferapokitaysky "$APP_NAME/Contents/MacOS/"
    
    # Copy icon if it exists
    if [ -f "AppIcon.icns" ]; then
        cp AppIcon.icns "$APP_NAME/Contents/Resources/"
    fi
    
    # Copy logo PNG if it exists
    if [ -f "logo.png" ]; then
        cp logo.png "$APP_NAME/Contents/Resources/logo.png"
    fi
    
    # Generate a basic Info.plist for the app bundle
    cat > "$APP_NAME/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Aferapokitaysky</string>
    <key>CFBundleIdentifier</key>
    <string>com.aferapokitaysky.player</string>
    <key>CFBundleName</key>
    <string>Aferapokitaysky</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF
    
    # Codesign the app bundle ad-hoc
    echo -e "\033[0;33mCodesigning the app bundle...\033[0m"
    codesign --force --deep --sign - "$APP_NAME"
    
    echo -e "\033[0;36m  App bundle created: ./$APP_NAME\033[0m"
    echo -e "\033[0;36m  You can now move this to your Applications folder!\033[0m"
    echo -e "\033[1;32m====================================================\033[0m"
else
    echo -e "\033[1;31m====================================================\033[0m"
    echo -e "\033[1;31m  BUILD FAILED! Please check error output above. \033[0m"
    echo -e "\033[1;31m====================================================\033[0m"
    exit 1
fi
