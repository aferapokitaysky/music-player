# Aferapokitaysky Player for macOS 🎵✨

[Русский текст ниже](#aesthetic-player-для-macos)

A modern, highly aesthetic, and completely native media player built for macOS. It focuses on premium glassmorphic design, smooth animations, and seamless integration with the MacBook's physical notch.

## ✨ Features

- **Glassmorphic UI**: A fully transparent, shadow-perfect main window featuring native macOS materials (`NSVisualEffectView`) and dynamic gradient backgrounds.
- **Dynamic Notch Mini Player**: A borderless interactive window that lives right under your screen's notch. It seamlessly expands on hover to reveal playback controls and track metadata with perfectly rounded corners.
- **Ambient Backdrops & Particles**: Features ambient glow reflections and "cosmic dust" particle effects that react to playback state.
- **Real-time Audio Visualizer**: A sleek, high-frequency animated bar visualizer mimicking audio playback frequencies.
- **Native macOS Integration**: Built using a hybrid of AppKit and SwiftUI for maximum performance and native system behaviors (like standard traffic light window buttons, media key bindings).
- **Standalone Build System**: No Xcode required! It uses a custom `build.sh` script to automatically discover and compile all Swift source files using the native `swiftc` compiler.

## 🛠 Project Structure

```text
aesthetic-player/
├── Sources/
│   ├── App/          # Application entry point and Window controllers (main.swift)
│   ├── Models/       # Data models and structures
│   ├── ViewModels/   # Business logic and state management
│   └── Views/        # SwiftUI and AppKit views (MainView, NotchMiniPlayerView, etc.)
├── build.sh          # Build script
└── README.md         # Documentation
```

## 🚀 Getting Started

### Requirements
- macOS 12.0 (Monterey) or newer.
- Swift 5.5+ (included with Xcode Command Line Tools).

### Building & Running

1. Open your terminal and navigate to the project directory:
   ```bash
   cd /path/to/aferapokitaysky-player
   ```
2. Run the build script to compile the application:
   ```bash
   ./build.sh
   ```
3. Launch the compiled executable:
   ```bash
   ./Aferapokitaysky
   ```

*(Note: During the first launch, macOS may request Developer Tools Access or Keychain permissions depending on your local Git config and security settings).*

---

# Aferapokitaysky Player для macOS

Современный, эстетичный и полностью нативный медиаплеер для macOS. Проект сфокусирован на премиальном дизайне с эффектом матового стекла (glassmorphism), плавных анимациях и идеальной интеграции с физической «челкой» (notch) на новых MacBook.

## ✨ Ключевые возможности

- **Glassmorphic UI**: Полностью прозрачное главное окно с идеальными тенями, использующее нативные материалы macOS (`NSVisualEffectView`) и динамические градиентные фоны.
- **Динамический мини-плеер в «челке»**: Интерактивное окно без рамок, «прилипающее» к системному вырезу экрана. Плавно раскрывается при наведении курсора, показывая элементы управления и метаданные трека с идеально скругленными углами.
- **Окружающая подсветка (Ambilight) и частицы**: Включает эффект рассеянного свечения (ambient glow) под цвет обложки и эффекты «космической пыли», реагирующие на воспроизведение.
- **Аудио-визуализатор реального времени**: Стильный эквалайзер с плавной анимацией частот.
- **Глубокая интеграция с macOS**: Построен на гибриде AppKit и SwiftUI для максимальной производительности. Поддерживает системные кнопки управления окном (светофоры) и медиа-клавиши.
- **Автономная система сборки**: Для работы не нужен Xcode! Проект использует кастомный скрипт `build.sh`, который сам находит и компилирует все исходники с помощью консольного `swiftc`.

## 🛠 Структура проекта

```text
aesthetic-player/
├── Sources/
│   ├── App/          # Точка входа в приложение и контроллеры окон (main.swift)
│   ├── Models/       # Модели данных
│   ├── ViewModels/   # Бизнес-логика и управление состоянием плеера
│   └── Views/        # SwiftUI и AppKit интерфейсы (MainView, NotchMiniPlayerView и др.)
├── build.sh          # Скрипт автоматической сборки
└── README.md         # Документация (этот файл)
```

## 🚀 Как запустить

### Требования
- macOS 12.0 (Monterey) или новее.
- Swift 5.5+ (входит в состав Xcode Command Line Tools).

### Сборка и запуск

1. Откройте терминал и перейдите в папку с проектом:
   ```bash
   cd /path/to/aferapokitaysky-player
   ```
2. Запустите скрипт сборки для компиляции:
   ```bash
   ./build.sh
   ```
3. Запустите готовый исполняемый файл:
   ```bash
   ./Aferapokitaysky
   ```

*(Примечание: При первом запуске macOS может однократно запросить доступ к инструментам разработчика (Developer Tools Access) в целях безопасности).*
