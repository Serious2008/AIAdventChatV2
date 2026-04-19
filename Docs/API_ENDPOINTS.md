# API Endpoints — AIAdventChatV2

Все внешние HTTP эндпоинты используемые приложением.

## Внешние API

| Сервис | URL | Метод | Назначение | Сервис-файл |
|---|---|---|---|---|
| Anthropic Claude | `https://api.anthropic.com/v1/messages` | POST | Основная LLM, генерация ответов | `ClaudeService.swift` |
| OpenAI Embeddings | `https://api.openai.com/v1/embeddings` | POST | Векторные embeddings для RAG | `EmbeddingService.swift` |
| HuggingFace | `https://router.huggingface.co/v1/chat/completions` | POST | Альтернативные LLM модели | `HuggingFaceService.swift` |
| OpenWeatherMap | `https://api.openweathermap.org/data/2.5/weather` | GET | Погода по названию города | `WeatherService.swift` |

## Локальные API

| Сервис | URL | Метод | Назначение | Сервис-файл |
|---|---|---|---|---|
| Ollama — модели | `http://localhost:11434/api/tags` | GET | Список доступных моделей | `OllamaService.swift` |
| Ollama — генерация | `http://localhost:11434/api/generate` | POST | Генерация текста локальной моделью | `OllamaService.swift` |

## Покрытие тестами

| Эндпоинт | Покрыт тестами |
|---|---|
| `api.anthropic.com/v1/messages` | ❌ |
| `api.openai.com/v1/embeddings` | ❌ |
| `router.huggingface.co/v1/chat/completions` | ❌ |
| `api.openweathermap.org/data/2.5/weather` | ❌ |
| `localhost:11434/api/tags` | ❌ |
| `localhost:11434/api/generate` | ❌ |

> Все эндпоинты не покрыты тестами — требуется добавить mock-тесты.
