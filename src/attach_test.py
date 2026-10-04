"""RGAccess test B: put an Edge app window INSIDE the Realm Grinder window.

Run this while the game is open. It opens a tiny test page in Edge app mode,
turns that window into a child of the game window, and keeps it sized to fit.
Close the game (or press Ctrl+C here) to end the test.
"""
import ctypes
import os
import subprocess
import tempfile
import time
import urllib.parse
from ctypes import wintypes

user32 = ctypes.WinDLL("user32", use_last_error=True)

GWL_STYLE = -16
WS_CHILD = 0x40000000
WS_POPUP = 0x80000000
WS_CAPTION = 0x00C00000
WS_THICKFRAME = 0x00040000
WS_VISIBLE = 0x10000000

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
TITLE = "RGAccess test"
PAGE = f"""<!doctype html><html><head><title>{TITLE}</title></head><body>
<h1>RGAccess test</h1><p>If NVDA can read this, option B works.</p>
<h2>Second heading</h2>
<button onclick="this.textContent='Clicked!'">Press me</button>
</body></html>"""

EnumProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)


def find_window(test):
    """Return the first visible top-level window for which test(class, title) is true."""
    found = []

    def cb(hwnd, _):
        if user32.IsWindowVisible(hwnd):
            cls = ctypes.create_unicode_buffer(256)
            title = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(hwnd, cls, 256)
            user32.GetWindowTextW(hwnd, title, 256)
            if test(cls.value, title.value):
                found.append(hwnd)
                return False
        return True

    user32.EnumWindows(EnumProc(cb), 0)
    return found[0] if found else None


def fit(child, parent):
    rect = wintypes.RECT()
    user32.GetClientRect(parent, ctypes.byref(rect))
    user32.MoveWindow(child, 0, 0, rect.right, rect.bottom, True)


def main():
    game = find_window(lambda c, t: c == "ApolloRuntimeContentWindow")
    if not game:
        print("Realm Grinder isn't running. Start it first.")
        return

    profile = os.path.join(tempfile.gettempdir(), "rgaccess_edge_profile")
    url = "data:text/html," + urllib.parse.quote(PAGE)
    edge_proc = subprocess.Popen([EDGE, f"--app={url}", f"--user-data-dir={profile}",
                                  "--no-first-run", "--no-default-browser-check"])

    page = None
    for _ in range(100):  # wait up to 10 seconds for the Edge window
        page = find_window(lambda c, t: t.startswith(TITLE))
        if page:
            break
        time.sleep(0.1)
    if not page:
        print("Couldn't find the Edge window.")
        return

    # Turn the Edge window into a borderless child of the game window.
    style = user32.GetWindowLongW(page, GWL_STYLE)
    style = (style & ~(WS_POPUP | WS_CAPTION | WS_THICKFRAME)) | WS_CHILD | WS_VISIBLE
    user32.SetWindowLongW(page, GWL_STYLE, style)
    user32.SetParent(page, game)
    fit(page, game)
    user32.SetForegroundWindow(game)
    print("Attached. Switch to the game and try H / Shift+H and the button.")

    try:
        while user32.IsWindow(game):
            fit(page, game)
            time.sleep(0.5)
    except KeyboardInterrupt:
        pass
    finally:
        edge_proc.terminate()
        print("Test ended.")


if __name__ == "__main__":
    main()
