#!/usr/bin/env python3
"""
Computer Use smoke-тест для AIAdventChatV2 (macOS SwiftUI)
Использует Anthropic API с computer use инструментами.

Запуск:
    python3 computer_use_test.py                        # сценарий 1 (smoke launch)
    python3 computer_use_test.py --scenario 2           # send message
    python3 computer_use_test.py --scenario 3           # change settings
    python3 computer_use_test.py --scenario 4           # user profile
    python3 computer_use_test.py --scenario 5           # clear chat
    python3 computer_use_test.py --scenario all         # все сценарии подряд
    python3 computer_use_test.py --task "своя задача"   # произвольная задача

Зависимости:
    pip install anthropic
    brew install cliclick          # управление мышью/клавиатурой
"""

import anthropic
import base64
import subprocess
import time
import argparse
import sys
import os
from datetime import datetime

# ── Конфигурация ──────────────────────────────────────────────────────────────

APP_NAME = "AIAdventChatV2"
SCREENSHOT_DIR = "/tmp/cu_screenshots"
SCREENSHOT_PATH = "/tmp/cu_screenshot.png"
MAX_ITERATIONS = 35
MAX_SCREENSHOTS_IN_HISTORY = 3
STEP_DELAY = 1.0

MODEL = "claude-sonnet-4-6"

SCREEN_WIDTH = 2560
SCREEN_HEIGHT = 1664

# ── Smoke-сценарии ────────────────────────────────────────────────────────────

SCENARIOS = {
    1: {
        "name": "Smoke Launch — запуск и базовая проверка",
        "task": """
Smoke-тест #1: Запуск приложения и базовая проверка.

Шаги:
1. Проверь, открыто ли приложение AIAdventChatV2. Если нет — открой его через Spotlight (Cmd+Space → "AIAdventChatV2" → Enter).
2. Подожди 3 секунды пока приложение загрузится.
3. Сделай скриншот и проверь:
   - Виден экран чата (список сообщений или пустое поле)
   - Видно поле ввода текста (TextField или TextEditor)
   - Нет алертов с ошибками
4. Если всё корректно — сообщи PASSED.
   Если что-то сломалось — сообщи FAILED с описанием проблемы.

Критерий прохождения: приложение запустилось и показывает интерфейс чата.
"""
    },
    2: {
        "name": "Send Message — отправить сообщение",
        "task": """
Smoke-тест #2: Отправка сообщения. Выполни СТРОГО по шагам, без отклонений.

ШАГ 1:
  bash: open -a AIAdventChatV2
  bash: sleep 2
  computer screenshot

ШАГ 2 — клик на поле ввода:
  computer left_click координата поля "Введите сообщение..." внизу экрана
  computer screenshot

ШАГ 3 — ввод текста (только так, через computer type):
  computer type: "Smoke test: reply with one word OK"
  computer screenshot — убедись что текст появился

ШАГ 4 — отправка:
  bash: ax_click btn_send
  computer screenshot — синий пузырь пользователя должен появиться справа

ШАГ 5 — ожидание ответа AI (жди ДО 60 секунд):
  bash: sleep 20
  computer screenshot
  bash: sleep 20
  computer screenshot
  bash: sleep 20
  computer screenshot
  Ищи новый пузырь AI слева. Счётчик "N сообщений" должен стать 2.

ШАГ 6 — итог:
  PASSED — если счётчик показывает 2 сообщения и виден пузырь AI.
  FAILED — если нет ответа или ошибка 404 (укажи что именно).
"""
    },
    3: {
        "name": "Change Settings — изменение настроек температуры",
        "task": """
Smoke-тест #3: Изменение настроек температуры.

Предусловие: приложение AIAdventChatV2 открыто.

ВАЖНО: используй bash-команды ax_click и ax_find для взаимодействия с элементами — они точнее, чем computer left_click.

Шаги:
1. Открой настройки: bash → ax_click btn_settings
2. Сделай скриншот — убедись что панель настроек открылась.
3. Запомни текущее значение Temperature (кнопка подсвечена синим: 0.0, 0.7, 1.0 или 1.2).
4. Нажми кнопку с другим значением: bash → ax_click btn_temp_10
   (если уже 1.0 — нажми ax_click btn_temp_07)
5. Сделай скриншот — убедись что новая кнопка подсвечена синим.
6. Закрой настройки: bash → ax_click btn_settings_done
7. Снова открой настройки: bash → ax_click btn_settings
8. Сделай скриншот — проверь что значение Temperature сохранилось (та же кнопка синяя).
9. Закрой настройки: bash → ax_click btn_settings_done
10. Сообщи PASSED если изменение сохранилось, FAILED если нет.

Критерий прохождения: настройка Temperature изменилась и сохранилась после переоткрытия.
"""
    },
    4: {
        "name": "User Profile — добавить навык в профиль",
        "task": """
Smoke-тест #4: Управление профилем пользователя.

Предусловие: приложение AIAdventChatV2 открыто.

Шаги:
1. Найди вкладку или кнопку «Профиль» (иконка человека) в боковой панели или верхнем меню.
2. Нажми на неё чтобы открыть экран профиля пользователя.
3. Сделай скриншот — должна открыться панель User Profile.
4. Найди поле «Навыки» (Skills) или кнопку добавления навыка.
5. Добавь навык: "AutomationTest" (кликни «+» или в поле ввода навыка, введи текст, нажми Enter/Add).
6. Сделай скриншот чтобы подтвердить добавление навыка в список.
7. Нажми кнопку «Сохранить» (Save) если она есть.
8. Закрой экран профиля и снова откройся — проверь что навык "AutomationTest" всё ещё в списке.
9. Опционально: удали навык "AutomationTest" чтобы вернуть систему в исходное состояние.
10. Сообщи PASSED если навык добавился и сохранился, FAILED если нет.

Критерий прохождения: навык добавлен, отображается в списке и сохраняется после переоткрытия профиля.
"""
    },
    5: {
        "name": "Clear Chat — очистить историю чата",
        "task": """
Smoke-тест #5: Очистка истории чата.

Предусловие: приложение AIAdventChatV2 открыто, в чате есть хотя бы одно сообщение.

Шаги:
1. Сделай скриншот — убедись что в чате есть сообщения (если чат пуст, сначала отправь любое сообщение).
2. Найди кнопку очистки чата (иконка корзины, «Очистить» или «Clear» в toolbar или меню).
3. Нажми кнопку очистки.
4. Если появится диалог подтверждения — нажми «Да» / «Очистить» / «Delete».
5. Сделай скриншот — чат должен стать пустым (нет сообщений).
6. Убедись что поле ввода по-прежнему доступно (можно продолжать переписку).
7. Сообщи PASSED если чат очищен, FAILED если кнопка не найдена или сообщения не удалились.

Критерий прохождения: после очистки список сообщений пуст, интерфейс функционирует.
"""
    },
}

# ── Инструменты для управления macOS ─────────────────────────────────────────

_screenshot_counter = 0

def take_screenshot() -> str:
    global _screenshot_counter
    _screenshot_counter += 1
    os.makedirs(SCREENSHOT_DIR, exist_ok=True)
    numbered_path = os.path.join(SCREENSHOT_DIR, f"step_{_screenshot_counter:03d}.png")
    subprocess.run(["screencapture", "-x", "-C", numbered_path], check=True)
    print(f"  📸 Скриншот: {numbered_path}")
    with open(numbered_path, "rb") as f:
        return base64.standard_b64encode(f.read()).decode("utf-8")


def mouse_click(x: int, y: int, button: str = "left", double: bool = False):
    action = "dc" if double else {"left": "c", "right": "rc"}.get(button, "c")
    subprocess.run(["cliclick", f"{action}:{x},{y}"])
    time.sleep(0.3)


def mouse_move(x: int, y: int):
    subprocess.run(["cliclick", f"m:{x},{y}"])
    time.sleep(0.1)


def mouse_scroll(x: int, y: int, direction: str, amount: int = 3):
    delta = amount * 10
    if direction in ("up", "right"):
        delta = -delta
    script = (
        f'tell application "System Events" to scroll '
        f'at {{{x}, {y}}} by {{{0 if direction in ("up","down") else delta}, '
        f'{delta if direction in ("up","down") else 0}}}'
    )
    subprocess.run(["osascript", "-e", script])
    time.sleep(0.1)


def type_text(text: str):
    # Всегда через буфер обмена — не зависит от раскладки клавиатуры
    subprocess.run(["pbcopy"], input=text.encode("utf-8"), check=True)
    time.sleep(0.2)
    subprocess.run([
        "osascript", "-e",
        'tell application "System Events" to keystroke "v" using {command down}'
    ])
    time.sleep(0.2)


def press_key(key: str):
    parts = key.lower().replace("ctrl", "control").split("+")
    modifiers = parts[:-1]
    main_key = parts[-1]

    key_map = {
        "return": "return", "enter": "return",
        "tab": "tab", "escape": "escape", "esc": "escape",
        "space": "space", "delete": "delete", "backspace": "delete",
        "up": "up arrow", "down": "down arrow",
        "left": "left arrow", "right": "right arrow",
    }
    main_key = key_map.get(main_key, main_key)

    mod_map = {
        "command": "command down", "cmd": "command down",
        "shift": "shift down", "option": "option down",
        "alt": "option down", "control": "control down",
    }

    if modifiers:
        mods = ", ".join(mod_map.get(m, f"{m} down") for m in modifiers)
        script = f'tell application "System Events" to keystroke "{main_key}" using {{{mods}}}'
    else:
        script = f'tell application "System Events" to keystroke "{main_key}"'

    subprocess.run(["osascript", "-e", script])
    time.sleep(0.2)


def execute_tool(tool_name: str, tool_input: dict) -> str:
    if tool_name == "computer":
        action = tool_input.get("action")

        if action == "screenshot":
            return {"type": "image", "data": take_screenshot()}

        elif action == "left_click":
            x, y = tool_input["coordinate"]
            mouse_click(x, y, "left")
            return "Клик выполнен"

        elif action == "right_click":
            x, y = tool_input["coordinate"]
            mouse_click(x, y, "right")
            return "Правый клик выполнен"

        elif action == "double_click":
            x, y = tool_input["coordinate"]
            mouse_click(x, y, double=True)
            return "Двойной клик выполнен"

        elif action == "mouse_move":
            x, y = tool_input["coordinate"]
            mouse_move(x, y)
            return "Мышь перемещена"

        elif action == "type":
            type_text(tool_input.get("text", ""))
            return f"Текст введён: {tool_input.get('text', '')!r}"

        elif action == "key":
            press_key(tool_input.get("key", ""))
            return f"Клавиша нажата: {tool_input.get('key', '')}"

        elif action == "scroll":
            x, y = tool_input["coordinate"]
            direction = tool_input.get("scroll_direction") or tool_input.get("direction", "down")
            amount = tool_input.get("scroll_amount") or tool_input.get("amount", 3)
            mouse_scroll(x, y, direction, amount)
            return f"Прокрутка {direction}"

        elif action == "left_click_drag":
            start = tool_input["start_coordinate"]
            end = tool_input["coordinate"]
            mouse_move(*start)
            subprocess.run(["cliclick", f"dd:{start[0]},{start[1]}", f"du:{end[0]},{end[1]}"])
            return "Drag выполнен"

        else:
            return f"Неизвестное действие: {action}"

    elif tool_name == "bash":
        cmd = tool_input.get("command", "")

        # ax_find:<id> — найти элемент по AXIdentifier, вернуть логические координаты
        if cmd.startswith("ax_find:"):
            identifier = cmd[len("ax_find:"):].strip()
            coords = find_element_coords(identifier)
            if coords:
                return (f"AXIdentifier '{identifier}' найден в логических координатах: "
                        f"x={coords[0]}, y={coords[1]}. "
                        f"Используй ax_click:{identifier} чтобы кликнуть по нему.")
            else:
                return f"AXIdentifier '{identifier}' не найден"

        # ax_click:<id> — найти и кликнуть по элементу напрямую через cliclick (логические координаты)
        if cmd.startswith("ax_click:"):
            identifier = cmd[len("ax_click:"):].strip()
            coords = find_element_coords(identifier)
            if coords:
                subprocess.run(["cliclick", f"c:{coords[0]},{coords[1]}"])
                time.sleep(0.5)
                return f"Клик по '{identifier}' в логических координатах ({coords[0]}, {coords[1]}) выполнен."
            else:
                return f"Элемент '{identifier}' не найден — не удалось кликнуть."

        script_dir = os.path.dirname(os.path.abspath(__file__))
        env = os.environ.copy()
        env["PATH"] = script_dir + ":" + env.get("PATH", "")
        try:
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=30, env=env)
            output = result.stdout + result.stderr
            return output[:2000] if output else "(нет вывода)"
        except subprocess.TimeoutExpired:
            return f"⏰ Команда превысила таймаут 30 сек и была прервана: {cmd[:100]}"

    return f"Неизвестный инструмент: {tool_name}"


# ── Вспомогательные функции ───────────────────────────────────────────────────

def prune_image_history(messages: list) -> list:
    """Удаляет старые скриншоты из истории, оставляя последние MAX_SCREENSHOTS_IN_HISTORY."""
    image_locations = []  # (msg_idx, content_idx)
    for i, msg in enumerate(messages):
        if msg["role"] == "user" and isinstance(msg["content"], list):
            for j, block in enumerate(msg["content"]):
                if (isinstance(block, dict) and
                        block.get("type") == "tool_result" and
                        isinstance(block.get("content"), list)):
                    for item in block["content"]:
                        if isinstance(item, dict) and item.get("type") == "image":
                            image_locations.append((i, j))

    to_drop = image_locations[:-MAX_SCREENSHOTS_IN_HISTORY]
    for (mi, ci) in to_drop:
        messages[mi]["content"][ci]["content"] = "[скриншот удалён из истории]"
    return messages


def find_element_coords(identifier: str):
    """Ищет UI-элемент по AXIdentifier во всех окнах/sheets и возвращает (x, y) или None."""
    script = f'''
tell application "System Events"
    tell process "{APP_NAME}"
        set allWindows to every window
        repeat with w in allWindows
            set allEl to entire contents of w
            repeat with el in allEl
                try
                    if value of attribute "AXIdentifier" of el is "{identifier}" then
                        set pos to position of el
                        set sz to size of el
                        set cx to (item 1 of pos) + (item 1 of sz) / 2.0
                        set cy to (item 2 of pos) + (item 2 of sz) / 2.0
                        return (round cx) & "," & (round cy)
                    end if
                end try
            end repeat
        end repeat
        return ""
    end tell
end tell
'''
    result = subprocess.run(["osascript", "-e", script], capture_output=True, text=True, timeout=15)
    output = result.stdout.strip()
    if not output:
        return None
    try:
        x, y = output.split(",")
        return int(x.strip()), int(y.strip())
    except Exception:
        return None


# ── Основной цикл агента ──────────────────────────────────────────────────────

def run_scenario(scenario_num: int, api_key: str) -> tuple[bool, str]:
    """Запускает сценарий и возвращает (passed, details)."""
    scenario = SCENARIOS[scenario_num]
    return run_agent(
        task=scenario["task"],
        api_key=api_key,
        label=f"Сценарий {scenario_num}: {scenario['name']}"
    )


def run_agent(task: str, api_key: str, label: str = "Задача") -> tuple[bool, str]:
    """Запускает агента и возвращает (passed, details)."""
    global _screenshot_counter
    _screenshot_counter = 0
    client = anthropic.Anthropic(api_key=api_key)

    tools = [
        {
            "type": "computer_20251124",
            "name": "computer",
            "display_width_px": SCREEN_WIDTH,
            "display_height_px": SCREEN_HEIGHT,
            "display_number": 1,
        },
        {
            "type": "bash_20250124",
            "name": "bash",
        }
    ]

    messages = [{"role": "user", "content": task}]

    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"  Модель: {MODEL}")
    print(f"  Начало: {datetime.now().strftime('%H:%M:%S')}")
    print(f"{'='*60}\n")

    final_text = ""

    for iteration in range(MAX_ITERATIONS):
        print(f"[Итерация {iteration + 1}/{MAX_ITERATIONS}]")

        messages = prune_image_history(messages)

        response = client.beta.messages.create(
            model=MODEL,
            max_tokens=4096,
            tools=tools,
            messages=messages,
            betas=["computer-use-2025-11-24"],
            system=(
                f"Ты QA-агент, который тестирует macOS приложение {APP_NAME}. "
                "Используй computer tool для взаимодействия с UI. "
                "Делай скриншот после каждого действия чтобы видеть результат. "
                f"Разрешение экрана: {SCREEN_WIDTH}x{SCREEN_HEIGHT}. "
                "\n\n"
                "ВАЖНО — поиск и клик по UI-элементам:\n"
                "Ключевые элементы приложения имеют AXIdentifier. "
                "В PATH доступны две утилиты: ax_click и ax_find.\n"
                "ВСЕГДА используй bash с командой 'ax_click <identifier>' вместо computer left_click "
                "— это точный клик по логическим координатам, без ошибок масштаба Retina.\n"
                "Примеры:\n"
                "  ax_click btn_settings      — открыть настройки (шестерёнка)\n"
                "  ax_click btn_user_profile  — открыть профиль пользователя\n"
                "  ax_click btn_send          — кнопка отправки сообщения\n"
                "  ax_click input_message     — фокус на поле ввода сообщения\n"
                "  ax_click slider_temperature — слайдер температуры\n"
                "  ax_click btn_temp_00       — кнопка Temperature 0.0\n"
                "  ax_click btn_temp_07       — кнопка Temperature 0.7\n"
                "  ax_click btn_temp_10       — кнопка Temperature 1.0\n"
                "  ax_click btn_temp_12       — кнопка Temperature 1.2\n"
                "  ax_click btn_settings_done — закрыть панель настроек (кнопка Готово)\n"
                "  ax_click btn_toolbar_menu  — меню тулбара (⋯)\n"
                "  ax_click btn_clear_chat    — очистить чат\n"
                "  ax_find <identifier>       — найти элемент и показать координаты\n"
                "  ax_type input_message <text> — напрямую установить текст в поле (без клавиатуры!)\n"
                "\n\n"
                "ВАЖНО — активация приложения:\n"
                f"Если приложение {APP_NAME} не на переднем плане — используй ТОЛЬКО:\n"
                f"  bash → open -a {APP_NAME}\n"
                "НЕ используй osascript 'tell application ... to activate' — эта команда зависает.\n"
                "После open -a сделай скриншот чтобы убедиться что приложение активно.\n"
                "\n\n"
                "ВАЖНО — ввод текста:\n"
                "Для ввода кириллицы используй action type — скрипт автоматически применит pbcopy+paste.\n"
                "\n\n"
                "В конце выведи ОДИН из двух итогов: PASSED или FAILED, "
                "затем краткое объяснение что было проверено и что пошло не так (если FAILED)."
            ),
        )

        messages.append({"role": "assistant", "content": response.content})

        tool_results = []
        has_tool_use = False

        for block in response.content:
            if block.type == "text":
                print(f"  Claude: {block.text}")
                final_text += block.text + "\n"

            elif block.type == "tool_use":
                has_tool_use = True
                print(f"  Инструмент: {block.name} → {str(block.input)[:100]}")

                time.sleep(STEP_DELAY)
                result = execute_tool(block.name, block.input)

                if isinstance(result, dict) and result.get("type") == "image":
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": [{
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/png",
                                "data": result["data"],
                            }
                        }]
                    })
                else:
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": str(result),
                    })

        if not has_tool_use or response.stop_reason == "end_turn":
            break

        if tool_results:
            messages.append({"role": "user", "content": tool_results})

    else:
        print(f"\n⚠️  Достигнут лимит итераций ({MAX_ITERATIONS})")
        final_text += "\nFAILED — достигнут лимит итераций без завершения теста.\n"

    passed = "PASSED" in final_text.upper()
    status = "✅ PASSED" if passed else "❌ FAILED"

    print(f"\n{'='*60}")
    print(f"  Результат: {status}")
    print(f"  Конец:     {datetime.now().strftime('%H:%M:%S')}")
    print(f"{'='*60}\n")

    return passed, final_text


# ── Точка входа ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Computer Use smoke-тесты для AIAdventChatV2",
        formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument(
        "--scenario",
        type=str,
        default="1",
        help=(
            "Номер сценария (1-5) или 'all' для запуска всех.\n"
            "  1 - Smoke Launch: запуск и базовая проверка\n"
            "  2 - Send Message: отправить сообщение и получить ответ\n"
            "  3 - Change Settings: изменить температуру в настройках\n"
            "  4 - User Profile: добавить навык в профиль\n"
            "  5 - Clear Chat: очистить историю чата\n"
            "  all - все сценарии подряд"
        )
    )
    parser.add_argument(
        "--task",
        type=str,
        default=None,
        help="Произвольная задача для агента (игнорирует --scenario)"
    )
    parser.add_argument(
        "--api-key",
        type=str,
        default=os.environ.get("ANTHROPIC_API_KEY", ""),
        help="Anthropic API ключ (или ANTHROPIC_API_KEY env)"
    )
    parser.add_argument(
        "--json-output",
        type=str,
        default=None,
        metavar="FILE",
        help="Записать результаты в JSON-файл (используется оркестратором)"
    )
    args = parser.parse_args()

    if not args.api_key:
        print("❌ Укажи API ключ: --api-key sk-ant-... или export ANTHROPIC_API_KEY=...")
        sys.exit(1)

    if args.task:
        run_agent(args.task, args.api_key)
        return

    import json as _json

    if args.scenario == "all":
        results = {}
        for num in sorted(SCENARIOS.keys()):
            passed, details = run_scenario(num, args.api_key)
            results[num] = {"passed": passed, "name": SCENARIOS[num]["name"], "details": details}
            time.sleep(2)

        print("\n" + "="*60)
        print("  ИТОГОВЫЙ ОТЧЁТ")
        print("="*60)
        for num, r in results.items():
            status = "✅ PASSED" if r["passed"] else "❌ FAILED"
            print(f"  Сценарий {num}: {status} — {r['name']}")
        total = sum(r["passed"] for r in results.values())
        print(f"\n  Итого: {total}/{len(results)} сценариев прошли")
        print("="*60)

        if args.json_output:
            payload = {str(k): v for k, v in results.items()}
            with open(args.json_output, "w", encoding="utf-8") as f:
                _json.dump(payload, f, ensure_ascii=False, indent=2)
            print(f"\n📄 Результаты записаны в {args.json_output}")
    else:
        try:
            scenario_num = int(args.scenario)
        except ValueError:
            print(f"❌ Неверный номер сценария: {args.scenario}. Используй 1-5 или 'all'.")
            sys.exit(1)

        if scenario_num not in SCENARIOS:
            print(f"❌ Сценарий {scenario_num} не найден. Доступны: 1-5.")
            sys.exit(1)

        passed, details = run_scenario(scenario_num, args.api_key)

        if args.json_output:
            payload = {
                str(scenario_num): {
                    "passed": passed,
                    "name": SCENARIOS[scenario_num]["name"],
                    "details": details,
                }
            }
            with open(args.json_output, "w", encoding="utf-8") as f:
                _json.dump(payload, f, ensure_ascii=False, indent=2)
            print(f"\n📄 Результаты записаны в {args.json_output}")


if __name__ == "__main__":
    main()
