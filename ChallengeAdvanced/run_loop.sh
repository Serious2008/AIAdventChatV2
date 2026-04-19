#!/bin/bash

PROJECT_DIR="/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2"
TASKS_FILE="$PROJECT_DIR/ChallengeAdvanced/Day5_Tasks.md"
MODEL="phi4:14b"
OLLAMA_URL="http://localhost:11434/api/generate"
METRICS_FILE="$PROJECT_DIR/ChallengeAdvanced/Day5_Metrics.md"
LOG_FILE="/tmp/task_log.txt"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

TASKS_DONE=0; TASKS_FAILED=0; TOTAL_TIME=0; FIRST_FAIL=""

log()     { echo -e "${BLUE}[LOOP]${NC} $1"; }
success() { echo -e "${GREEN}[✅]${NC} $1"; }
fail()    { echo -e "${RED}[❌]${NC} $1"; }
warn()    { echo -e "${YELLOW}[⚠️]${NC} $1"; }

# Найти ID следующей незавершённой задачи
get_next_task_id() {
    grep -E "^### TASK-[0-9]+" "$TASKS_FILE" | while read -r line; do
        task_id=$(echo "$line" | grep -oE "TASK-[0-9]+")
        # Проверить статус этой задачи
        status=$(awk "/^### $task_id /,/\*\*Статус:\*\*/" "$TASKS_FILE" | grep "Статус" | head -1)
        if echo "$status" | grep -q "🔲"; then
            echo "$task_id"
            return
        fi
    done | head -1
}

# Получить детали задачи
get_task_details() {
    local id=$1
    awk "/^### $id /,/^---$/" "$TASKS_FILE" | grep -v "^---"
}

# Получить упомянутый файл в задаче
get_task_file() {
    local details=$1
    echo "$details" | grep -oE "(Services|Views|Tests)/[A-Za-z]+\.swift" | head -1
}

# Обновить статус задачи
mark_task() {
    local id=$1 status=$2
    python3 - "$TASKS_FILE" "$id" "$status" << 'PYEOF'
import sys
path, task_id, status = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path).readlines()
in_task = False
result = []
for line in lines:
    if f"### {task_id} " in line:
        in_task = True
    if in_task and "**Статус:**" in line:
        line = line.replace("🔲", status).replace("🔄", status)
        in_task = False
    result.append(line)
open(path, 'w').writelines(result)
PYEOF
}

# Вызов Ollama API
ask_ollama() {
    local prompt=$1
    python3 - "$prompt" "$MODEL" "$OLLAMA_URL" << 'PYEOF'
import sys, json, urllib.request
prompt, model, url = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.dumps({"model": model, "prompt": prompt, "stream": False,
                   "options": {"temperature": 0.1, "top_p": 0.95}}).encode()
try:
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        resp = json.loads(r.read())
        print(resp.get("response", ""))
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
PYEOF
}

SYSTEM="You are a Swift developer for AIAdventChatV2 macOS app (NOT iOS). Swift 6.0, AppKit not UIKit.
Rules: no force unwrap, async/await, init(settings:) for DI, MARK sections, emoji logs.
Respond ONLY with: first line must be exactly 'FILE: path/to/file.swift' or 'NEW_FILE: path/to/file.swift' or 'DOC_FILE: path/to/file.md'
Then a swift or markdown code block with the complete file content. Nothing else."

> "$LOG_FILE"
log "Запуск Execution Loop | Модель: $MODEL"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for i in $(seq 1 15); do
    TASK_ID=$(get_next_task_id)
    [ -z "$TASK_ID" ] && { log "Все задачи выполнены!"; break; }

    DETAILS=$(get_task_details "$TASK_ID")
    TASK_FILE=$(get_task_file "$DETAILS")
    PROBLEM=$(echo "$DETAILS" | grep "Проблема" | sed 's/\*\*Проблема:\*\* //')
    CRITERIA=$(echo "$DETAILS" | grep "Критерий" | sed 's/\*\*Критерий готовности:\*\* //')

    log "[$i/15] $TASK_ID"
    echo "  Проблема: $PROBLEM"
    echo "  Файл: $TASK_FILE"

    START=$(date +%s)

    # Читаем контекстный файл
    FILE_CONTENT=""
    if [ -n "$TASK_FILE" ]; then
        FULL="$PROJECT_DIR/AIAdventChatV2/$TASK_FILE"
        [ -f "$FULL" ] && FILE_CONTENT="Current content of $TASK_FILE:
\`\`\`swift
$(cat "$FULL")
\`\`\`"
    fi

    PROMPT="$SYSTEM

TASK: $TASK_ID
Problem: $PROBLEM
Done criteria: $CRITERIA
Target file: $TASK_FILE

$FILE_CONTENT

Complete the task now:"

    warn "Запрос к $MODEL..."
    RESPONSE=$(ask_ollama "$PROMPT")
    END=$(date +%s)
    ELAPSED=$((END - START))
    TOTAL_TIME=$((TOTAL_TIME + ELAPSED))

    # Парсим ответ
    FIRST_LINE=$(echo "$RESPONSE" | head -1 | tr -d '\r')
    OUTPUT_FILE=$(echo "$FIRST_LINE" | grep -oE "(Services|Views|Tests|Docs|AIAdventChatV2Tests)/[A-Za-z_]+\.(swift|md)" | head -1)

    if [ -z "$OUTPUT_FILE" ]; then
        fail "$TASK_ID — нет файла в ответе (${ELAPSED}с)"
        echo "  Ответ: $(echo "$RESPONSE" | head -2)"
        mark_task "$TASK_ID" "❌"
        TASKS_FAILED=$((TASKS_FAILED + 1))
        [ -z "$FIRST_FAIL" ] && FIRST_FAIL="$TASK_ID"
        echo "| $TASK_ID | ❌ | нет файла в ответе | ${ELAPSED}с |" >> "$LOG_FILE"
        continue
    fi

    # Извлекаем код из блока
    FILE_BODY=$(echo "$RESPONSE" | awk '/^```/{p=!p;next} p')

    if [ -z "$FILE_BODY" ]; then
        fail "$TASK_ID — пустое содержимое файла (${ELAPSED}с)"
        mark_task "$TASK_ID" "❌"
        TASKS_FAILED=$((TASKS_FAILED + 1))
        [ -z "$FIRST_FAIL" ] && FIRST_FAIL="$TASK_ID"
        echo "| $TASK_ID | ❌ | пустое содержимое | ${ELAPSED}с |" >> "$LOG_FILE"
        continue
    fi

    # Определяем путь назначения
    if echo "$OUTPUT_FILE" | grep -qE "Tests/|AIAdventChatV2Tests/"; then
        DEST="$PROJECT_DIR/AIAdventChatV2Tests/$(basename "$OUTPUT_FILE")"
    elif echo "$OUTPUT_FILE" | grep -q "Docs/"; then
        mkdir -p "$PROJECT_DIR/Docs"
        DEST="$PROJECT_DIR/$OUTPUT_FILE"
    else
        DEST="$PROJECT_DIR/AIAdventChatV2/$OUTPUT_FILE"
    fi

    printf "%s" "$FILE_BODY" > "$DEST"
    success "$TASK_ID — записан: $OUTPUT_FILE (${ELAPSED}с)"

    cd "$PROJECT_DIR"
    git add "$DEST" "$TASKS_FILE" 2>/dev/null
    git commit -m "ChallengeAdvanced: Day 5 Loop — $TASK_ID

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>" --quiet 2>/dev/null \
        && success "Коммит создан" || warn "Коммит пропущен"

    mark_task "$TASK_ID" "✅"
    TASKS_DONE=$((TASKS_DONE + 1))
    echo "| $TASK_ID | ✅ | $OUTPUT_FILE | ${ELAPSED}с |" >> "$LOG_FILE"
    echo ""
done

log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "ИТОГ: ✅ $TASKS_DONE выполнено | ❌ $TASKS_FAILED провалено"

AVG=0
[ $((TASKS_DONE + TASKS_FAILED)) -gt 0 ] && AVG=$((TOTAL_TIME / (TASKS_DONE + TASKS_FAILED)))

cat > "$METRICS_FILE" << EOF
# Day 5 — Метрики Execution Loop (Прогон 1: phi4:14b)

**Модель:** $MODEL
**Дата:** $(date '+%Y-%m-%d %H:%M')

## Результаты

| Метрика | Значение |
|---|---|
| Задач выполнено | $TASKS_DONE / 15 |
| Задач провалено | $TASKS_FAILED |
| Подряд без паузы | $TASKS_DONE |
| Первый сбой | ${FIRST_FAIL:-нет} |
| Среднее время на задачу | ${AVG}с |
| Общее время | ${TOTAL_TIME}с |

## Лог задач

| Задача | Статус | Файл | Время |
|---|---|---|---|
$(cat "$LOG_FILE")
EOF

log "Метрики: $METRICS_FILE"
