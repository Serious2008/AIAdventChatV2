#!/usr/bin/env python3
"""
Оркестратор: smoke-тесты → bug-report → фикс → повтор.

Запуск (из Claude Code или терминала):
    python3 smoke_fix_loop.py --scenarios 1,2,3
    python3 smoke_fix_loop.py --scenarios all

Возвращает exit-код:
    0 — все тесты PASSED
    1 — есть FAILED, bug-репорты записаны в /tmp/smoke_bug_reports/

Оркестратор только запускает тесты и генерирует bug-репорты.
Исправление — задача Claude Code (bug-fix skill).
После исправления — снова запустить smoke_fix_loop.py.
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime

RESULTS_FILE = "/tmp/smoke_results.json"
BUG_REPORTS_DIR = "/tmp/smoke_bug_reports"
TEST_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "computer_use_test.py")

SCENARIO_NAMES = {
    "1": "Smoke Launch — запуск и базовая проверка",
    "2": "Send Message — отправка сообщения и получение ответа AI",
    "3": "Change Settings — изменение настроек температуры",
    "4": "User Profile — добавить навык в профиль",
    "5": "Clear Chat — очистить историю чата",
}


def run_tests(scenarios: str, api_key: str) -> dict:
    """Запускает computer_use_test.py и возвращает JSON-результаты."""
    cmd = [
        sys.executable, TEST_SCRIPT,
        "--scenario", scenarios,
        "--json-output", RESULTS_FILE,
        "--api-key", api_key,
    ]
    print(f"\n🚀 Запуск тестов: сценарии={scenarios}")
    print(f"   Команда: {' '.join(cmd)}\n")
    subprocess.run(cmd, check=False)

    if not os.path.exists(RESULTS_FILE):
        print("❌ Файл результатов не создан — тест завершился с ошибкой.")
        return {}

    with open(RESULTS_FILE, encoding="utf-8") as f:
        return json.load(f)


def generate_bug_reports(results: dict) -> list[str]:
    """
    Для каждого FAILED сценария создаёт markdown bug-report.
    Возвращает список путей к созданным файлам.
    """
    os.makedirs(BUG_REPORTS_DIR, exist_ok=True)
    report_paths = []

    for num, data in results.items():
        if data.get("passed"):
            continue

        name = data.get("name", SCENARIO_NAMES.get(num, f"Сценарий {num}"))
        details = data.get("details", "Детали недоступны.")
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        report = f"""# Bug Report — Сценарий {num}: {name}

**Дата:** {timestamp}
**Статус:** ❌ FAILED

## Описание проблемы

Smoke-тест сценария {num} завершился с ошибкой во время автоматического тестирования
macOS-приложения AIAdventChatV2 через computer use.

## Детали от QA-агента

{details.strip()}

## Сценарий (шаги теста)

Тестировался сценарий: **{name}**

## Что нужно исправить

Проанализируй детали выше и найди причину падения теста в коде приложения
(Swift/SwiftUI, папки Services/, ViewModels/, Views/, Models/).
Исправь баг так чтобы smoke-тест проходил успешно.

## Приоритет

Высокий — блокирует smoke-тестирование.
"""

        path = os.path.join(BUG_REPORTS_DIR, f"scenario_{num}.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(report)

        print(f"  📝 Bug-report: {path}")
        report_paths.append(path)

    return report_paths


def print_summary(results: dict, run: int):
    passed_list = [n for n, d in results.items() if d.get("passed")]
    failed_list = [n for n, d in results.items() if not d.get("passed")]

    print(f"\n{'='*60}")
    print(f"  ПРОГОН #{run} — ИТОГ")
    print(f"{'='*60}")
    for num in sorted(results.keys()):
        d = results[num]
        status = "✅ PASSED" if d.get("passed") else "❌ FAILED"
        name = d.get("name", SCENARIO_NAMES.get(num, f"Сценарий {num}"))
        print(f"  {num}. {status} — {name}")
    print(f"\n  Итого: {len(passed_list)}/{len(results)} прошли")
    if failed_list:
        print(f"  Упали: сценарии {', '.join(sorted(failed_list))}")
    print(f"{'='*60}\n")

    return failed_list


def main():
    parser = argparse.ArgumentParser(
        description="Оркестратор smoke-тестов с генерацией bug-репортов"
    )
    parser.add_argument(
        "--scenarios",
        type=str,
        default="1,2,3",
        help="Сценарии через запятую (1,2,3) или 'all'. По умолчанию: 1,2,3"
    )
    parser.add_argument(
        "--api-key",
        type=str,
        default=os.environ.get("ANTHROPIC_API_KEY", ""),
        help="Anthropic API ключ (или ANTHROPIC_API_KEY env)"
    )
    parser.add_argument(
        "--run",
        type=int,
        default=1,
        help="Номер текущего прогона (для логов). По умолчанию: 1"
    )
    args = parser.parse_args()

    if not args.api_key:
        print("❌ Укажи API ключ: --api-key sk-ant-... или export ANTHROPIC_API_KEY=...")
        sys.exit(2)

    # Преобразуем "1,2,3" → "all" или оставляем один номер
    if args.scenarios == "all":
        scenario_arg = "all"
    else:
        nums = [s.strip() for s in args.scenarios.split(",") if s.strip()]
        if len(nums) == 1:
            scenario_arg = nums[0]
        else:
            # computer_use_test.py не поддерживает список — запускаем all и фильтруем
            scenario_arg = "all"

    results = run_tests(scenario_arg, args.api_key)

    if not results:
        print("❌ Нет результатов — завершаю с ошибкой.")
        sys.exit(2)

    # Если запускали all но нужны только конкретные сценарии — фильтруем
    if args.scenarios != "all" and scenario_arg == "all":
        needed = set(s.strip() for s in args.scenarios.split(",") if s.strip())
        results = {k: v for k, v in results.items() if k in needed}

    failed_list = print_summary(results, args.run)

    if not failed_list:
        print("🎉 Все тесты прошли! Работа завершена.")
        sys.exit(0)

    # Генерируем bug-репорты для упавших сценариев
    print(f"🐛 Генерирую bug-репорты для сценариев: {', '.join(sorted(failed_list))}")
    report_paths = generate_bug_reports(results)

    print(f"\n{'='*60}")
    print("  ДЕЙСТВИЕ ТРЕБУЕТСЯ")
    print(f"{'='*60}")
    print(f"  Bug-репорты созданы в: {BUG_REPORTS_DIR}/")
    for path in report_paths:
        print(f"    → {path}")
    print()
    print("  Следующий шаг:")
    print("  1. Claude Code читает bug-репорты выше")
    print("  2. Вызывает skill bug-fix для каждого")
    print("  3. После исправления запускает:")
    print(f"     python3 smoke_fix_loop.py --scenarios {args.scenarios} --run {args.run + 1}")
    print(f"{'='*60}\n")

    sys.exit(1)


if __name__ == "__main__":
    main()
