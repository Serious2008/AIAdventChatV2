# 🔔 Дизайн агента-напоминателя (Reminder Agent)

## 📋 Задание

Создать агент, который:
1. Сохраняет задачи/напоминания (JSON или SQLite)
2. Работает 24/7
3. Периодически уведомляет о summary
4. Интегрируется с Claude через MCP

---

## 🎯 Варианты реализации

### Вариант 1: Background Service + Local Notifications (macOS)
**Сложность:** ⭐⭐ Средняя
**Качество:** ⭐⭐⭐⭐ Отличное
**Рекомендация:** ✅ **ЛУЧШИЙ для вашего случая**

#### Как работает:

```
┌──────────────────────────────────────────────────────────┐
│ Пользователь в чате:                                     │
│ "Напомни мне через 2 часа позвонить клиенту"            │
└───────────────────┬──────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│ Claude с инструментами:                                  │
│ - create_reminder(title, message, time)                  │
│ - list_reminders()                                       │
│ - delete_reminder(id)                                    │
└───────────────────┬──────────────────────────────────────┘
                    │
                    │ Claude вызывает: create_reminder
                    ▼
┌──────────────────────────────────────────────────────────┐
│ ReminderService (Swift)                                  │
│                                                          │
│ 1. Сохраняет в SQLite                                   │
│ 2. Планирует UNNotification                             │
│ 3. Возвращает результат Claude                          │
└───────────────────┬──────────────────────────────────────┘
                    │
                    │ Через 2 часа
                    ▼
┌──────────────────────────────────────────────────────────┐
│ UNUserNotificationCenter (macOS)                         │
│                                                          │
│ [Уведомление]                                            │
│ 🔔 Напоминание                                           │
│ Позвонить клиенту                                        │
│                                                          │
│ [Открыть] [Отложить]                                     │
└──────────────────────────────────────────────────────────┘
```

#### Архитектура:

```swift
// 1. ReminderModel.swift
struct Reminder: Codable, Identifiable {
    let id: UUID
    let title: String
    let message: String
    let scheduledTime: Date
    let isCompleted: Bool
    let repeatInterval: RepeatInterval? // daily, weekly, etc.
}

// 2. ReminderService.swift (Swift)
class ReminderService {
    private let db: SQLiteDatabase
    private let notificationCenter = UNUserNotificationCenter.current()

    func createReminder(title: String, message: String, time: Date) async throws -> Reminder
    func scheduleNotification(for reminder: Reminder) async throws
    func listReminders() async throws -> [Reminder]
    func deleteReminder(id: UUID) async throws
    func getUpcomingReminders(hours: Int) async throws -> [Reminder]
}

// 3. ReminderTools.swift (MCP Tools)
class ReminderToolsProvider {
    static func getTools() -> [ClaudeTool] {
        return [
            createReminderTool(),
            listRemindersTool(),
            deleteReminderTool(),
            getSummaryTool()
        ]
    }
}

// 4. Background Timer (для периодических summary)
class SummaryScheduler {
    private var timer: Timer?

    func start(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.sendDailySummary()
            }
        }
    }

    func sendDailySummary() async {
        // Собираем summary
        // Показываем notification
        // Опционально: отправляем в чат
    }
}
```

#### Преимущества:
- ✅ Нативные macOS уведомления (красиво выглядят)
- ✅ Работает даже когда приложение свёрнуто
- ✅ Не требует постоянного интернета
- ✅ Низкое потребление ресурсов
- ✅ Интеграция с Notification Center
- ✅ Возможность отложить/пропустить

#### Недостатки:
- ⚠️ Приложение должно быть запущено (пусть и в фоне)
- ⚠️ macOS может ограничивать фоновую активность

---

### Вариант 2: MCP Server + Persistent Background Process
**Сложность:** ⭐⭐⭐ Высокая
**Качество:** ⭐⭐⭐⭐⭐ Превосходное
**Рекомендация:** ✅ **ЛУЧШИЙ для production**

#### Как работает:

```
┌──────────────────────────────────────────────────────────┐
│ 1. Отдельный MCP Server (Node.js/Python)                │
│    Работает как системный сервис (launchd на macOS)     │
└───────────────────┬──────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│ mcp-reminder-server/                                     │
│ ├── src/                                                 │
│ │   ├── index.ts                                         │
│ │   ├── database.ts (SQLite)                             │
│ │   ├── scheduler.ts                                     │
│ │   └── notifier.ts                                      │
│ └── reminders.db                                         │
└───────────────────┬──────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│ Scheduler (node-cron или node-schedule)                  │
│                                                          │
│ Every minute:                                            │
│ 1. Проверяет БД на просроченные напоминания             │
│ 2. Отправляет уведомления                               │
│ 3. Помечает как отправленные                            │
└───────────────────┬──────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│ Notifier - несколько способов:                          │
│                                                          │
│ A. node-notifier (macOS notifications)                   │
│ B. Webhook → ваше приложение                             │
│ C. WebSocket → real-time в приложение                    │
│ D. Email                                                 │
│ E. Telegram bot                                          │
└──────────────────────────────────────────────────────────┘
```

#### Структура MCP сервера:

```typescript
// mcp-reminder-server/src/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { Database } from "./database.js";
import { Scheduler } from "./scheduler.js";
import { Notifier } from "./notifier.js";

class ReminderMCPServer {
    private db: Database;
    private scheduler: Scheduler;
    private notifier: Notifier;

    constructor() {
        this.db = new Database("reminders.db");
        this.notifier = new Notifier();
        this.scheduler = new Scheduler(this.db, this.notifier);

        // Запускаем планировщик
        this.scheduler.start();
    }

    // MCP Tools
    async handleCreateReminder(args: any) {
        const reminder = await this.db.insertReminder({
            title: args.title,
            message: args.message,
            scheduledTime: new Date(args.time),
            repeatInterval: args.repeat
        });

        return `✅ Напоминание создано: ${reminder.title} на ${formatDate(reminder.scheduledTime)}`;
    }

    async handleListReminders() {
        const reminders = await this.db.getUpcomingReminders();
        return formatRemindersList(reminders);
    }

    async handleGetSummary() {
        const today = await this.db.getRemindersForToday();
        const upcoming = await this.db.getUpcomingReminders(7); // 7 дней
        const overdue = await this.db.getOverdueReminders();

        return formatSummary({ today, upcoming, overdue });
    }
}

// mcp-reminder-server/src/scheduler.ts
import cron from "node-cron";

export class Scheduler {
    start() {
        // Проверяем каждую минуту
        cron.schedule("* * * * *", async () => {
            await this.checkReminders();
        });

        // Ежедневный summary в 9:00
        cron.schedule("0 9 * * *", async () => {
            await this.sendDailySummary();
        });

        // Еженедельный summary в понедельник 9:00
        cron.schedule("0 9 * * 1", async () => {
            await this.sendWeeklySummary();
        });
    }

    private async checkReminders() {
        const now = new Date();
        const reminders = await this.db.getDueReminders(now);

        for (const reminder of reminders) {
            await this.notifier.send(reminder);
            await this.db.markAsNotified(reminder.id);

            // Если повторяющееся, создаём следующее
            if (reminder.repeatInterval) {
                await this.db.createNextRecurrence(reminder);
            }
        }
    }

    private async sendDailySummary() {
        const summary = await this.generateDailySummary();
        await this.notifier.sendSummary(summary);
    }
}

// mcp-reminder-server/src/notifier.ts
import notifier from "node-notifier";

export class Notifier {
    async send(reminder: Reminder) {
        // macOS notification
        notifier.notify({
            title: "🔔 " + reminder.title,
            message: reminder.message,
            sound: true,
            wait: true,
            timeout: 10
        });

        // Опционально: webhook в приложение
        await fetch("http://localhost:8080/reminder-notification", {
            method: "POST",
            body: JSON.stringify(reminder)
        });
    }

    async sendSummary(summary: string) {
        notifier.notify({
            title: "📊 Daily Summary",
            message: summary,
            sound: false
        });
    }
}
```

#### Установка как системный сервис (macOS launchd):

```bash
# 1. Создаём сервис
cat > ~/Library/LaunchAgents/com.yourname.reminder-server.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourname.reminder-server</string>

    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/node</string>
        <string>/path/to/mcp-reminder-server/build/index.js</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/reminder-server.log</string>

    <key>StandardErrorPath</key>
    <string>/tmp/reminder-server-error.log</string>
</dict>
</plist>
EOF

# 2. Загружаем сервис
launchctl load ~/Library/LaunchAgents/com.yourname.reminder-server.plist

# 3. Проверяем статус
launchctl list | grep reminder-server
```

#### Преимущества:
- ✅ Работает **всегда**, даже если приложение закрыто
- ✅ Независимый процесс (не зависит от Swift приложения)
- ✅ Легко масштабируется (можно добавить веб-интерфейс)
- ✅ Можно отправлять уведомления разными способами
- ✅ Production-ready (restart при падении)

#### Недостатки:
- ⚠️ Требует настройки системного сервиса
- ⚠️ Сложнее в отладке

---

### Вариант 3: Hybrid (Swift App + MCP Server + WebSocket)
**Сложность:** ⭐⭐⭐⭐ Очень высокая
**Качество:** ⭐⭐⭐⭐⭐ Превосходное
**Рекомендация:** ✅ **Для максимальной гибкости**

#### Архитектура:

```
┌────────────────────────────────────────────────────────────┐
│ Swift App (AIAdventChatV2)                                 │
│                                                            │
│ ┌──────────────────────────────────────────────────────┐  │
│ │ ReminderView                                         │  │
│ │ - Список напоминаний                                 │  │
│ │ - Создание новых                                     │  │
│ │ - Редактирование                                     │  │
│ └───────────────────┬──────────────────────────────────┘  │
│                     │                                      │
│                     ▼                                      │
│ ┌──────────────────────────────────────────────────────┐  │
│ │ ReminderWebSocketClient                              │  │
│ │ - Получает real-time уведомления                     │  │
│ │ - Обновляет UI                                       │  │
│ └───────────────────┬──────────────────────────────────┘  │
└─────────────────────┼────────────────────────────────────┘
                      │
                      │ WebSocket
                      ▼
┌────────────────────────────────────────────────────────────┐
│ MCP Reminder Server (Node.js)                              │
│                                                            │
│ ┌──────────────────────────────────────────────────────┐  │
│ │ MCP Tools Handler                                    │  │
│ │ - create_reminder                                    │  │
│ │ - list_reminders                                     │  │
│ │ - get_summary                                        │  │
│ └───────────────────┬──────────────────────────────────┘  │
│                     │                                      │
│ ┌──────────────────┴──────────────────────────────────┐  │
│ │ WebSocket Server                                     │  │
│ │ - Отправляет уведомления клиентам                   │  │
│ │ - Синхронизирует состояние                          │  │
│ └──────────────────────────────────────────────────────┘  │
│                                                            │
│ ┌──────────────────────────────────────────────────────┐  │
│ │ Scheduler (node-cron)                                │  │
│ │ - Проверяет напоминания каждую минуту               │  │
│ │ - Отправляет summary по расписанию                  │  │
│ └──────────────────────────────────────────────────────┘  │
│                                                            │
│ ┌──────────────────────────────────────────────────────┐  │
│ │ SQLite Database                                      │  │
│ │ reminders.db                                         │  │
│ └──────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

#### Преимущества:
- ✅ Real-time уведомления в приложении
- ✅ Работает независимо от приложения
- ✅ Красивый UI для управления напоминаниями
- ✅ Синхронизация между устройствами (если добавить)

---

### Вариант 4: Cloud-based (Firebase/Supabase + Cloud Functions)
**Сложность:** ⭐⭐⭐ Высокая
**Качество:** ⭐⭐⭐⭐⭐ Превосходное
**Рекомендация:** ⚠️ **Только если нужна синхронизация между устройствами**

#### Архитектура:

```
┌──────────────────────────────────────────────────────────┐
│ Swift App                                                │
│ ↕ Firebase SDK                                           │
└───────────────────┬──────────────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────────────┐
│ Firebase/Supabase                                        │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Firestore/PostgreSQL                               │  │
│ │ - reminders collection                             │  │
│ │ - Real-time sync                                   │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Cloud Functions / Edge Functions                  │  │
│ │ - Scheduled function (каждую минуту)              │  │
│ │ - Проверяет напоминания                           │  │
│ │ - Отправляет Push Notifications                   │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Firebase Cloud Messaging (FCM)                     │  │
│ │ - Push notifications на все устройства             │  │
│ └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

#### Преимущества:
- ✅ Синхронизация между устройствами
- ✅ Работает без локального сервера
- ✅ Масштабируемость
- ✅ Push notifications

#### Недостатки:
- ⚠️ Требует интернет
- ⚠️ Стоимость (хоть и небольшая)
- ⚠️ Зависимость от внешнего сервиса

---

## 🎯 Рекомендации

### Для вашего случая (Pet Project + Learning):

**Рекомендую: Вариант 1 + Вариант 2 (поэтапно)**

#### Этап 1: Начните с Варианта 1 (Swift + Local Notifications)
**Почему:**
- ✅ Быстрая реализация (1-2 дня)
- ✅ Полная интеграция с текущим приложением
- ✅ Изучите UserNotifications framework
- ✅ Работает сразу после имплементации

**Что сделать:**
1. Создать `ReminderService.swift`
2. Добавить SQLite хранилище
3. Интегрировать с Claude через MCP Tools
4. Настроить UNUserNotificationCenter
5. Добавить UI для управления напоминаниями

#### Этап 2: Расширьте до Варианта 2 (Background MCP Server)
**Почему:**
- ✅ Научитесь создавать системные сервисы
- ✅ Изучите node-cron для планирования
- ✅ Production-ready решение
- ✅ Работает независимо от приложения

**Что сделать:**
1. Создать отдельный `mcp-reminder-server/`
2. Настроить как launchd сервис
3. Добавить WebSocket для real-time связи
4. Перенести логику планирования на сервер

---

## 📋 Пошаговый план (Вариант 1)

### Шаг 1: Создать модель данных

```swift
// Models/Reminder.swift
import Foundation

struct Reminder: Codable, Identifiable {
    let id: UUID
    var title: String
    var message: String
    var scheduledTime: Date
    var isCompleted: Bool
    var repeatInterval: RepeatInterval?
    var createdAt: Date
    var notifiedAt: Date?

    enum RepeatInterval: String, Codable {
        case none
        case daily
        case weekly
        case monthly
    }
}
```

### Шаг 2: Создать SQLite сервис

```swift
// Services/ReminderDatabase.swift
import Foundation
import SQLite

class ReminderDatabase {
    private var db: Connection?

    private let reminders = Table("reminders")
    private let id = Expression<String>("id")
    private let title = Expression<String>("title")
    private let message = Expression<String>("message")
    private let scheduledTime = Expression<Date>("scheduled_time")
    // ... other columns

    init() {
        do {
            let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
            db = try Connection("\(path)/reminders.db")
            try createTable()
        } catch {
            print("Database error: \(error)")
        }
    }

    func insert(_ reminder: Reminder) throws { }
    func getAll() throws -> [Reminder] { }
    func getUpcoming(hours: Int) throws -> [Reminder] { }
    func delete(id: UUID) throws { }
}
```

### Шаг 3: Создать ReminderService

```swift
// Services/ReminderService.swift
import UserNotifications

class ReminderService: ObservableObject {
    @Published var reminders: [Reminder] = []

    private let db = ReminderDatabase()
    private let notificationCenter = UNUserNotificationCenter.current()

    func createReminder(title: String, message: String, time: Date) async throws -> Reminder
    func scheduleNotification(for reminder: Reminder) async throws
    func loadReminders()
    func deleteReminder(id: UUID)
    func getDailySummary() async -> String
}
```

### Шаг 4: Создать MCP Tools

```swift
// Services/ReminderTools.swift
class ReminderToolsProvider {
    static func getTools() -> [ClaudeTool] {
        return [
            createReminderTool(),
            listRemindersTool(),
            getSummaryTool()
        ]
    }

    static func executeTool(
        name: String,
        input: [String: Any],
        reminderService: ReminderService
    ) async throws -> String {
        // Implementation
    }
}
```

### Шаг 5: Интегрировать с Claude

```swift
// ChatViewModel.swift
// Добавить ReminderService к доступным инструментам
if settings.isRemindersEnabled {
    let reminderTools = ReminderToolsProvider.getTools()
    tools.append(contentsOf: reminderTools)
}
```

### Шаг 6: Создать UI

```swift
// Views/RemindersView.swift
struct RemindersView: View {
    @ObservedObject var reminderService: ReminderService

    var body: some View {
        List {
            ForEach(reminderService.reminders) { reminder in
                ReminderRow(reminder: reminder)
            }
        }
        .toolbar {
            Button("Add Reminder") {
                // Show create reminder dialog
            }
        }
    }
}
```

---

## ⏰ Summary Schedule Examples

### 1. Daily Summary (9:00 AM)
```
📊 Daily Summary - 15 октября 2025

🔔 Сегодня запланировано 5 напоминаний:
• 10:00 - Встреча с командой
• 14:00 - Позвонить клиенту
• 16:30 - Code review
• 18:00 - Тренировка
• 20:00 - Подготовить отчёт

📅 Завтра: 3 напоминания
⏰ Просрочено: 1 напоминание

Хорошего дня! 🌟
```

### 2. Weekly Summary (Monday 9:00 AM)
```
📊 Weekly Summary - Неделя 42

✅ На прошлой неделе выполнено: 23 из 25 напоминаний
📈 Прогресс: 92%

📅 На этой неделе запланировано: 18 напоминаний
🔥 Самые важные:
• Понедельник 14:00 - Презентация проекта
• Среда 10:00 - Встреча с инвесторами
• Пятница 16:00 - Дедлайн по задаче

Продуктивной недели! 💪
```

---

## 🎯 Итоговая рекомендация

### Начните с этого:

1. **Сейчас (1-2 дня):** Вариант 1 (Swift + UserNotifications)
   - Быстро работает
   - Полная интеграция с Claude
   - Красивый UI

2. **Позже (3-5 дней):** Добавьте Вариант 2 (MCP Background Server)
   - Работает 24/7 независимо
   - Более надёжно
   - Production-ready

3. **Опционально:** WebSocket для real-time sync

### Минимальный набор функций для MVP:

- ✅ Создать напоминание через чат ("Напомни мне в 15:00...")
- ✅ Список всех напоминаний
- ✅ Удалить напоминание
- ✅ Local notification в указанное время
- ✅ Daily summary в 9:00
- ✅ SQLite для хранения

### Расширенные функции (позже):

- 🔄 Повторяющиеся напоминания (daily/weekly)
- 📍 Напоминания по геолокации
- 🏷️ Теги и категории
- 📊 Статистика выполнения
- 🔔 Разные типы уведомлений (звук/баннер/badge)
- 📱 Синхронизация между устройствами

---

## 📚 Полезные ресурсы

### Apple Documentation:
- [UserNotifications Framework](https://developer.apple.com/documentation/usernotifications)
- [UNNotificationRequest](https://developer.apple.com/documentation/usernotifications/unnotificationrequest)
- [SQLite with Swift](https://github.com/stephencelis/SQLite.swift)

### Node.js Libraries:
- [node-cron](https://www.npmjs.com/package/node-cron) - Планирование задач
- [node-schedule](https://www.npmjs.com/package/node-schedule) - Более гибкое планирование
- [node-notifier](https://www.npmjs.com/package/node-notifier) - macOS уведомления

---

**Готовы начать? Какой вариант хотите реализовать первым?** 🚀
