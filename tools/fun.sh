#!/usr/bin/env bash
# Запуск инструментов FUN (папка tools/) из проекта игры - той версии FUN, что подключена в game.project.
# Копия этого файла лежит в каждом проекте как scripts/fun.sh (источник - tools/fun.sh в FUN, копировать без правок).
#
#   scripts/fun.sh <инструмент> [аргументы]    например: scripts/fun.sh store/gp_listing --apply
#   scripts/fun.sh --path                       папка инструментов этой версии (README, исходники)
#
# Версия FUN - зависимость .../seliseev/fun/archive/... в game.project. Архив скачивается один раз
# в build/fun/<версия>/ (тег не меняется; ветка - скачивается заново при каждом запуске).
# Плейсхолдеры __VAR__ в адресе заменяются переменными окружения, как у Defold.
# FUN_TOOLS=<путь к tools/> - взять инструменты из локального клона FUN (проверить правки до выпуска тега).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/game.project"

find_tools() {
	if [ -n "${FUN_TOOLS:-}" ]; then
		echo "$FUN_TOOLS"
		return
	fi
	local url
	url="$(grep -E '^dependencies#[0-9]+[[:space:]]*=.*/seliseev/fun/archive/' "$PROJECT" | head -1 | sed -E 's/^[^=]*=[[:space:]]*//; s/[[:space:]]*$//')"
	if [ -z "$url" ]; then
		echo "fun.sh: в $PROJECT нет зависимости seliseev/fun" >&2
		exit 1
	fi
	# __VAR__ -> значение переменной окружения VAR
	while [[ "$url" =~ __([A-Za-z0-9_]+)__ ]]; do
		local name="${BASH_REMATCH[1]}"
		url="${url//__${name}__/${!name:-}}"
	done
	local version
	version="$(basename "$url" .zip)"
	local cache="$ROOT/build/fun/$version"
	if [ -d "$cache/tools" ] && [[ "$url" == */refs/tags/* ]]; then
		echo "$cache/tools"
		return
	fi
	# Без local: trap срабатывает при выходе из подоболочки $(find_tools), когда local уже нет
	TMP_DIR="$(mktemp -d)"
	trap 'rm -rf "$TMP_DIR"' EXIT
	local tmp="$TMP_DIR"
	curl -fsSL "$url" -o "$tmp/fun.zip" || { echo "fun.sh: не удалось скачать FUN ($version)" >&2; exit 1; }
	unzip -q "$tmp/fun.zip" -d "$tmp/src"
	local tools
	tools="$(find "$tmp/src" -mindepth 2 -maxdepth 2 -type d -name tools | head -1)"
	if [ -z "$tools" ]; then
		echo "fun.sh: в FUN $version нет папки tools (нужна версия FUN с инструментами)" >&2
		exit 1
	fi
	rm -rf "$cache"
	mkdir -p "$cache"
	mv "$tools" "$cache/tools"
	echo "$cache/tools"
}

if [ $# -eq 0 ]; then
	sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
fi

TOOLS="$(find_tools)"
if [ "$1" = "--path" ]; then
	echo "$TOOLS"
	exit 0
fi

SCRIPT="$TOOLS/$1.py"
if [ ! -f "$SCRIPT" ]; then
	echo "fun.sh: нет инструмента $1. Есть:" >&2
	(cd "$TOOLS" && find . -name '*.py' ! -name '*_common.py' | sed 's|^\./||; s|\.py$||' | sort) >&2
	exit 1
fi
shift
cd "$ROOT"
exec env FUN_PROJECT_ROOT="$ROOT" PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT" "$@"
