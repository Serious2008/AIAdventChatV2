# Smoke Test — AIAdventChatV2 (macos-ui-automation MCP)

Запускает smoke-сценарии тестирования macOS-приложения AIAdventChatV2 через macos-ui-automation MCP.

**Использование:**
```
/smoke-test           # все сценарии (1-4)
/smoke-test 1         # только сценарий 1
/smoke-test 2,3       # сценарии 2 и 3
```

## Механика работы

Для взаимодействия с UI используй ТОЛЬКО инструменты macos-ui-automation MCP:
- `mcp__macos-ui-automation__find_elements_in_app` — найти элемент и получить координаты
- `mcp__macos-ui-automation__click_at_position` — кликнуть по координатам (центр = x + w/2, y + h/2)
- `mcp__macos-ui-automation__type_text_to_element_by_selector` — ввести текст
- `mcp__macos-ui-automation__get_app_overview` — быстрая проверка что приложение запущено

**Перед каждым сценарием** активируй приложение:
```bash
open -a AIAdventChatV2 && sleep 1
```

**После каждого действия** делай повторный `find_elements_in_app` чтобы убедиться что результат корректный.

## AXIdentifiers приложения

| Идентификатор        | Элемент                         |
|----------------------|---------------------------------|
| `input_message`      | Поле ввода сообщения            |
| `btn_send`           | Кнопка отправки                 |
| `btn_settings`       | Кнопка настроек (⚙)             |
| `btn_user_profile`   | Кнопка профиля (👤)             |
| `btn_clear_chat`     | Очистить чат (в toolbar menu)   |
| `btn_toolbar_menu`   | Меню тулбара (⋯)                |
| `btn_settings_done`  | Кнопка «Готово» в настройках    |
| `btn_temp_00`        | Temperature 0.0                 |
| `btn_temp_07`        | Temperature 0.7                 |
| `btn_temp_10`        | Temperature 1.0                 |
| `btn_temp_12`        | Temperature 1.2                 |
| `slider_temperature` | Слайдер температуры             |

## Сценарии

---

### Сценарий 1: Smoke Launch — запуск и базовая проверка

**Цель:** приложение запущено и показывает интерфейс чата.

**Шаги:**

1. Запусти приложение если не запущено:
   ```bash
   open -a AIAdventChatV2 && sleep 2
   ```

2. Вызови `find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='input_message')]")`.

3. Проверь результат:
   - Найден элемент `input_message` с `enabled: true` → признак что чат активен
   - Найден `btn_send` → кнопка отправки присутствует
   - Найден `btn_settings` → шапка чата отрисована

4. Вызови `find_elements_in_app` с широким запросом `$..[?(@.ax_identifier)]` и убедись что нет элементов с текстом «ошибка», «Error», «Crash».

**Критерий PASSED:** `input_message` найден и `enabled: true`, `btn_send` найден.
**Критерий FAILED:** элементы не найдены, приложение не запустилось или показывает ошибку.

---

### Сценарий 2: Send Message — отправка сообщения и получение ответа AI

**Цель:** сообщение отправляется, AI отвечает.

**Шаги:**

1. Активируй приложение:
   ```bash
   open -a AIAdventChatV2 && sleep 1
   ```

2. Найди поле ввода:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='input_message')]")
   ```
   Запомни `position` и `size`. Центр = (x + w/2, y + h/2).

3. Кликни на поле:
   ```
   click_at_position(x=<центр_x>, y=<центр_y>)
   ```

4. Введи тестовое сообщение через `type_text_to_element_by_selector`:
   ```
   type_text_to_element_by_selector(
     jsonpath_selector="$..[?(@.ax_identifier=='input_message')]",
     text="Smoke test MCP: ответь одним словом ОК"
   )
   ```
   Если инструмент не сработал — используй `click_at_position` на поле и затем снова попробуй.

5. Запомни текущее количество сообщений: найди все `AXStaticText` с текстом вида «N сообщений».

6. Найди кнопку отправки и кликни:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_send')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   ```

7. Подожди ответ AI (до 60 секунд):
   ```bash
   sleep 15
   ```
   Затем проверь `find_elements_in_app` снова — ищи новые `AXStaticText` в списке сообщений.
   Если ответа нет — жди ещё `sleep 20` и снова проверь.

8. Проверь что счётчик сообщений увеличился (был N, стал N+2 — вопрос + ответ).

**Критерий PASSED:** в чате появилось сообщение пользователя и ответ AI (счётчик увеличился на 2).
**Критерий FAILED:** сообщение не отправилось, или ответ AI не пришёл за 60 сек, или ошибка 404/500.

---

### Сценарий 3: Change Settings — изменение температуры

**Цель:** температура меняется и сохраняется после переоткрытия настроек.

**Шаги:**

1. Активируй приложение:
   ```bash
   open -a AIAdventChatV2 && sleep 1
   ```

2. Открой настройки — найди и кликни `btn_settings`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_settings')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 1
   ```

3. Убедись что настройки открылись — найди `btn_settings_done`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_settings_done')]")
   ```
   Если не найден → FAILED: настройки не открылись.

4. Найди кнопки температуры (`btn_temp_00`, `btn_temp_07`, `btn_temp_10`, `btn_temp_12`) и определи какая сейчас активна (она будет выделена — `value` или другой признак).

5. Выбери другое значение температуры (если активна 0.7 → нажми 1.0):
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_temp_10')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 0.5
   ```

6. Закрой настройки — найди и кликни `btn_settings_done`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_settings_done')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 1
   ```

7. Снова открой настройки (шаг 2) и проверь что температура сохранилась.

**Критерий PASSED:** кнопка выбранной температуры осталась активной после переоткрытия.
**Критерий FAILED:** настройки не открылись, кнопки не найдены, или значение сбросилось.

---

### Сценарий 4: User Profile — добавить навык в профиль

**Цель:** навык добавляется, сохраняется и остаётся после переоткрытия профиля.

**Шаги:**

1. Активируй приложение:
   ```bash
   open -a AIAdventChatV2 && sleep 1
   ```

2. Открой профиль — найди и кликни `btn_user_profile`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_user_profile')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 1
   ```

3. Убедись что профиль открылся — найди `btn_profile_save`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_profile_save')]")
   ```
   Если не найден → FAILED: профиль не открылся.

4. Найди поле ввода навыка `input_profile_skills` и кликни:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='input_profile_skills')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   ```

5. Введи тестовый навык:
   ```
   type_text_to_element_by_selector(
     jsonpath_selector="$..[?(@.ax_identifier=='input_profile_skills')]",
     text="AutomationTest"
   )
   ```

6. Кликни кнопку добавления `btn_profile_skills_add`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_profile_skills_add')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 0.5
   ```

7. Убедись что тег появился — ищи `tag_profile_skills_0` (или следующий индекс):
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier && @.ax_identifier =~ /tag_profile_skills_/)]")
   ```
   Проверь что среди найденных элементов есть текст «AutomationTest».

8. Сохрани и закрой — кликни `btn_profile_save`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_profile_save')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 1
   ```

9. Снова открой профиль (шаг 2) и проверь что навык «AutomationTest» всё ещё отображается среди тегов `tag_profile_skills_*`.

10. Cleanup: найди кнопку удаления навыка `btn_profile_skills_delete_<index>` и удали «AutomationTest», затем сохрани.

**Критерий PASSED:** навык добавился (тег виден), сохранился после переоткрытия.
**Критерий FAILED:** поле не найдено, тег не появился, или навык не сохранился.

---

### Сценарий 5: Clear Chat — очистка истории чата

**Цель:** кнопка очистки чата работает.

**Шаги:**

1. Активируй приложение:
   ```bash
   open -a AIAdventChatV2 && sleep 1
   ```

2. Убедись что в чате есть сообщения — ищи `AXStaticText` со счётчиком «N сообщений» (N > 0):
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.role=='AXStaticText')]")
   ```
   Если чат пуст — сначала отправь одно сообщение (см. Сценарий 2, шаги 2-6).

3. Открой toolbar menu — найди и кликни `btn_toolbar_menu`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_toolbar_menu')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 0.5
   ```

4. Найди и кликни `btn_clear_chat`:
   ```
   find_elements_in_app(app_name="AIAdventChatV2", jsonpath_selector="$..[?(@.ax_identifier=='btn_clear_chat')]")
   click_at_position(x=<центр_x>, y=<центр_y>)
   sleep 1
   ```

5. Если появился диалог подтверждения — найди кнопку с текстом «Очистить» или «Да» среди `AXButton` и кликни по ней.

6. Проверь что чат очищен — найди элемент с текстом «Добро пожаловать» или убедись что счётчик сообщений исчез / равен 0.

7. Убедись что `input_message` всё ещё `enabled: true` (интерфейс функционирует).

**Критерий PASSED:** чат пуст (нет сообщений), поле ввода доступно.
**Критерий FAILED:** кнопка не найдена, сообщения не удалились, интерфейс сломан.

---

## Итоговый отчёт

После выполнения всех сценариев выведи итог:

```
═══════════════════════════════════════
  SMOKE TEST — ИТОГ (macos-ui-automation MCP)
═══════════════════════════════════════
  1. ✅/❌ Smoke Launch — ...
  2. ✅/❌ Send Message — ...
  3. ✅/❌ Change Settings — ...
  4. ✅/❌ User Profile — ...
  5. ✅/❌ Clear Chat — ...
═══════════════════════════════════════
  Итого: N/5 прошли
═══════════════════════════════════════
```

Для каждого ❌ FAILED укажи:
- Какой шаг упал
- Что именно ожидалось и что получилось
- Какие элементы были найдены / не найдены
