#!/usr/bin/env bash
#
# release_testflight.sh — одной командой собрать iOS-билд и залить в TestFlight.
#
#   ./dev/release_testflight.sh --check            только проверки, ничего не собирает
#   ./dev/release_testflight.sh                    bump билда → экспорт → аплоад
#   ./dev/release_testflight.sh --version 1.0.4    заодно поднять маркетинговую версию
#   ./dev/release_testflight.sh --no-upload        собрать .ipa и остановиться
#   ./dev/release_testflight.sh --no-bump          не трогать номер билда
#   ./dev/release_testflight.sh --patch-template   поднять нижнюю версию iOS в шаблоне
#
# Требует (см. --check):
#   • Godot 4.2.x с установленными export templates
#   • Xcode + сертификат Apple Distribution в keychain
#   • secrets/asc.env с ключом App Store Connect API
#
set -euo pipefail

PRESET="iOS"
PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$PROJ_DIR/../.." && pwd)"
PRESETS_FILE="$PROJ_DIR/export_presets.cfg"
OUT_DIR="$PROJ_DIR/ios_export"
IPA="$OUT_DIR/Normaldo.ipa"
ASC_ENV="$REPO_ROOT/secrets/asc.env"

# ── НИЖНЯЯ ВЕРСИЯ iOS ────────────────────────────────────────────────────────
# App Store отклоняет сборку с MinimumOSVersion 12.0:
#
#   This bundle is invalid. The value provided for the key MinimumOSVersion
#   '12.0' is not acceptable                                      (код 90068)
#
# То же число App Store Connect называет обязательным с весны 2027, так что
# возвращаться сюда через полгода не придётся.
#
# Столько же стоит в dev/smoke_release.gd — держать два разных числа значит
# однажды починить одно и уехать на втором.
MIN_IOS="15.0"

DO_CHECK_ONLY=0
DO_UPLOAD=1
DO_BUMP=1
DO_PATCH_TPL=0
NEW_VERSION=""

while [[ $# -gt 0 ]]; do
	case "$1" in
		--check)          DO_CHECK_ONLY=1; shift ;;
		--no-upload)      DO_UPLOAD=0; shift ;;
		--no-bump)        DO_BUMP=0; shift ;;
		--patch-template) DO_PATCH_TPL=1; shift ;;
		--version)        NEW_VERSION="${2:-}"; shift 2 ;;
		-h|--help)        sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
	esac
done

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }
bold() { printf '\033[1m%s\033[0m\n' "$*"; }

FAIL=0
ok()   { grn "  ✓ $*"; }
bad()  { red "  ✗ $*"; FAIL=1; }
warn() { ylw "  ! $*"; }

# Меньше ли первое число второго. Версии вида «12.0» и «15.0» сравнивать
# строками нельзя: «9.0» строкой больше «15.0».
ver_lt() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n | head -1)" == "$1" && "$1" != "$2" ]]; }

# ── Поиск Godot ───────────────────────────────────────────────────────────────
find_godot() {
	if [[ -n "${GODOT:-}" ]]; then echo "$GODOT"; return; fi
	local c
	for c in \
		"$(command -v godot 2>/dev/null || true)" \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
	do
		[[ -n "$c" && -x "$c" ]] && { echo "$c"; return; }
	done
	echo ""
}

# ── Чтение/запись export_presets.cfg ──────────────────────────────────────────
# Ключи лежат в секции [preset.N.options]; в проекте пресет iOS — единственный
# с platform="iOS", но значения уникальны по имени, поэтому правим по ключу.
cfg_get() { grep -E "^$1=" "$PRESETS_FILE" | head -1 | sed -E 's/^[^=]+="?([^"]*)"?$/\1/'; }
cfg_set() {
	local key="$1" val="$2"
	/usr/bin/sed -i '' -E "s|^${key}=.*|${key}=\"${val}\"|" "$PRESETS_FILE"
}

# ── ШАБЛОН ЭКСПОРТА ───────────────────────────────────────────────────────────
# Нижняя версия iOS приходит НЕ из пресета — настройки под неё в этой версии
# движка нет вовсе. Она зашита в шаблоне экспорта (ios.zip), в его проекте
# Xcode, и оттуда попадает в каждую сборку.
#
# Править проект Xcode между экспортом и архивом нельзя: при
# application/export_project_only=false Godot делает и то и другое внутри одного
# вызова --export-release, окна между ними не существует.
#
# Поэтому чинится шаблон. Правка машинная, не репозиторная: она живёт в твоей
# установке Godot и переживает любые pull, но исчезает при обновлении движка —
# тогда скрипт скажет об этом снова.
tpl_pbx_path() { unzip -Z1 "$1" 2>/dev/null | grep -m1 'project\.pbxproj$' || true; }

tpl_min_ios() {
	local zip="$1" inner
	inner="$(tpl_pbx_path "$zip")"
	[[ -z "$inner" ]] && return 1
	unzip -p "$zip" "$inner" 2>/dev/null \
		| grep -m1 -oE 'IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+' \
		| grep -oE '[0-9.]+$'
}

patch_template() {
	local zip="$1" inner tmp
	inner="$(tpl_pbx_path "$zip")"
	if [[ -z "$inner" ]]; then
		red "В шаблоне $zip не нашёлся project.pbxproj — шаблон изменился, правь руками."
		return 1
	fi
	if [[ ! -f "$zip.before-min-ios" ]]; then
		cp "$zip" "$zip.before-min-ios"
		ok "Копия исходного шаблона: $(basename "$zip").before-min-ios"
	fi
	tmp="$(mktemp -d)"
	( cd "$tmp" && unzip -q "$zip" "$inner" )
	/usr/bin/sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = ${MIN_IOS};/g" "$tmp/$inner"
	( cd "$tmp" && zip -q "$zip" "$inner" )
	rm -rf "$tmp"
	ok "Шаблон поправлен: нижняя версия iOS → $MIN_IOS"
}

# ── Проверки ──────────────────────────────────────────────────────────────────
bold "Проверки"

GODOT_BIN="$(find_godot)"
TPL_ZIP=""
if [[ -z "$GODOT_BIN" ]]; then
	bad "Godot не найден. Укажи путь: GODOT=/path/to/Godot $0"
else
	GODOT_VER="$("$GODOT_BIN" --version 2>/dev/null | head -1)"
	ok "Godot: $GODOT_VER"
	TPL_VER="${GODOT_VER%%.official*}"
	TPL_DIR="$HOME/Library/Application Support/Godot/export_templates/$TPL_VER"
	if [[ -d "$TPL_DIR" ]]; then
		ok "Export templates: $TPL_VER"
		TPL_ZIP="$TPL_DIR/ios.zip"
	else
		bad "Нет export templates для $TPL_VER (Editor → Manage Export Templates)"
	fi
fi

if [[ -n "$TPL_ZIP" && -f "$TPL_ZIP" ]]; then
	TPL_MIN="$(tpl_min_ios "$TPL_ZIP" || true)"
	if [[ -z "$TPL_MIN" ]]; then
		warn "В шаблоне iOS не нашлась нижняя версия — проверю уже по собранному .ipa."
	elif ver_lt "$TPL_MIN" "$MIN_IOS"; then
		if [[ "$DO_PATCH_TPL" -eq 1 ]]; then
			patch_template "$TPL_ZIP" || FAIL=1
		else
			bad "Шаблон отдаёт нижнюю версию iOS $TPL_MIN, а нужно $MIN_IOS — App Store откажет (код 90068)."
			echo "     Лечится один раз на эту версию движка: $0 --patch-template"
		fi
	else
		ok "Нижняя версия iOS в шаблоне: $TPL_MIN"
	fi
elif [[ -n "$TPL_ZIP" ]]; then
	warn "Не найден $TPL_ZIP — нижнюю версию проверю по собранному .ipa."
fi

if [[ -f "$PRESETS_FILE" ]] && grep -q "name=\"$PRESET\"" "$PRESETS_FILE"; then
	ok "Пресет «$PRESET» найден"
	CUR_SHORT="$(cfg_get 'application/short_version')"
	CUR_BUILD="$(cfg_get 'application/version')"
	CUR_BUNDLE="$(cfg_get 'application/bundle_identifier')"
	ok "Текущая версия: $CUR_SHORT (build $CUR_BUILD), bundle $CUR_BUNDLE"
	SIGN_ID="$(cfg_get 'application/code_sign_identity_release')"
	if [[ "$SIGN_ID" == *Developer* ]]; then
		warn "code_sign_identity_release=\"$SIGN_ID\" — это ДЕВЕЛОПЕРСКАЯ подпись."
		warn "  Для App Store/TestFlight нужна \"Apple Distribution\" (или пустая строка при automatic signing)."
	fi
else
	bad "В $PRESETS_FILE нет пресета «$PRESET»"
fi

if xcodebuild -version >/dev/null 2>&1; then
	ok "Xcode: $(xcodebuild -version | head -1)"
else
	bad "Xcode CLI недоступен (xcode-select -p ?)"
fi

DIST_ID="$(security find-identity -v -p codesigning 2>/dev/null | grep -cE 'Apple Distribution|iPhone Distribution' || true)"
if [[ "$DIST_ID" -gt 0 ]]; then
	ok "Сертификат распространения в keychain: найден"
else
	bad "НЕТ сертификата «Apple Distribution» в keychain — архив для App Store не подпишется."
	echo "     Есть только: $(security find-identity -v -p codesigning 2>/dev/null | grep '\"' | sed 's/.*\"\(.*\)\"/\1/' | paste -sd', ' -)"
	echo "     Лечится в Xcode: Settings → Accounts → Manage Certificates → + Apple Distribution."
fi

if [[ -f "$ASC_ENV" ]]; then
	# shellcheck disable=SC1090
	set -a; source "$ASC_ENV"; set +a
	if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
		ok "App Store Connect API: key ${ASC_KEY_ID}"
	else
		bad "$ASC_ENV есть, но не заданы ASC_KEY_ID / ASC_ISSUER_ID"
	fi
	P8="$REPO_ROOT/secrets/AuthKey_${ASC_KEY_ID:-NONE}.p8"
	[[ -f "$P8" ]] && ok "Приватный ключ: $(basename "$P8")" || bad "Не найден $P8"
else
	bad "Нет $ASC_ENV — без него нечем авторизоваться в App Store Connect."
	cat <<'EOF'
     Создай файл secrets/asc.env (папка secrets/ уже в .gitignore):
       ASC_KEY_ID=XXXXXXXXXX
       ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
     Ключ берётся в App Store Connect → Users and Access → Integrations → App Store Connect API.
     Скачанный AuthKey_<KEY_ID>.p8 положи в secrets/.
EOF
fi

# ── ГОТОВНОСТЬ САМОЙ ИГРЫ ────────────────────────────────────────────────────
# Дев-кнопки сбрасывают скины, выдают доллары и делают бессмертным. Уехавшая с
# ними сборка — это не «мелкий недочёт интерфейса», это сломанная экономика у
# всех тестеров сразу. Тест заодно следит за нижней версией iOS и за тем, что
# системная заставка чёрная.
if [[ -n "$GODOT_BIN" ]]; then
	if "$GODOT_BIN" --headless --path "$PROJ_DIR" --script dev/smoke_release.gd >/tmp/smoke_release.log 2>&1; then
		ok "Готовность сборки: $(grep -m1 'ВСЁ ЗЕЛЁНОЕ' /tmp/smoke_release.log || echo 'проверки прошли')"
	else
		bad "dev/smoke_release.gd не прошёл:"
		grep -E '  FAIL|ПРОВАЛОВ' /tmp/smoke_release.log | sed 's/^/     /' || true
		echo "     Полный вывод: /tmp/smoke_release.log"
	fi
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
	warn "Рабочее дерево грязное — в билд уедут незакоммиченные правки."
fi

echo
if [[ "$FAIL" -eq 1 ]]; then
	red "Проверки не пройдены — см. ✗ выше."
	[[ "$DO_CHECK_ONLY" -eq 1 ]] && exit 1
	exit 1
fi
grn "Все проверки пройдены."
[[ "$DO_CHECK_ONLY" -eq 1 ]] && exit 0

# ── Bump версии ───────────────────────────────────────────────────────────────
echo
bold "Версия"
if [[ -n "$NEW_VERSION" ]]; then
	cfg_set 'application/short_version' "$NEW_VERSION"
	ok "short_version → $NEW_VERSION"
fi
if [[ "$DO_BUMP" -eq 1 ]]; then
	NEXT_BUILD=$(( CUR_BUILD + 1 ))
	cfg_set 'application/version' "$NEXT_BUILD"
	ok "build → $NEXT_BUILD"
else
	NEXT_BUILD="$CUR_BUILD"
	warn "build не тронут ($CUR_BUILD) — App Store Connect отклонит повторный номер."
fi
FINAL_SHORT="$(cfg_get 'application/short_version')"

# ── ВЕРСИЯ, КОТОРУЮ ПОКАЖЕТ САМА ИГРА ────────────────────────────────────────
# Игра берёт версию из project.godot и в пресет не смотрит: export_presets.cfg —
# файл РЕДАКТОРА, в сборку он не попадает вовсе. Поэтому версию и номер билда
# переносит скрипт.
#
# Место выбрано не случайно: ПОСЛЕ bump'а — иначе в сборку уедет предыдущий
# номер, — и ДО экспорта, иначе перенос не успеет попасть в .pck.
#
# Расхождение стоило полудня поисков несуществующего кеша: в пресете было 1.0.3,
# игра показывала 1.0.1, и на вопрос «новая ли сборка стоит на телефоне» экран
# настроек отвечал неправдой.
python3 "$PROJ_DIR/dev/tools/sync_version.py"

# ── Экспорт ───────────────────────────────────────────────────────────────────
echo
bold "Сборка $FINAL_SHORT ($NEXT_BUILD)"
mkdir -p "$OUT_DIR"
rm -f "$IPA"
# Godot сам зовёт xcodebuild archive + exportArchive, потому что в пресете
# application/export_project_only=false.
"$GODOT_BIN" --headless --path "$PROJ_DIR" --export-release "$PRESET" "$IPA"

if [[ ! -f "$IPA" ]]; then
	red "Экспорт не создал $IPA. Смотри $OUT_DIR/Packaging.log"
	exit 1
fi
ok "Собрано: $IPA ($(du -h "$IPA" | cut -f1))"

# ── ВОРОТА ПЕРЕД ЗАЛИВКОЙ ─────────────────────────────────────────────────────
# Спрашиваем САМ АРТЕФАКТ, а не проект и не шаблон: в .ipa лежит ровно тот
# Info.plist, который будет читать App Store. Отказ по нижней версии приходит в
# конце двадцатиминутной заливки, и узнавать о нём оттуда незачем.
IPA_PLIST="$(unzip -Z1 "$IPA" 2>/dev/null | grep -m1 -E '^Payload/[^/]+\.app/Info\.plist$' || true)"
if [[ -z "$IPA_PLIST" ]]; then
	warn "В .ipa не нашёлся Info.plist — нижнюю версию не проверить."
else
	IPA_MIN="$(unzip -p "$IPA" "$IPA_PLIST" 2>/dev/null \
		| plutil -extract MinimumOSVersion raw -o - - 2>/dev/null || true)"
	if [[ -z "$IPA_MIN" ]]; then
		warn "В Info.plist нет MinimumOSVersion — проверить нечего."
	elif ver_lt "$IPA_MIN" "$MIN_IOS"; then
		red "Нижняя версия iOS в собранном .ipa: $IPA_MIN, а App Store принимает от $MIN_IOS."
		red "Заливка отвалится с кодом 90068 — останавливаюсь до неё."
		echo "  Лечится один раз на эту версию движка: $0 --patch-template"
		exit 1
	else
		ok "Нижняя версия iOS в .ipa: $IPA_MIN"
	fi
fi

if [[ "$DO_UPLOAD" -eq 0 ]]; then
	ylw "--no-upload: остановились на .ipa."
	exit 0
fi

# ── Загрузка ──────────────────────────────────────────────────────────────────
echo
bold "Загрузка в TestFlight"
# altool ищет ключ в ./private_keys, ~/private_keys, ~/.private_keys,
# ~/.appstoreconnect/private_keys — кладём временную копию и убираем за собой.
KEYDIR="$(mktemp -d)/private_keys"
mkdir -p "$KEYDIR"
cp "$P8" "$KEYDIR/"
cleanup() { rm -rf "$(dirname "$KEYDIR")"; }
trap cleanup EXIT

( cd "$(dirname "$KEYDIR")" && \
  xcrun altool --upload-app -f "$IPA" -t ios \
	--apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID" )

ok "Загружено. Обработка в App Store Connect занимает 5–15 минут."

# ── Тег ───────────────────────────────────────────────────────────────────────
TAG="tf/$FINAL_SHORT-$NEXT_BUILD"
if git -C "$REPO_ROOT" rev-parse "$TAG" >/dev/null 2>&1; then
	warn "Тег $TAG уже существует, пропускаю."
else
	git -C "$REPO_ROOT" tag -a "$TAG" -m "TestFlight $FINAL_SHORT ($NEXT_BUILD)"
	ok "Тег $TAG (запушить: git push origin $TAG)"
fi

echo
grn "Готово."
