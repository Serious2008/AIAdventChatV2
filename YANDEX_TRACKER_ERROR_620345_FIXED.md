# ✅ Исправлена ошибка 620345 - Organization not found

## 🔴 Проблема

При попытке получить задачи из Yandex Tracker появлялась ошибка:

```
Failed to get stats: Error: Failed to fetch issues: Access forbidden (403).
Check that your OAuth token has 'tracker:read' permission and Organization ID is correct.
Details: {"errors":{},"errorMessages":["Organization is not available, not ready or not found"],"errorCode":620345}
```

**Причина:** Organization ID был неверным или недоступным.

---

## ✅ Что исправлено

### 1. Улучшена обработка ошибки в MCP сервере

**Файл:** `mcp-yandex-tracker/src/index.ts`

Теперь MCP сервер распознаёт код ошибки **620345** и показывает понятное сообщение:

```typescript
if (status === 403) {
  // Проверяем конкретный код ошибки Yandex Tracker
  if (errorData?.errorCode === 620345) {
    detailedMessage += `: Organization not found (error code 620345). Your Organization ID is incorrect or you don't have access to this organization. Organization ID should be a numeric ID (like '12345678'), not organization name. Check https://tracker.yandex.ru → Settings → About to find the correct ID.`;
  } else {
    detailedMessage += `: Access forbidden (403). Check that your OAuth token has 'tracker:read' permission and Organization ID is correct.`;
  }
}
```

### 2. Улучшена обработка ошибки в UI

**Файл:** `AIAdventChatV2/Views/SettingsView.swift`

Добавлена специальная обработка ошибки 620345 в функции `testYandexTrackerConnection()`:

```swift
if errorMessage.contains("620345") || errorMessage.contains("Organization not found") {
    trackerTestResult = "❌ Organization ID неверный или недоступен. Organization ID должен быть ЧИСЛОМ (например: 12345678). Найдите его в Yandex Tracker → Settings → About organization."
}
```

### 3. Улучшена подсказка в поле Organization ID

**Файл:** `AIAdventChatV2/Views/SettingsView.swift`

Теперь подсказка явно указывает, что Organization ID - это **ЧИСЛО**:

```swift
Text("Organization ID - это ЧИСЛО (например: 12345678)")
    .font(.caption)
    .foregroundColor(.secondary)
    .fontWeight(.semibold)
Text("Найдите в: Yandex Tracker → Settings → About organization")
    .font(.caption)
    .foregroundColor(.secondary)
```

### 4. Создана подробная документация

Созданы новые файлы документации:

- **FIX_ORGANIZATION_ERROR.md** - Подробное описание проблемы и решения
- **HOW_TO_FIND_ORG_ID.md** - Пошаговая инструкция поиска Organization ID
- **YANDEX_TRACKER_ERROR_620345_FIXED.md** (этот файл) - Краткое описание исправлений

### 5. Пересобран MCP сервер

Выполнено:
```bash
npm run build
```

Результат: ✅ BUILD SUCCEEDED

---

## 📋 Как найти правильный Organization ID

### Способ 1: Через интерфейс Yandex Tracker (РЕКОМЕНДУЕТСЯ)

1. Откройте https://tracker.yandex.ru
2. Войдите в аккаунт
3. Нажмите **⚙️ Settings** (внизу слева)
4. Выберите **"About organization"**
5. Скопируйте **Organization ID** (это число!)

### Способ 2: Из URL

Посмотрите в адресную строку:

```
https://tracker.yandex.ru/admin/orgs/12345678/settings
                                    ^^^^^^^^
                           Это ваш Organization ID!
```

### ⚠️ Важно!

Organization ID - это **ЧИСЛО**, например:
- ✅ `12345678`
- ✅ `87654321`
- ❌ `my-company` (название)
- ❌ `company.yandex` (домен)
- ❌ Ваш Client ID (это другое!)

---

## 🧪 Как проверить исправление

### 1. Перезапустите приложение из Xcode

После пересборки MCP сервера обязательно перезапустите приложение.

### 2. Найдите правильный Organization ID

Используйте инструкцию выше, чтобы найти **числовой** Organization ID.

### 3. Обновите настройки

1. Откройте Settings (⚙️)
2. В разделе **Yandex Tracker** введите Organization ID (число!)
3. Убедитесь, что OAuth Token заполнен
4. Нажмите **"Проверить подключение"**

### 4. Ожидаемые результаты

#### ✅ Если Organization ID правильный:
```
✅ Подключение успешно! Данные Yandex Tracker верны.
```

#### ❌ Если Organization ID неверный:
```
❌ Organization ID неверный или недоступен. Organization ID должен быть ЧИСЛОМ (например: 12345678).
Найдите его в Yandex Tracker → Settings → About organization.
```

Теперь сообщение об ошибке **явно** указывает на проблему!

#### ❌ Если OAuth Token неверный:
```
❌ Неверный OAuth Token. Проверьте токен в настройках Yandex OAuth.
```

#### ❌ Если токен без прав:
```
❌ Доступ запрещён (403). Проверьте, что OAuth Token имеет права 'tracker:read' и 'tracker:write',
и что Organization ID правильный.
```

---

## 🎯 Чек-лист перед использованием

Убедитесь, что:

- [ ] Organization ID - это **число** (найдено через Settings → About organization)
- [ ] Вы можете открыть https://tracker.yandex.ru и видите задачи
- [ ] OAuth Token создан с правами `tracker:read` и `tracker:write`
- [ ] OAuth Token получен **после** входа в нужную организацию
- [ ] MCP сервер собран: `npm run build` в папке `mcp-yandex-tracker`
- [ ] Приложение перезапущено после изменений

---

## 📚 Дополнительная информация

Подробные инструкции смотрите в файлах:

- **HOW_TO_FIND_ORG_ID.md** - Как найти Organization ID (с визуальными примерами)
- **FIX_ORGANIZATION_ERROR.md** - Полное описание проблемы и всех возможных решений
- **GET_YANDEX_TOKEN.md** - Как получить OAuth Token с правильными правами
- **FIX_YANDEX_TRACKER_403.md** - Что делать при ошибке 403

---

## 🚀 Итого

### Что было сделано:

1. ✅ MCP сервер теперь распознаёт ошибку 620345 и показывает понятное сообщение
2. ✅ UI приложения показывает специальное сообщение для ошибки 620345
3. ✅ Подсказка в поле Organization ID явно указывает, что это ЧИСЛО
4. ✅ Создана подробная документация с пошаговыми инструкциями
5. ✅ MCP сервер пересобран

### Теперь при ошибке 620345:

- Пользователь сразу видит, что Organization ID должен быть **числом**
- Сообщение об ошибке подсказывает, **где** найти правильный ID
- UI показывает пример правильного формата (`12345678`)

**Проблема решена! 🎉**
