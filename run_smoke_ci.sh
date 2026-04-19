#!/usr/bin/env bash
# run_smoke_ci.sh — Запускает один прогон smoke-тестов и генерирует bug-репорты.
# Используется Claude Code как часть цикла: тест → фикс → тест.
#
# Использование:
#   ./run_smoke_ci.sh [сценарии] [номер_прогона]
#   ./run_smoke_ci.sh 1,2,3 1
#   ./run_smoke_ci.sh all 2
#
# Exit codes:
#   0 — все тесты PASSED
#   1 — есть FAILED, bug-репорты в /tmp/smoke_bug_reports/
#   2 — ошибка конфигурации

set -euo pipefail

SCENARIOS="${1:-1,2,3}"
RUN="${2:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then
    echo "❌ Нужен ANTHROPIC_API_KEY"
    exit 2
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Smoke CI — Прогон #${RUN} | Сценарии: ${SCENARIOS}"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

python3 "${SCRIPT_DIR}/smoke_fix_loop.py" \
    --scenarios "${SCENARIOS}" \
    --run "${RUN}" \
    --api-key "${ANTHROPIC_API_KEY}"

EXIT=$?

if [[ $EXIT -eq 0 ]]; then
    echo "✅ CI PASSED — все smoke-тесты зелёные."
elif [[ $EXIT -eq 1 ]]; then
    echo ""
    echo "❌ CI FAILED — есть упавшие тесты."
    echo "   Bug-репорты: /tmp/smoke_bug_reports/"
    echo "   Claude Code прочитает репорты и запустит bug-fix."
fi

exit $EXIT
