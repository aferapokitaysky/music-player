#!/bin/bash

# --- Aesthetic macOS Media Player Builder ---
# Compiles Swift files into a standalone native macOS executable.

echo -e "\033[1;36m====================================================\033[0m"
echo -e "\033[1;35m  AESTHETIC MAC-OS MEDIA PLAYER BUILDER  \033[0m"
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
    main.swift \
    Theme.swift \
    Persistence.swift \
    PlayerViewModel.swift \
    Views/ServiceLogos.swift \
    Views/VisualizerView.swift \
    Views/PlayerControls.swift \
    Views/MainView.swift \
    -o AestheticPlayer

if [ $? -eq 0 ]; then
    echo -e "\033[1;32m====================================================\033[0m"
    echo -e "\033[1;32m  BUILD SUCCESSFUL! \033[0m"
    echo -e "\033[0;36m  Executable created: ./AestheticPlayer\033[0m"
    echo -e "\033[0;36m  Run it with: ./AestheticPlayer &\033[0m"
    echo -e "\033[1;32m====================================================\033[0m"
    chmod +x AestheticPlayer
else
    echo -e "\033[1;31m====================================================\033[0m"
    echo -e "\033[1;31m  BUILD FAILED! Please check error output above. \033[0m"
    echo -e "\033[1;31m====================================================\033[0m"
    exit 1
fi
