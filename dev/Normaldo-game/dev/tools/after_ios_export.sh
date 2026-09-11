#!/usr/bin/env bash
# Что нужно поправить в проекте Xcode ПОСЛЕ каждого экспорта из Godot.
#
#   ./dev/tools/after_ios_export.sh
#
# ── КОГДА ОН НУЖЕН, А КОГДА БЕСПОЛЕЗЕН ──────────────────────────────────────
# Он для РУЧНОЙ сборки: экспорт из Godot отдаёт проект Xcode, ты открываешь его
# и архивируешь сам.
#
#   1. экспорт iOS из Godot (перезаписывает ios_export/ целиком);
#   2. этот скрипт;
#   3. архив и заливка из Xcode.
#
# В dev/release_testflight.sh он НЕ ВСТАВЛЯЕТСЯ. Там в пресете стоит
# application/export_project_only=false, и Godot внутри одного вызова
# --export-release сам зовёт xcodebuild archive и exportArchive: окна между
# «проект собран» и «архив готов» не существует, вклиниться некуда.
#
# Для того конвейера чинится ШАБЛОН экспорта, откуда значение и приходит, —
# см. `--patch-template` в release_testflight.sh.
#
# ── ЗАЧЕМ ОН ВООБЩЕ НУЖЕН ───────────────────────────────────────────────────
# App Store отказывается принимать сборку с нижней версией iOS 12.0:
#
#   This bundle is invalid. The value provided for the key MinimumOSVersion
#   '12.0' is not acceptable                                      (код 90068)
#
# Само значение в Info.plist не лежит — Xcode выводит его из
# IPHONEOS_DEPLOYMENT_TARGET при сборке. А тот приходит из ШАБЛОНА ЭКСПОРТА
# Godot, где зашит намертво: настройки экспорта под нижнюю версию в этой версии
# движка нет вовсе.
#
# То есть поправленное руками в Xcode живёт ровно до следующего экспорта, после
# чего молча возвращается 12.0 — и узнаётся это в самом конце, после сборки,
# архива и двадцати минут заливки.
#
# Если экспорт перестанет сбрасывать значение (в движке появится своя настройка
# или сменится шаблон) — скрипт просто ничего не найдёт и скажет об этом.
#
# За тем, что правка на месте, следит ещё и dev/smoke_release.gd: он падает на
# любом значении ниже нужного.
set -euo pipefail

# Столько же стоит в dev/smoke_release.gd — держать два разных числа значит
# однажды починить одно и уехать на втором.
MIN_IOS="15.0"

cd "$(dirname "$0")/../.."
PBX="ios_export/Normaldo.xcodeproj/project.pbxproj"

if [ ! -f "$PBX" ]; then
	echo "нет проекта Xcode: $PBX" >&2
	echo "сначала экспорт iOS из Godot" >&2
	exit 1
fi

before=$(grep -c "IPHONEOS_DEPLOYMENT_TARGET" "$PBX" || true)
if [ "$before" -eq 0 ]; then
	echo "в проекте нет ни одной строки IPHONEOS_DEPLOYMENT_TARGET" >&2
	echo "шаблон экспорта изменился — проверь руками" >&2
	exit 1
fi

# Правится ЛЮБОЕ значение, а не только 12.0: шаблон может однажды приехать с
# 13.0, и тогда молчаливый пропуск был бы хуже лишней правки.
sed -i '' -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = ${MIN_IOS};/g" "$PBX" 2>/dev/null \
	|| sed -i -E "s/IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;/IPHONEOS_DEPLOYMENT_TARGET = ${MIN_IOS};/g" "$PBX"

after=$(grep -c "IPHONEOS_DEPLOYMENT_TARGET = ${MIN_IOS};" "$PBX" || true)
echo "нижняя версия iOS: ${MIN_IOS} в ${after} из ${before} мест"
if [ "$after" -ne "$before" ]; then
	echo "часть строк не поддалась — проверь $PBX руками" >&2
	exit 1
fi
