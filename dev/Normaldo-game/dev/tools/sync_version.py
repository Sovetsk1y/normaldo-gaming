#!/usr/bin/env python3
"""Версия сборки → версия, которую показывает игра.

    python3 dev/tools/sync_version.py            # синхронизировать
    python3 dev/tools/sync_version.py --check    # только проверить, ничего не писать

── ЗАЧЕМ ───────────────────────────────────────────────────────────────────────
Версий в проекте две, и живут они в разных файлах:

  * `export_presets.cfg` → `application/short_version` и `application/version` —
    то, что уходит в Info.plist и что видно в TestFlight. Это ТА САМАЯ версия,
    которую разработчик пишет руками перед сборкой;
  * `project.godot` → `application/config/version` — то, что игра показывает в
    настройках и шлёт в аналитику.

Прочитать пресет в игре нельзя: `export_presets.cfg` — файл РЕДАКТОРА, в сборку
он не попадает вовсе. Поэтому версию переносит этот скрипт — до экспорта.

Разошлись они молча и надолго: в пресете стояло 1.0.3, в игре показывалось
1.0.1, и на вопрос «а новая ли сборка у меня на телефоне» экран настроек отвечал
неправдой. Ровно тогда, когда ответ и был нужен.

── НОМЕР СБОРКИ ТОЖЕ ───────────────────────────────────────────────────────────
`application/version` (CFBundleVersion) — счётчик сборок. Именно он различает две
заливки с одинаковой версией, и именно его не хватало, чтобы понять, та ли
сборка стоит на телефоне. Он кладётся в `application/config/build` рядом —
отдельно, а не внутрь строки версии: версия уходит в аналитику, и номер сборки
размыл бы там группировку.
"""
from __future__ import annotations
import pathlib
import re
import sys

ROOT     = pathlib.Path(__file__).resolve().parents[2]
PRESETS  = ROOT / "export_presets.cfg"
PROJECT  = ROOT / "project.godot"


def ios_preset_versions(text: str) -> tuple[str, str]:
    """`short_version` и `version` из пресета iOS.

    Секция ищется по `platform="iOS"`, а не по имени пресета: имя разработчик
    волен поменять, платформу — нет.
    """
    blocks = re.split(r'\n(?=\[preset\.\d+\])', text)
    for b in blocks:
        if 'platform="iOS"' not in b:
            continue
        short = re.search(r'^application/short_version="([^"]*)"', b, re.M)
        build = re.search(r'^application/version="([^"]*)"', b, re.M)
        if short is None or build is None:
            raise SystemExit("в пресете iOS нет application/short_version или "
                             "application/version")
        return short.group(1), build.group(1)
    raise SystemExit('в export_presets.cfg не нашёлся пресет с platform="iOS"')


def project_versions(text: str) -> tuple[str, str]:
    ver = re.search(r'^config/version="([^"]*)"', text, re.M)
    bld = re.search(r'^config/build="([^"]*)"', text, re.M)
    return (ver.group(1) if ver else ""), (bld.group(1) if bld else "")


def write_project(text: str, short: str, build: str) -> str:
    text = re.sub(r'^config/version="[^"]*"', f'config/version="{short}"',
                  text, count=1, flags=re.M)
    if re.search(r'^config/build="', text, re.M):
        return re.sub(r'^config/build="[^"]*"', f'config/build="{build}"',
                      text, count=1, flags=re.M)
    # Строки ещё нет — ставим сразу за версией, чтобы они читались парой.
    return re.sub(r'^(config/version="[^"]*")',
                  rf'\1\nconfig/build="{build}"', text, count=1, flags=re.M)


def main() -> int:
    check_only = "--check" in sys.argv
    presets = PRESETS.read_text(encoding="utf-8")
    project = PROJECT.read_text(encoding="utf-8")
    short, build = ios_preset_versions(presets)
    cur_ver, cur_build = project_versions(project)

    if (cur_ver, cur_build) == (short, build):
        print(f"версии совпадают: {short} (сборка {build})")
        return 0
    if check_only:
        print(f"РАЗОШЛИСЬ: в пресете {short} (сборка {build}), "
              f"в игре {cur_ver or '—'} (сборка {cur_build or '—'})")
        print("почините: python3 dev/tools/sync_version.py")
        return 1

    PROJECT.write_text(write_project(project, short, build), encoding="utf-8")
    print(f"project.godot: {cur_ver or '—'} (сборка {cur_build or '—'}) "
          f"→ {short} (сборка {build})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
