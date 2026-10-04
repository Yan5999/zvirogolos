#!/usr/bin/env bash
# Импорт + прогон меню + smoke-тест. Использование: GODOT=/path/to/godot tools/check.sh
set -u
G="${GODOT:-godot}"
cd "$(dirname "$0")/.."
$G --headless --path . --import >/dev/null 2>&1
echo "== run main scene =="
timeout 60 $G --headless --path . --quit-after 120 2>&1 | grep -E "ERROR|WARNING|SCRIPT" || echo "no errors"
echo "== smoke test =="
timeout 120 $G --headless --path . res://tools/smoke_test.tscn 2>&1 | grep -vE "^Godot Engine|^$"
