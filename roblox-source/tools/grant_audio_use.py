#!/usr/bin/env python3
"""Выдать universe игры право Use на все звуки Pawtown (Config.SOUNDS).

Звуки, загруженные через Open Cloud (tools/upload_audio.py), в живой игре не грузятся, пока их universe не получит
право Use (ContentProvider отдаёт Failure; клиент тогда молчит и повторяет загрузку — игра не ломается).
Запускать один раз, когда universe Pawtown создан:

    ROBLOX_OPEN_CLOUD_KEY=… python3 tools/grant_audio_use.py <universeId>
    ROBLOX_OPEN_CLOUD_KEY=… ROBLOX_UNIVERSE_ID=<universeId> python3 tools/grant_audio_use.py [--dry-run]

ID берутся из src/ReplicatedStorage/Config.lua (Config.SOUNDS, ненулевые). Ключ только из окружения, не печатается.
Печатает JSON с точным ответом asset-permissions-api.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import upload_audio  # noqa: E402

CONFIG = os.path.join(HERE, "..", "src", "ReplicatedStorage", "Config.lua")


def sound_ids(path=CONFIG):
    src = open(path, encoding="utf-8").read()
    m = re.search(r"Config\.SOUNDS\s*=\s*\{(.*?)\n\}", src, re.S)
    if not m:
        raise SystemExit("Config.SOUNDS not found in " + path)
    out = {}
    for name, num in re.findall(r"^\s*([A-Z_]+)\s*=\s*(\d+)", m.group(1), re.M):
        if int(num) > 0:
            out[name] = int(num)
    return out


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    universe = args[0] if args else os.environ.get("ROBLOX_UNIVERSE_ID", "")
    ids = sound_ids()
    if "--dry-run" in sys.argv:
        print(json.dumps({"universe": universe or None, "assets": ids}, indent=2))
        sys.exit(0)
    if not universe:
        print(json.dumps({"error": "pass the universe id as an argument or set ROBLOX_UNIVERSE_ID"}))
        sys.exit(2)
    key = os.environ.get("ROBLOX_OPEN_CLOUD_KEY", "")
    if not key:
        print(json.dumps({"error": "ROBLOX_OPEN_CLOUD_KEY is not set"}))
        sys.exit(2)
    g = upload_audio.grant_use(sorted(set(ids.values())), key, universe)
    print(json.dumps({"universe": universe, "assets": ids, "grant": g}, ensure_ascii=False, indent=2))
    sys.exit(0 if g["httpStatus"] < 300 else 1)
