# Исправление ошибки "MCP client is not initialized"

## ✅ Что исправлено

1. ✅ Добавлен вызов `mcpService.initializeClient()` перед подключением
2. ✅ Улучшен поиск пути к MCP серверу (проверяет несколько возможных путей)
3. ✅ Добавлены подробные логи для отладки

---

## 🔧 Настройка рабочей директории в Xcode

Чтобы приложение могло найти MCP сервер, нужно настроить рабочую директорию:

### Способ 1: Через схему Xcode (РЕКОМЕНДУЕТСЯ)

1. **Откройте Xcode**
2. **Нажмите на схему** (рядом с кнопкой Play/Stop)
   ```
   [AIAdventChatV2] > My Mac
        ↑
   Нажмите сюда
   ```

3. **Выберите "Edit Scheme..."**

4. **Слева выберите "Run"**

5. **Вкладка "Options"**

6. **Найдите "Working Directory"**

7. **Отметьте чекбокс** ☑️ **"Use custom working directory:"**

8. **Нажмите иконку папки** и выберите:
   ```
   /Users/sergeymarkov/Documents/PetProject/AIAdventChatV2
   ```

9. **Нажмите "Close"**

10. **Запустите приложение заново**

### Визуально:

```
┌──────────────────────────────────────┐
│ Edit Scheme                          │
├──────────────────────────────────────┤
│ ▼ Run                                │
│   • Info                             │
│   • Arguments                        │
│   • Options            ← Выберите    │
│   • Diagnostics                      │
│                                      │
│ Working Directory:                   │
│ ☑ Use custom working directory:     │
│ [📁 /Users/.../AIAdventChatV2  ]    │
│                                      │
│                  [Close]             │
└──────────────────────────────────────┘
```

---

## 🧪 Проверка после исправления

### 1. Запустите приложение из Xcode

### 2. Откройте настройки и проверьте подключение

Вы должны увидеть в консоли Xcode:
```
⚠️ MCP server not found at: /Users/.../mcp-yandex-tracker/build/index.js
⚠️ MCP server not found at: /Users/.../Documents/.../index.js
✅ Found MCP server at: mcp-yandex-tracker/build/index.js
```

Или:
```
✅ Found MCP server at: /Users/.../AIAdventChatV2/mcp-yandex-tracker/build/index.js
```

### 3. Результат проверки

Если всё настроено правильно:
- ✅ "Подключение успешно!"
- Или более детальная ошибка о том, что именно не так (не найден сервер, неверный токен и т.д.)

---

## 🐛 Если всё ещё не работает

### Проблема: "MCP сервер не найден"

**Причина:** Приложение не может найти файл `mcp-yandex-tracker/build/index.js`

**Решение 1: Проверьте, что сервер собран**
```bash
cd /Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/mcp-yandex-tracker
ls -la build/index.js
```

Если файла нет:
```bash
npm install
npm run build
```

**Решение 2: Укажите полный путь в коде**

Если автоматический поиск не работает, можно указать путь вручную.

Откройте `YandexTrackerService.swift` и замените строку 72 на:
```swift
"/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/mcp-yandex-tracker/build/index.js",
```

### Проблема: "MCP client is not initialized"

**Причина:** Клиент не инициализирован перед подключением

**Решение:** Уже исправлено! Теперь `initializeClient()` вызывается автоматически.

### Проблема: Другие ошибки MCP

Проверьте логи в консоли Xcode (View → Debug Area → Activate Console)

---

## 📝 Где смотреть логи

### В консоли Xcode:

```
✅ Found MCP server at: ...
📥 Received serverCommand: ["node", "/path/to/index.js"]
🚀 Executing: /usr/local/bin/node /path/to/index.js
MCP Client initialized: AIAdventChat v2.0.0
Starting MCP server process...
Connecting to MCP server...
MCP Server stderr: Yandex Tracker MCP Server running on stdio
```

Если видите эти логи - всё работает правильно!

---

## ✅ Чек-лист проверки

Перед тестом подключения убедитесь:

- [ ] MCP сервер собран: `ls mcp-yandex-tracker/build/index.js` возвращает файл
- [ ] Установлен Node.js: `node --version` показывает версию
- [ ] Working Directory настроена в Xcode (Scheme → Run → Options)
- [ ] Приложение перезапущено после изменений
- [ ] В консоли видно "✅ Found MCP server at: ..."

Если все пункты ✅ - можно проверять подключение к Yandex Tracker!

---

## 🎯 Тестирование

### 1. Запустите приложение из Xcode

### 2. Откройте Settings (⚙️)

### 3. Заполните Yandex Tracker:
- Organization ID
- OAuth Token

### 4. Нажмите "Проверить подключение"

### Ожидаемый результат:

#### ✅ Успех:
```
✅ Подключение успешно! Данные Yandex Tracker верны.
```

#### ❌ Ошибки с пояснениями:
```
❌ Неверный OAuth Token. Проверьте токен...
❌ Organization ID не найден...
❌ MCP сервер не найден. Убедитесь, что mcp-yandex-tracker/build/index.js существует. Текущая директория: /Users/.../AIAdventChatV2
```

---

## 🚀 Готово!

После настройки Working Directory и пересборки всё должно работать:

1. ✅ MCP клиент инициализируется
2. ✅ Путь к серверу находится автоматически
3. ✅ Подключение к Yandex Tracker работает
4. ✅ Кнопка проверки показывает детальные результаты

**BUILD SUCCEEDED - можно тестировать! 🎉**
