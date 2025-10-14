# Исправление ошибки "Organization is not available, not ready or not found"

## 🔴 Проблема

При попытке получить задачи из Yandex Tracker появляется ошибка:
```
Failed to fetch issues: Access forbidden (403).
Check that your OAuth token has 'tracker:read' permission and Organization ID is correct.
Details: {"errors":{},"errorMessages":["Organization is not available, not ready or not found"],"errorCode":620345}
```

**Код ошибки 620345** означает, что **организация не найдена или недоступна**.

---

## 🔍 Причины

### 1. Неверный Organization ID ⚠️

**Самая частая причина!**

Organization ID должен быть **числовым ID организации**, а не её названием или ссылкой.

### 2. OAuth Token не привязан к этой организации

OAuth токен создан для одной организации, а вы пытаетесь получить доступ к другой.

### 3. У пользователя нет доступа к Yandex Tracker в этой организации

Ваш аккаунт не добавлен в организацию или Tracker не активирован.

---

## ✅ Решение 1: Найти правильный Organization ID

### Способ 1: Через URL Yandex Tracker

1. Откройте https://tracker.yandex.ru
2. Войдите в свой аккаунт
3. Посмотрите в адресную строку:

```
https://tracker.yandex.ru/issues
```

Если URL не содержит цифр, перейдите в настройки:

```
Settings → Organization (слева внизу) → About
```

Там будет указан **Organization ID** - это **ЧИСЛО**, например: `12345678`

### Способ 2: Через API

Выполните запрос для получения списка доступных организаций:

```bash
curl -H "Authorization: OAuth YOUR_OAUTH_TOKEN" \
     https://api.tracker.yandex.net/v2/myself
```

Ответ будет содержать информацию о вашем аккаунте и доступных организациях.

### Способ 3: Через Yandex 360

1. Откройте https://admin.yandex.ru/
2. Войдите в аккаунт
3. Выберите организацию
4. Посмотрите в URL:

```
https://admin.yandex.ru/portal/services/tracker?organization_id=12345678
                                                                ^^^^^^^^
                                                           Это ваш Organization ID
```

### Способ 4: Через Yandex Cloud Console

1. Откройте https://console.cloud.yandex.ru/
2. Выберите облако
3. Перейдите в раздел **"Управление доступом"**
4. В верхней части страницы будет **Organization ID**

---

## ✅ Решение 2: Проверить доступ к Tracker

### Убедитесь, что у вас есть доступ к Yandex Tracker:

1. Откройте https://tracker.yandex.ru
2. Войдите в аккаунт
3. Если видите список задач или очередей - **доступ есть** ✅
4. Если видите "Доступ запрещён" или пустую страницу - **доступа нет** ❌

### Если доступа нет:

#### Вариант 1: Активировать Tracker для организации

1. Откройте https://admin.yandex.ru/
2. Выберите вашу организацию
3. Перейдите в **"Сервисы"**
4. Найдите **"Yandex Tracker"**
5. Нажмите **"Подключить"** или **"Активировать"**

#### Вариант 2: Попросить администратора добавить вас

Свяжитесь с администратором организации и попросите:
1. Добавить вас в организацию (если не добавлены)
2. Дать права на использование Yandex Tracker
3. Добавить в нужные очереди задач

---

## ✅ Решение 3: Пересоздать OAuth Token для нужной организации

**ВАЖНО:** OAuth токен привязан к конкретной организации!

Если вы создавали токен, будучи залогиненным в одной организации, а пытаетесь использовать его для другой - **это не сработает**.

### Шаги:

1. **Выйдите** из всех аккаунтов Yandex в браузере
2. **Войдите** в аккаунт, который **имеет доступ** к нужной организации
3. Откройте https://tracker.yandex.ru и убедитесь, что видите задачи **именно этой организации**
4. Откройте https://oauth.yandex.ru/
5. Создайте **новое** OAuth приложение или используйте существующее
6. Убедитесь, что выбраны права:
   - ☑️ `tracker:read`
   - ☑️ `tracker:write`
7. Получите **новый** OAuth токен через `get_yandex_token.html` или прямую ссылку:

```
https://oauth.yandex.ru/authorize?response_type=token&client_id=ВАШ_CLIENT_ID&scope=tracker:read%20tracker:write
```

8. **Обновите** токен в настройках приложения

---

## ✅ Решение 4: Проверить правильность данных

### Чек-лист:

- [ ] **Organization ID** - это **число** (например, `12345678`), а не название организации
- [ ] **Organization ID** взят из URL или настроек **именно той организации**, к которой у вас есть доступ
- [ ] **OAuth Token** получен **после** входа в аккаунт с доступом к этой организации
- [ ] Вы можете открыть https://tracker.yandex.ru и видите задачи
- [ ] OAuth Token имеет права `tracker:read` и `tracker:write`
- [ ] Токен скопирован **полностью** (начинается с `y0_AgA...`)

---

## 🧪 Тестирование через curl

Проверьте доступ вручную через curl:

```bash
curl -H "Authorization: OAuth YOUR_OAUTH_TOKEN" \
     -H "X-Org-ID: YOUR_ORG_ID" \
     -H "Content-Type: application/json" \
     https://api.tracker.yandex.net/v2/issues?perPage=10
```

### Ожидаемые результаты:

#### ✅ Если всё правильно:
```json
[
  {
    "key": "PROJECT-123",
    "summary": "Task title",
    "status": { ... }
  }
]
```

#### ❌ Если Organization ID неверный:
```json
{
  "errors": {},
  "errorMessages": ["Organization is not available, not ready or not found"],
  "errorCode": 620345
}
```

#### ❌ Если токен неверный:
```json
{
  "errors": {},
  "errorMessages": ["Unauthorized"],
  "statusCode": 401
}
```

---

## 🔧 Улучшенная обработка ошибок

Я могу улучшить код MCP сервера, чтобы он показывал более понятные сообщения об ошибках:

### В файле `mcp-yandex-tracker/src/index.ts`:

```typescript
if (status === 403) {
  // Проверяем конкретный код ошибки
  if (errorData?.errorCode === 620345) {
    detailedMessage += `: Organization not found (620345). Check that your Organization ID is correct. It should be a numeric ID like '12345678', not organization name.`;
  } else {
    detailedMessage += `: Access forbidden (403). Check that your OAuth token has 'tracker:read' permission and Organization ID is correct.`;
  }
}
```

---

## 📋 Пошаговая инструкция для пользователя

### Шаг 1: Найдите Organization ID

1. Откройте https://tracker.yandex.ru
2. Войдите в аккаунт
3. Нажмите на иконку **Settings** (⚙️) внизу слева
4. Выберите **"About organization"**
5. Скопируйте **Organization ID** (это число!)

Альтернативно - посмотрите в URL:
```
https://tracker.yandex.ru/admin/orgs/12345678/settings
                                    ^^^^^^^^
                                Это ваш Organization ID
```

### Шаг 2: Проверьте доступ

1. Убедитесь, что вы видите задачи на https://tracker.yandex.ru
2. Если не видите - попросите администратора добавить вас

### Шаг 3: Создайте OAuth Token

1. **НЕ ВЫХОДИТЕ** из Yandex в браузере (должны быть залогинены!)
2. Откройте `get_yandex_token.html`
3. Введите Client ID вашего OAuth приложения
4. Откройте сгенерированную ссылку
5. Разрешите доступ
6. Скопируйте токен из адресной строки (всё после `#access_token=`)

### Шаг 4: Обновите настройки

1. Откройте настройки приложения (⚙️)
2. Вставьте **Organization ID** (число!)
3. Вставьте **OAuth Token** (начинается с `y0_AgA...`)
4. Нажмите **"Проверить подключение"**

---

## 🎯 Итого

### Основная причина ошибки 620345:
**Неверный Organization ID или токен не имеет доступа к этой организации**

### Решение:
1. Найдите правильный Organization ID (это число!)
2. Убедитесь, что у вас есть доступ к Tracker
3. Пересоздайте OAuth Token, будучи залогиненным в нужную организацию
4. Обновите данные в настройках приложения

**После исправления подключение должно заработать! 🚀**
