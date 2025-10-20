---
description: Анализирует структуру проекта AIAdventChatV2 и ищет потенциальные баги
---

НЕМЕДЛЕННО начни анализ проекта AIAdventChatV2. НЕ ЗАДАВАЙ вопросы, НЕ СПРАШИВАЙ дополнительную информацию.

КОНТЕКСТ ПРОЕКТА:
- Название: AIAdventChatV2
- Тип: macOS приложение на Swift/SwiftUI
- Назначение: AI чат-ассистент с интеграцией Claude API, MCP серверами, Yandex Tracker
- Директория: /Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/AIAdventChatV2/

ВЫПОЛНИ СЛЕДУЮЩИЕ ШАГИ АВТОМАТИЧЕСКИ:

**ШАГ 1: Найди все Swift файлы**
Используй Glob для поиска всех .swift файлов в директории AIAdventChatV2/

**ШАГ 2: Построй структуру**
Категоризуй файлы по типам:
- Models (файлы в Models/)
- Views (файлы в Views/)
- ViewModels (файлы в ViewModels/)
- Services (файлы в Services/)
- App (точка входа)

**ШАГ 3: Найди проблемы**
Используй Grep для поиска:
- Force unwrapping: поиск по паттерну `\!` в .swift файлах
- Force casting: поиск по паттерну `as!` в .swift файлах
- Force try: поиск по паттерну `try!` в .swift файлах
- TODO/FIXME: поиск комментариев с задачами
- Retain cycles: проверь наличие `[weak self]` в closures

**ШАГ 4: Прочитай ключевые файлы**
Прочитай и проанализируй:
- AIAdventChatV2/ViewModels/ChatViewModel.swift (основная бизнес-логика)
- AIAdventChatV2/Services/ClaudeService.swift (интеграция с API)
- AIAdventChatV2/Models/Settings.swift (конфигурация)

**ШАГ 5: Создай отчет**
Предоставь структурированный отчет в формате:

# АНАЛИЗ ПРОЕКТА AIAdventChatV2

## 📁 СТРУКТУРА ПРОЕКТА
[Список файлов по категориям]

## 🏗 АРХИТЕКТУРА
[Используемые паттерны и описание компонентов]

## ⚠️ НАЙДЕННЫЕ ПРОБЛЕМЫ
[Конкретные примеры с номерами строк]

## 💡 РЕКОМЕНДАЦИИ
[Что улучшить]

НАЧНИ АНАЛИЗ ПРЯМО СЕЙЧАС. Не спрашивай ничего дополнительно.
