# Aferapokitaysky Player for macOS 🎵✨

[Русский текст ниже](#aferapokitaysky-player-для-macos)

A modern, highly aesthetic, and completely native media player built for macOS. It focuses on premium glassmorphic design, smooth animations, and seamless integration with the MacBook's physical notch.

## ✨ Features

- **Glassmorphic UI**: A fully transparent, shadow-perfect main window featuring native macOS materials (`NSVisualEffectView`) and dynamic gradient backgrounds.
- **Dynamic Notch Mini Player**: A borderless interactive window that lives right under your screen's notch. It seamlessly expands on hover to reveal playback controls and track metadata with perfectly rounded corners.
- **Ambient Backdrops & Particles**: Ambient glow reflections and a "cosmic dust" particle system that react to playback state.
- **Real-time Audio Visualizer**: A sleek animated visualizer with multiple render modes (bars, wave, circle, dots) that mirror audio playback frequencies.
- **Spotify & SoundCloud Integration**: In-app web login flow for both services, with tokens/cookies stored securely in the macOS Keychain and built-in track search.
- **Terminal UI Mode**: A full-featured text-based interface for controlling playback, search, and library navigation entirely from the terminal (`--cli` flag).
- **Native macOS Integration**: Built using a hybrid of AppKit and SwiftUI for maximum performance and native system behaviors (standard traffic light window buttons, media key bindings).
- **Standalone Build System**: No Xcode required! A custom `build.sh` script automatically discovers and compiles all Swift source files using the native `swiftc` compiler.

## 🛠 Project Structure

```text
music-player/
├── Sources/
│   ├── App/         # Application entry point and window controllers (main.swift)
│   ├── Theme/       # Color palettes and theming
│   ├── ViewModels/  # Business logic and state management (PlayerViewModel)
│   ├── Views/       # SwiftUI and AppKit views (MainView, NotchMiniPlayerView, etc.)
│   └── Resources/   # Bundled images and service logos
├── build.sh              # Standalone build script (no Xcode required)
├── aferapokitaysky-win/  # Experimental Windows port (Tauri + Svelte)
└── README.md             # Documentation
```

## 🚀 Getting Started

### Requirements
- macOS 12.0 (Monterey) or newer.
- Swift 5.5+ (included with Xcode Command Line Tools).

### Building & Running

1. Open your terminal and navigate to the project directory:
   ```bash
   cd /path/to/music-player
   ```
2. Run the build script to compile the application:
   ```bash
   ./build.sh
   ```
3. Launch the compiled executable:
   ```bash
   open ./Aferapokitaysky.app
   # or run the terminal UI:
   ./Aferapokitaysky.app/Contents/MacOS/Aferapokitaysky --cli
   ```

*(Note: During the first launch, macOS may request Developer Tools Access or Keychain permissions depending on your local Git config and security settings).*

## 🪟 Windows Port (`aferapokitaysky-win/`)

An experimental Windows build of the player lives in [`aferapokitaysky-win/`](./aferapokitaysky-win), built with [Tauri](https://tauri.app) (Rust) and a Svelte + TypeScript frontend that mirrors the macOS app's glassmorphic UI, theming system, and visualizer.

- **Frontend**: Svelte + TypeScript (`src/`), reproducing the album sidebar, player controls, and audio visualizer from the native app.
- **Backend**: A Rust/Tauri shell (`src-tauri/`) exposing `play_track`, `pause_track`, `set_volume`, and `get_audio_frequencies` commands, with `rodio` and `symphonia` listed as the intended audio decoding/playback stack.
- **Status**: Early-stage/work in progress — playback commands and the visualizer's frequency data are currently stubbed (simulated values), not yet wired to real audio decoding and output. Treat this as a UI/architecture preview rather than a feature-complete build.

### Running the Windows port

```bash
cd aferapokitaysky-win
npm install
npm run dev    # launches the Tauri dev shell (equivalent to `tauri dev`)
npm run build  # produces a release build (equivalent to `tauri build`)
```

Requires Node.js, the Rust toolchain, and the platform prerequisites for [Tauri v2](https://v2.tauri.app/start/prerequisites/) (e.g. WebView2 on Windows).

---

# Aferapokitaysky Player для macOS

Современный, эстетичный и полностью нативный медиаплеер для macOS. Проект сфокусирован на премиальном дизайне с эффектом матового стекла (glassmorphism), плавных анимациях и идеальной интеграции с физической «чёлкой» (notch) на новых MacBook.

## ✨ Ключевые возможности

- **Glassmorphic UI**: Полностью прозрачное главное окно с идеальными тенями, использующее нативные материалы macOS (`NSVisualEffectView`) и динамические градиентные фоны.
- **Динамический мини-плеер в «чёлке»**: Интерактивное окно без рамок, «прилипающее» к системному вырезу экрана. Плавно раскрывается при наведении курсора, показывая элементы управления и метаданные трека с идеально скруглёнными углами.
- **Окружающая подсветка (ambient glow) и частицы**: Эффект рассеянного свечения под цвет обложки и система частиц «космической пыли», реагирующая на воспроизведение.
- **Аудио-визуализатор реального времени**: Стильный анимированный визуализатор с несколькими режимами отображения (столбцы, волна, круг, точки), синхронизированный с частотами воспроизведения.
- **Интеграция со Spotify и SoundCloud**: Встроенный веб-вход для обоих сервисов, безопасное хранение токенов/cookies в Keychain macOS и поиск треков прямо в приложении.
- **Терминальный режим**: Полноценный текстовый интерфейс для управления воспроизведением, поиском и библиотекой прямо из терминала (флаг `--cli`).
- **Глубокая интеграция с macOS**: Построен на гибриде AppKit и SwiftUI для максимальной производительности. Поддерживает системные кнопки управления окном (светофоры) и медиа-клавиши.
- **Автономная система сборки**: Для работы не нужен Xcode! Кастомный скрипт `build.sh` сам находит и компилирует все исходники с помощью консольного `swiftc`.

## 🛠 Структура проекта

```text
music-player/
├── Sources/
│   ├── App/         # Точка входа в приложение и контроллеры окон (main.swift)
│   ├── Theme/       # Цветовые палитры и темы
│   ├── ViewModels/  # Бизнес-логика и управление состоянием (PlayerViewModel)
│   ├── Views/       # SwiftUI и AppKit интерфейсы (MainView, NotchMiniPlayerView и др.)
│   └── Resources/   # Встроенные изображения и логотипы сервисов
├── build.sh              # Скрипт автономной сборки (Xcode не требуется)
├── aferapokitaysky-win/  # Экспериментальный порт для Windows (Tauri + Svelte)
└── README.md             # Документация (этот файл)
```

## 🚀 Как запустить

### Требования
- macOS 12.0 (Monterey) или новее.
- Swift 5.5+ (входит в состав Xcode Command Line Tools).

### Сборка и запуск

1. Откройте терминал и перейдите в папку с проектом:
   ```bash
   cd /path/to/music-player
   ```
2. Запустите скрипт сборки для компиляции:
   ```bash
   ./build.sh
   ```
3. Запустите готовый исполняемый файл:
   ```bash
   open ./Aferapokitaysky.app
   # или терминальный режим:
   ./Aferapokitaysky.app/Contents/MacOS/Aferapokitaysky --cli
   ```

*(Примечание: При первом запуске macOS может запросить доступ к инструментам разработчика (Developer Tools Access) или к Keychain в зависимости от локальных настроек безопасности).*

## 🪟 Порт для Windows (`aferapokitaysky-win/`)

Экспериментальная Windows-версия плеера находится в папке [`aferapokitaysky-win/`](./aferapokitaysky-win) и построена на [Tauri](https://tauri.app) (Rust) с фронтендом на Svelte + TypeScript, повторяющим glassmorphic-интерфейс, систему тем и визуализатор оригинального macOS-приложения.

- **Фронтенд**: Svelte + TypeScript (`src/`) — воспроизводит боковую панель с альбомами, элементы управления плеером и аудио-визуализатор из нативного приложения.
- **Бэкенд**: Rust/Tauri-оболочка (`src-tauri/`), предоставляющая команды `play_track`, `pause_track`, `set_volume` и `get_audio_frequencies`; в качестве стека для декодирования и воспроизведения аудио заявлены `rodio` и `symphonia`.
- **Статус**: Ранняя стадия разработки — команды воспроизведения и данные визуализатора пока заглушены (используются симулированные значения) и ещё не подключены к реальному декодированию и выводу аудио. Стоит воспринимать это как превью интерфейса и архитектуры, а не готовую к использованию сборку.

### Запуск Windows-версии

```bash
cd aferapokitaysky-win
npm install
npm run dev    # запускает dev-оболочку Tauri (аналог `tauri dev`)
npm run build  # собирает релизную версию (аналог `tauri build`)
```

Требуются Node.js, тулчейн Rust и системные зависимости для [Tauri v2](https://v2.tauri.app/start/prerequisites/) (например, WebView2 на Windows).
