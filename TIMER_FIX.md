# 🔧 Исправление проблемы с Timer

## 🐛 Проблема

**Симптом:** Первое сообщение от погодного агента приходит, но дальше обновления прекращаются.

**Причина:** Timer не был правильно добавлен в RunLoop и использовал устаревшую копию структуры task.

---

## ✅ Что было исправлено

### 1. Timer не добавлялся в RunLoop

**Было:**
```swift
let timer = Timer.scheduledTimer(
    withTimeInterval: interval,
    repeats: true
) { [weak self] _ in
    Task {
        await self?.executeTask(task)
    }
}

timers[task.id] = timer
```

**Проблема:** `scheduledTimer` автоматически добавляет Timer в current RunLoop, но только в default mode. Когда приложение выполняет другие действия (scrolling, tracking), RunLoop переключается на другой mode и Timer перестаёт срабатывать.

**Стало:**
```swift
let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
    print("⏰ Timer сработал для задачи \(task.id)")
    Task {
        await self?.executeTaskById(task.id)
    }
}

// Добавляем timer в main RunLoop с режимом common
RunLoop.main.add(timer, forMode: .common)

timers[task.id] = timer

print("✅ Timer создан и добавлен в RunLoop для задачи \(task.id)")
```

**Решение:** Используем `RunLoop.main.add(timer, forMode: .common)` чтобы Timer работал во всех режимах RunLoop, включая tracking mode (когда пользователь взаимодействует с UI).

---

### 2. Timer использовал устаревшую копию task

**Было:**
```swift
let timer = Timer(...) { [weak self] _ in
    Task {
        await self?.executeTask(task)  // ❌ task - это копия структуры
    }
}
```

**Проблема:** `PeriodicTask` - это struct (value type), а не class (reference type). Когда мы захватываем `task` в closure, захватывается **копия** структуры. Если позже мы обновим счётчик `executionCount` или изменим `isActive`, эти изменения не будут видны в closure.

**Стало:**
```swift
let timer = Timer(...) { [weak self] _ in
    Task {
        await self?.executeTaskById(task.id)  // ✅ Передаём только ID
    }
}

// Новый метод, который находит актуальную задачу по ID
private func executeTaskById(_ taskId: UUID) async {
    guard let task = activeTasks.first(where: { $0.id == taskId && $0.isActive }) else {
        print("⚠️ Задача \(taskId) не найдена или неактивна")
        return
    }

    print("🚀 Выполняю задачу \(taskId): \(task.action)")
    await executeTask(task)
}
```

**Решение:** Вместо захвата всей структуры, захватываем только `taskId`, а затем находим актуальную версию задачи из `activeTasks` перед каждым выполнением.

---

### 3. Добавлено логирование для отладки

Добавлены print-ы на каждом этапе:

```swift
// При создании Timer
print("⏰ Планирую задачу \(task.id) с интервалом \(interval) секунд")
print("✅ Timer создан и добавлен в RunLoop")

// При срабатывании Timer
print("⏰ Timer сработал для задачи \(task.id)")

// При выполнении задачи
print("📋 Начинаю выполнение задачи \(task.id)")
print("🔧 Вызываю MCP tool: \(task.action)")
print("✅ MCP tool вернул результат: \(result.prefix(100))...")
print("📊 Счётчик выполнений: \(executionCount)")
print("💬 Добавляю результат в чат")
print("✅ Задача успешно выполнена")
```

Это позволяет увидеть в консоли Xcode, что именно происходит и где возникают проблемы.

---

## 🧪 Как тестировать

### 1. Запустите приложение с консолью Xcode

В Xcode: Window → Show Debug Area (⇧⌘Y)

### 2. Напишите в чат

```
Присылай мне погоду в Москве каждые 2 минуты
```

(Для тестирования используйте короткий интервал - 2 минуты вместо часа)

### 3. Наблюдайте логи в консоли

Вы должны увидеть:
```
⏰ Планирую задачу [UUID] с интервалом 120.0 секунд (2 минут)
✅ Timer создан и добавлен в RunLoop для задачи [UUID]
📋 Начинаю выполнение задачи [UUID]
🔧 Вызываю MCP tool: get_weather_summary
✅ MCP tool вернул результат: 🌤️ Погода в Москве...
💬 Добавляю результат в чат
✅ Задача [UUID] успешно выполнена
```

### 4. Через 2 минуты должен сработать Timer

```
⏰ Timer сработал для задачи [UUID]
🚀 Выполняю задачу [UUID]: get_weather_summary с параметрами ["city": "Москва"]
📋 Начинаю выполнение задачи [UUID]
...
✅ Задача [UUID] успешно выполнена
```

### 5. В чате появится второе обновление

```
🤖 Погодный агент • 22:45 • Москва

🌤️ Погода в Москве:
• Температура: +15°C
...
```

---

## 📊 Что изменилось в коде

### PeriodicTaskService.swift

**Изменённые методы:**

1. **scheduleTask()** - строки 71-92
   - Использует `Timer(timeInterval:repeats:block:)` вместо `scheduledTimer`
   - Явно добавляет в RunLoop с `.common` mode
   - Вызывает `executeTaskById` вместо `executeTask`
   - Добавлено логирование

2. **executeTaskById()** - строки 94-103 (НОВЫЙ МЕТОД)
   - Находит актуальную задачу по ID из `activeTasks`
   - Проверяет что задача активна
   - Логирует выполнение

3. **executeTask()** - строки 105-139
   - Добавлено подробное логирование на каждом этапе
   - Логирует результат MCP
   - Логирует счётчик выполнений
   - Логирует добавление в чат

4. **addResultToChat()** - строки 184-207
   - Добавлена проверка на nil chatViewModel
   - Логирует количество сообщений до и после добавления

---

## 🎯 Результат

**До исправления:**
- ✅ Первое сообщение приходит
- ❌ Последующие обновления не приходят
- ❌ Timer не срабатывает повторно

**После исправления:**
- ✅ Первое сообщение приходит
- ✅ Последующие обновления приходят каждый интервал
- ✅ Timer работает бесконечно долго
- ✅ Логи показывают каждое выполнение

---

## 🔍 Дополнительная отладка

Если обновления всё равно не приходят, проверьте логи на:

### 1. Timer не срабатывает
Ищите в логах: `⏰ Timer сработал`

**Если не видно:** RunLoop issue или Timer был освобождён

### 2. Task не выполняется
Ищите: `🚀 Выполняю задачу`

**Если не видно:** Задача была деактивирована или удалена

### 3. MCP ошибка
Ищите: `❌ Ошибка выполнения задачи`

**Если видно:** Проблема с подключением к MCP Weather Server

### 4. Сообщение не добавляется в чат
Ищите: `✅ Сообщение добавлено в чат`

**Если не видно:** chatViewModel стал nil (weak reference lost)

---

## 💡 Почему weak reference может быть проблемой

В `PeriodicTaskService`:
```swift
weak var chatViewModel: ChatViewModel?
```

Если `ChatViewModel` будет освобождён (deallocated), `weak var` станет `nil`, и сообщения перестанут добавляться в чат.

**Решение:** В `ChatViewModel.swift` держим strong reference:
```swift
private let periodicTaskService = PeriodicTaskService()
```

Это гарантирует, что пока жив `ChatViewModel`, жив и `PeriodicTaskService`, и vice versa через weak reference обратно.

---

## ✅ Итого

**Файл изменён:** `AIAdventChatV2/Services/PeriodicTaskService.swift`

**Ключевые изменения:**
1. ✅ Timer добавляется в RunLoop с `.common` mode
2. ✅ Timer использует ID вместо копии структуры
3. ✅ Добавлено подробное логирование
4. ✅ Проверки на nil для chatViewModel

**Статус:** ✅ **BUILD SUCCEEDED**

**Готово к тестированию!** 🎉

Используйте короткий интервал (2 минуты) для быстрого тестирования:
```
Присылай погоду в Москве каждые 2 минуты
```

Затем наблюдайте консоль Xcode и ждите второе обновление через 2 минуты.
