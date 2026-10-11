"""Smoke test: install a SWF, run the game for a while, report whether it survived and what it logged.

    python tools/smoke.py                 test the current full build
    python tools/smoke.py main_only       cleaned Main + logger only
    python tools/smoke.py with:Doc,Speech  Main + logger + only those mod files
    python tools/smoke.py no_call         every mod class present, but RGA.start not called

The game's SWF is put back to whatever it was before the test.
"""
import os
import re
import shutil
import subprocess
import sys
import time

import build

EXE = os.path.join(build.GAME, "RealmGrinderDesktop.exe")
GAME_SWF = os.path.join(build.GAME, "RealmGrinderDesktop.swf")
LOG = os.path.expandvars(r"%APPDATA%\com.kongregate.mobile.realmgrinder.air\Local Store\rga_debug.log")
CALL = re.compile(r"try\s*\{\s*RGA\.start\(stage\);.*?\n         \}\n         catch.*?\n         \}\n", re.S)
PROBE = '         RGALog.write("init finished");\n'


def variant(name):
    """Write build/Main.as for the named variant and return its path."""
    if name == "full":
        return build.bundle()
    only = None
    if name == "main_only":
        only = ["RGALog"]
    elif name.startswith("with:"):
        only = ["RGALog"] + name[5:].split(",")
    path = build.bundle(only)
    text = open(path, encoding="utf-8").read()
    assert CALL.search(text), "RGA.start call not found"
    open(path, "w", encoding="utf-8").write(CALL.sub(PROBE, text))
    return path


def run(swf, seconds=20):
    keep = GAME_SWF + ".smoke_keep"
    shutil.copy2(GAME_SWF, keep)
    if os.path.exists(LOG):
        os.remove(LOG)
    try:
        shutil.copy2(swf, GAME_SWF)
        proc = subprocess.Popen([EXE], cwd=build.GAME)
        died_at = None
        for tick in range(seconds):
            time.sleep(1)
            if proc.poll() is not None:
                died_at = tick + 1
                break
        if died_at is None:
            proc.kill()
            print("SURVIVED %d seconds" % seconds)
        else:
            print("QUIT after %d seconds, exit code %s" % (died_at, proc.returncode))
        time.sleep(1)
    finally:
        shutil.move(keep, GAME_SWF)
    if os.path.exists(LOG):
        print("--- rga_debug.log ---")
        print(open(LOG, encoding="utf-8", errors="replace").read()[-3000:])
    else:
        print("no rga_debug.log written")


if __name__ == "__main__":
    for name in sys.argv[1:] or ["full"]:
        print("=== %s ===" % name)
        run(build.compile_swf(variant(name)))
