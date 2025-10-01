# AIAdventChatV2 - Claude AI Chat Application

Простое приложение для общения с Claude AI через API, созданное с использованием SwiftUI и архитектуры MVVM.

## Возможности

- 💬 Чат с Claude AI через официальный API
- ⚙️ Экран настроек для добавления API ключа
- 🎨 Современный и интуитивный интерфейс
- 📱 Поддержка macOS
- 🏗️ Архитектура MVVM

## Требования

- macOS 15.5+
- Xcode 16.0+
- API ключ от Anthropic (Claude)

## Установка и запуск

1. Клонируйте репозиторий или скачайте проект
2. Откройте `AIAdventChatV2.xcodeproj` в Xcode
3. Соберите и запустите проект (⌘+R)

## Настройка API ключа

1. Получите API ключ на [https://console.anthropic.com/](https://console.anthropic.com/)
2. Запустите приложение
3. Нажмите на кнопку настроек (⚙️) в правом верхнем углу
4. Введите ваш API ключ в поле "Claude API Key"
5. Нажмите "Готово"

## Использование

1. После настройки API ключа вы можете начать общение с Claude
2. Введите ваше сообщение в поле ввода внизу экрана
3. Нажмите кнопку отправки (📤) или Enter
4. Дождитесь ответа от Claude AI

## Архитектура

Приложение построено с использованием архитектуры MVVM:

- **Models**: `Message`, `Settings`
- **ViewModels**: `ChatViewModel` 
- **Views**: `ChatView`, `SettingsView`, `ContentView`

### Основные компоненты

- **Message**: Модель данных для сообщений чата
- **Settings**: Модель для хранения настроек приложения (API ключ)
- **ChatViewModel**: Бизнес-логика чата, обработка API запросов
- **ChatView**: Основной экран чата
- **SettingsView**: Экран настроек

## API

Приложение использует официальный API Anthropic Claude:
- Endpoint: `https://api.anthropic.com/v1/messages`
- Model: `claude-3-5-sonnet-20241022`
- Максимум токенов: 1000

## Особенности

- API ключ сохраняется в UserDefaults (не в Keychain, как запрошено)
- Автоматическая прокрутка к новым сообщениям
- Индикатор загрузки при ожидании ответа
- Обработка ошибок с понятными сообщениями
- Возможность очистки чата

## Структура проекта

```
AIAdventChatV2/
├── Models/
│   ├── Message.swift          # Модель сообщения
│   └── Settings.swift         # Модель настроек
├── ViewModels/
│   └── ChatViewModel.swift    # ViewModel для чата
├── Views/
│   ├── ChatView.swift         # Основной экран чата
│   └── SettingsView.swift     # Экран настроек
├── ContentView.swift          # Корневой View
└── AIAdventChatV2App.swift    # Главный файл приложения
```

## Лицензия

Этот проект создан для демонстрационных целей.

