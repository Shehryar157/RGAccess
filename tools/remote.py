"""Drive the running game through the mod's remote control (src/mod/RGARemote.as), no keyboard needed.

    python tools/remote.py start                      start the game (detached) and wait for the mod
    python tools/remote.py stop                       ask the game window to close (it saves), kill if it will not
    python tools/remote.py "press Upgrades" "dump upgrades"
    python tools/remote.py show upgrades              print rga_page_upgrades.txt

Commands run one per second inside the game; this waits for rga_cmd_done.txt and prints it.
See RGARemote.as for the command list.
"""
import os
import subprocess
import sys
import time

import build

STORE = os.path.expandvars(r"%APPDATA%\com.kongregate.mobile.realmgrinder.air\Local Store")
EXE = os.path.join(build.GAME, "RealmGrinderDesktop.exe")
CMD = os.path.join(STORE, "rga_cmd.txt")
DONE = os.path.join(STORE, "rga_cmd_done.txt")
LOG = os.path.join(STORE, "rga_debug.log")


def running():
    out = subprocess.run(["tasklist", "/FI", "IMAGENAME eq RealmGrinderDesktop.exe"], capture_output=True, text=True).stdout
    return "RealmGrinderDesktop.exe" in out


def stop():
    if not running():
        print("game was not running")
        return
    subprocess.run(["powershell", "-NoProfile", "-Command",
                    "Get-Process RealmGrinderDesktop | ForEach-Object { $_.CloseMainWindow() | Out-Null }"])
    for _ in range(15):
        time.sleep(1)
        if not running():
            print("game closed")
            return
    subprocess.run(["taskkill", "/F", "/IM", "RealmGrinderDesktop.exe"], capture_output=True)
    print("game killed (it did not close by itself)")


def start():
    if running():
        print("game already running")
        return
    size = os.path.getsize(LOG) if os.path.exists(LOG) else 0
    subprocess.Popen([EXE], cwd=build.GAME, creationflags=0x00000008 | 0x00000200)  # detached, own group
    for _ in range(40):
        time.sleep(1)
        if os.path.exists(LOG) and os.path.getsize(LOG) > size:
            time.sleep(8)  # let the game finish loading its first screen
            print("game started, running:", running())
            return
        if not running():
            break
    print("GAME DID NOT START (running: %s)" % running())


def send(commands, timeout=None):
    for path in (CMD, DONE):
        if os.path.exists(path):
            os.remove(path)
    with open(CMD, "w", encoding="utf-8") as f:
        f.write("\n".join(commands))
    waits = sum(int(c.split()[1]) for c in commands if c.startswith("wait "))
    timeout = timeout or len(commands) + waits + 10
    for _ in range(timeout * 2):
        time.sleep(0.5)
        if os.path.exists(DONE):
            time.sleep(0.2)
            print(open(DONE, encoding="utf-8", errors="replace").read())
            return
    print("NO ANSWER after %d s (game running: %s)" % (timeout, running()))


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["start"]:
        start()
    elif args[:1] == ["stop"]:
        stop()
    elif args[:1] == ["show"]:
        for name in args[1:]:
            print(open(os.path.join(STORE, "rga_page_%s.txt" % name), encoding="utf-8", errors="replace").read())
    else:
        send(args)
