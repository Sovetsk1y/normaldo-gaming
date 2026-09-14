#!/usr/bin/env python3
"""Версия игры → настройки сборки. И номер сборки обратно.

    python3 dev/tools/sync_version.py            # синхронизировать
    python3 dev/tools/sync_version.py --check    # только сверить, ничего не писать

── ГДЕ ЖИВЁТ ВЕРСИЯ ────────────────────────────────────────────────────────────
В `project.godot` → `application/config/version`. Это Project Settings →
Application → Config → Version в редакторе Godot: одно поле, одно место, видно
глазами. Его же игра показывает в настройках и шлёт в аналитику.

`export_presets.cfg` → `application/short_version` — ПРОИЗВОДНОЕ. Скрипт
переписывает его перед каждой сборкой, руками туда лезть незачем.

── ПОЧЕМУ НЕ НАОБОРОТ ──────────────────────────────────────────────────────────
Сначала было наоборот — версия жила в пресете, а скрипт нёс её в игру. И сразу
подвело: `export_presets.cfg` у каждого разработчика СВОЙ (в нём настройки
подписи), в гите он расходится с рабочей копией — и «версия проекта» оказалась
величиной, которая у всех разная. В репозитории лежало 1.0.3, на машине 1.9.3, и
какая из них настоящая, не мог сказать никто.

`project.godot` общий для всех и коммитится как обычный файл. Поэтому источник —
он.

── НОМЕР СБОРКИ ИДЁТ В ДРУГУЮ СТОРОНУ ──────────────────────────────────────────
`application/version` (CFBundleVersion) — счётчик заливок, его поднимает сам
release_testflight.sh, и печатать его руками не надо никогда. Он переносится
ОБРАТНО, из пресета в `application/config/build`, чтобы игра могла показать, какая
именно сборка стоит на телефоне: две заливки бывают с одной версией и разными
номерами, и без номера их не различить ничем.
"""
from __future__ import annotations
import pathlib
import re
import sys

ROOT     = pathlib.Path(__file__).resolve().parents[2]
PRESETS  = ROOT / "export_presets.cfg"
PROJECT  = ROOT / "project.godot"


def ios_block(text: str) -> tuple[int, int]:
    """Границы секций пресета iOS — от заголовка до следующего заголовка.

    Версии лежат не в `[preset.N]`, а в `[preset.N.options]`, то есть за той
    скобкой, на которой останавливается наивный поиск «от слова iOS до
    следующей скобки».
    """
    heads = [m.start() for m in re.finditer(r'^\[preset\.\d+\]', text, re.M)]
    for i, start in enumerate(heads):
        end = heads[i + 1] if i + 1 < len(heads) else len(text)
        if 'platform="iOS"' in text[start:end]:
            return start, end
    raise SystemExit('в export_presets.cfg не нашёлся пресет с platform="iOS"')


def read_key(block: str, key: str) -> str:
    m = re.search(rf'^{re.escape(key)}="([^"]*)"', block, re.M)
    return m.group(1) if m else ""


def main() -> int:
    check_only = "--check" in sys.argv
    presets = PRESETS.read_text(encoding="utf-8")
    project = PROJECT.read_text(encoding="utf-8")

    start, end = ios_block(presets)
    block = presets[start:end]

    version = read_key(project, "config/version")
    if not version:
        raise SystemExit("в project.godot пусто application/config/version — "
                         "поставьте версию в Project Settings → Application → Config")
    build = read_key(block, "application/version")
    if not build:
        raise SystemExit("в пресете iOS нет application/version (номера сборки)")

    preset_ver = read_key(block, "application/short_version")
    project_bld = read_key(project, "config/build")
    ok = preset_ver == version and project_bld == build
    if ok:
        print(f"совпадают: версия {version}, сборка {build}")
        return 0
    if check_only:
        print(f"РАЗОШЛИСЬ: версия в игре {version}, в пресете {preset_ver or '—'}; "
              f"сборка в пресете {build}, в игре {project_bld or '—'}")
        print("почините: python3 dev/tools/sync_version.py")
        return 1

    # Версия: игра → пресет.
    block_new = re.sub(r'^application/short_version="[^"]*"',
                       f'application/short_version="{version}"',
                       block, count=1, flags=re.M)
    PRESETS.write_text(presets[:start] + block_new + presets[end:], encoding="utf-8")

    # Номер сборки: пресет → игра.
    if re.search(r'^config/build="', project, re.M):
        project = re.sub(r'^config/build="[^"]*"', f'config/build="{build}"',
                         project, count=1, flags=re.M)
    else:
        # Строки ещё нет — ставим сразу за версией, чтобы читались парой.
        project = re.sub(r'^(config/version="[^"]*")', rf'\1\nconfig/build="{build}"',
                         project, count=1, flags=re.M)
    PROJECT.write_text(project, encoding="utf-8")

    print(f"версия {version} → пресет (было {preset_ver or '—'})")
    print(f"сборка {build} → игра (было {project_bld or '—'})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
