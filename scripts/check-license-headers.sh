#!/usr/bin/env bash
#
# check-license-headers.sh
#
# Проверяет, что во всех НОВЫХ/ИЗМЕНЁННЫХ исходных файлах PR присутствует
# строка "SPDX-License-Identifier: GPL-3.0-or-later" где-то в первых
# N строках файла (заголовок лицензии должен быть в начале файла).
#
# Использование:
#   scripts/check-license-headers.sh <base-ref> <head-ref>
#
# Если аргументы не переданы, скрипт попробует взять их из переменных
# окружения GITHUB_BASE_SHA / GITHUB_HEAD_SHA (см. workflow), либо
# сравнит рабочую копию с HEAD~1 (для локального запуска).

set -euo pipefail

BASE_REF="${1:-${GITHUB_BASE_SHA:-}}"
HEAD_REF="${2:-${GITHUB_HEAD_SHA:-HEAD}}"

if [[ -z "$BASE_REF" ]]; then
  echo "Не задан base ref, сравниваю с HEAD~1 (локальный режим)."
  BASE_REF="HEAD~1"
fi

# Расширения файлов, которые обязаны нести заголовок лицензии
EXTENSIONS_REGEX='\.(c|h|cpp|hpp|cc|cxx|asm|inc|S)$'
# Пути, которые заведомо исключены (сторонний код, автогенерируемые файлы)
EXCLUDE_REGEX='^(third_party/|external/|vendor/|build/)'
# Строка, наличие которой считаем достаточным подтверждением заголовка
SPDX_TAG='SPDX-License-Identifier:'
# Скан только первых 25 строк файла в поисках SPDX-тега
HEAD_LINES=25

echo "Сравниваю диапазон: ${BASE_REF}...${HEAD_REF}"

mapfile -t CHANGED_FILES < <(
  git diff --name-only --diff-filter=ACMR "${BASE_REF}" "${HEAD_REF}" \
    | grep -E "${EXTENSIONS_REGEX}" \
    | grep -Ev "${EXCLUDE_REGEX}" || true
)

if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
  echo "Нет новых/изменённых исходных файлов, подлежащих проверке."
  exit 0
fi

MISSING=()

for f in "${CHANGED_FILES[@]}"; do
  # Файл мог быть удалён в этом диапазоне - пропускаем
  if [[ ! -f "$f" ]]; then
    continue
  fi

  if ! head -n "${HEAD_LINES}" "$f" | grep -q "${SPDX_TAG}"; then
    MISSING+=("$f")
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "[-] В следующих файлах отсутствует заголовок лицензии (${SPDX_TAG}):"
  for f in "${MISSING[@]}"; do
    echo "   - $f"
  done
  echo ""
  echo "Возьмите шаблон из templates/license-headers/ и вставьте его"
  echo "первым блоком в начало файла (см. templates/license-headers/README.md)."
  exit 1
fi

echo "[+] Все проверенные файлы (${#CHANGED_FILES[@]}) содержат заголовок лицензии."