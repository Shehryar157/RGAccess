"""RG Access installer, updater and uninstaller: one file the player runs and waits for.

RGAccess-Setup.exe:
  1. asks GitHub whether a newer installer has been released; if so it shows the new
     version and what's new, and on Update downloads that one and hands over to it (Skip
     carries on with the version this file carries; the offer comes back on the next run);
  2. finds Realm Grinder through Steam (or asks for the folder);
  3. rebuilds the game's code file, RealmGrinderDesktop.swf, with the mod in it, from the
     player's own copy and the differences this setup carries (installer/patch.py). The
     untouched file is kept beside it for the uninstaller;
  4. copies the speech helper into <game>\\RGAccess.

Running it again later is how you update. The installed copy of this program,
"Uninstall RG Access.exe", removes it all again. Messages are standard Windows message
boxes, which screen readers read in full; downloading and installing show a progress
window with Cancel (installer/ui.py), and the end plays the Windows alert sound and says
"Done: Updated RG Access from <old> to <new>." (version.txt records the installed one).

  --no-update     skip step 1 (the newer installer starts this one with it)
  --game <dir>    install into this folder instead of looking for the game (testing)
  --silent        print messages instead of showing them, answer yes, and don't check
                  whether the game is running (testing, on a scratch folder)
"""
import ctypes
import json
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

import patch    # the game file as differences (installer/patch.py)
import steam    # finding the game's folder (installer/steam.py)
import ui       # the installer's windows (installer/ui.py)

TITLE = "RG Access"
REPO = "Shehryar157/RGAccess"
ASSET = "RGAccess-Setup.exe"
GAME_NAME = "Realm Grinder"
GAME_FOLDER, GAME_EXE = "Realm Grinder", "RealmGrinderDesktop.exe"
SWF = "RealmGrinderDesktop.swf"             # the game's code, which the mod goes into
SWF_BACKUP = SWF + ".before-rgaccess"       # the untouched one
MOD_FOLDER, HELPER_EXE = "RGAccess", "rga_speech.exe"
UNINSTALLER = "Uninstall RG Access.exe"
VERSION_FILE = "version.txt"    # in <game>\RGAccess: which version is installed
SWF_MARK = "swf.sha256"         # in <game>\RGAccess: the fingerprint of the file we wrote
PATCH = "_patch/"               # in payload.zip: the differences, not copied to the game
HIDDEN = 0x08000000     # CREATE_NO_WINDOW

MB_OK, MB_YESNO, MB_OKCANCEL, MB_DEFBUTTON2 = 0x0, 0x4, 0x1, 0x100   # DEFBUTTON2: Enter = No
MB_ICONINFO, MB_ICONWARN, MB_ICONERROR, MB_ICONQUESTION = 0x40, 0x30, 0x10, 0x20
IDYES, IDOK = 6, 1
SILENT = "--silent" in sys.argv


class Stop(Exception):
    """Setup can't go on; the text is shown to the player. Nothing has been changed."""


def message(text, flags=MB_OK | MB_ICONINFO):
    if SILENT:
        print(text)
        return IDYES if flags & MB_YESNO else IDOK
    return ctypes.windll.user32.MessageBoxW(None, text, TITLE, flags | 0x10000)  # 0x10000: in front


def bundled(name):
    """A file this setup carries: inside the .exe, or in the project when run from source
    (payload.zip is then the one tools/build_release.py left in build/release)."""
    here = os.path.dirname(os.path.abspath(__file__))
    for base in (getattr(sys, "_MEIPASS", here), os.path.dirname(here),
                 os.path.join(os.path.dirname(here), "build", "release")):
        if os.path.exists(os.path.join(base, name)):
            return os.path.join(base, name)
    raise Stop(f"This setup is incomplete: {name} is missing.")


with open(bundled("VERSION"), encoding="utf-8") as _f:
    VERSION = _f.read().strip()


def numbers(version):
    """ "v0.10.1" -> (0, 10, 1), so versions compare as numbers, not as text."""
    return tuple(int(part) for part in version.lstrip("v").split(".") if part.isdigit())


def download(address, path):
    """Fetch a web address into a file with Windows' own downloader (urlmon, what
    Explorer uses), so the installer needn't carry Python's 6 MB of encryption code.
    Raises OSError when it fails."""
    ctypes.windll.wininet.DeleteUrlCacheEntryW(address)     # never an old, remembered answer
    if ctypes.windll.urlmon.URLDownloadToFileW(None, address, path, 0, None) != 0:
        raise OSError(f"could not download {address}")


def fetch(address, path, progress):
    """Download a big file in pieces (WinINet, Windows' web library), reporting each
    piece to the progress window and stopping at Cancel. Raises OSError when it fails,
    ui.Cancelled when the player cancels; either way no half file is left behind."""
    from ctypes import wintypes
    net = ctypes.windll.wininet
    net.InternetOpenW.restype = net.InternetOpenUrlW.restype = ctypes.c_void_p
    net.InternetOpenUrlW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR, wintypes.LPCWSTR,
                                     wintypes.DWORD, wintypes.DWORD, ctypes.c_size_t]
    net.HttpQueryInfoW.argtypes = [ctypes.c_void_p, wintypes.DWORD, ctypes.c_void_p,
                                   ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p]
    net.InternetReadFile.argtypes = [ctypes.c_void_p, ctypes.c_void_p, wintypes.DWORD,
                                     ctypes.POINTER(wintypes.DWORD)]
    net.InternetCloseHandle.argtypes = [ctypes.c_void_p]
    net.InternetOpenW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPCWSTR, wintypes.LPCWSTR,
                                  wintypes.DWORD]
    session = net.InternetOpenW("RGAccess-Setup", 0, None, None, 0)
    # Always fresh from the server, not from the cache.
    url = net.InternetOpenUrlW(session, address, None, 0, 0x80000000 | 0x04000000, 0) if session else None
    try:
        if not url:
            raise OSError(f"could not download {address}")
        number, size = wintypes.DWORD(), wintypes.DWORD(4)
        as_number = 0x20000000
        net.HttpQueryInfoW(url, 19 | as_number, ctypes.byref(number), ctypes.byref(size), None)
        if number.value != 200:                                     # 19 = status code
            raise OSError(f"the server answered {number.value} for {address}")
        size.value = 4
        total = number.value if net.HttpQueryInfoW(url, 5 | as_number, ctypes.byref(number),
                                                   ctypes.byref(size), None) else 0   # 5 = length
        piece, got, done = ctypes.create_string_buffer(65536), wintypes.DWORD(), 0
        with open(path, "wb") as out:
            while True:
                progress.check()
                if not net.InternetReadFile(url, piece, len(piece), ctypes.byref(got)):
                    raise OSError(f"the download of {address} broke off")
                if not got.value:
                    break
                out.write(piece.raw[:got.value])
                done += got.value
                megabytes = f"{done / 1e6:.1f}" + (f" of {total / 1e6:.1f}" if total else "")
                progress.update(done / total if total else None, f"Downloaded {megabytes} MB")
    except BaseException:
        try:
            os.remove(path)
        except OSError:
            pass
        raise
    finally:
        for handle in (url, session):
            if handle:
                net.InternetCloseHandle(handle)


def read_text(path):
    """A small text file's contents, or None when it isn't there."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip() or None
    except OSError:
        return None


def installed_version(target):
    """The version an earlier setup installed (it writes VERSION_FILE), or None."""
    return read_text(os.path.join(target, VERSION_FILE))


def current_install():
    """The installed version, found quietly: through --game or Steam, never a dialog.
    None when the mod isn't installed or the game isn't found that way."""
    game = (os.path.normpath(sys.argv[sys.argv.index("--game") + 1]) if "--game" in sys.argv
            else steam.find_game(GAME_FOLDER, GAME_EXE))
    return installed_version(os.path.join(game, MOD_FOLDER)) if game else None


def newest(*versions):
    """The highest of these versions (None ones ignored), compared as numbers."""
    return max((v for v in versions if v), key=numbers)


def newer_installer(have):
    """(version, download address, what's new) of a released installer newer than
    `have` (the newer of the installed version and this setup's), or None. Any trouble
    (no internet, no release yet) means None: install what we carry. "What's new" is
    the description written on the GitHub release."""
    answer = os.path.join(tempfile.gettempdir(), "RGAccess-latest.json")
    try:
        download(f"https://api.github.com/repos/{REPO}/releases/latest", answer)
        with open(answer, encoding="utf-8") as f:
            release = json.load(f)
        if numbers(release["tag_name"]) <= numbers(have):
            return None
        for asset in release["assets"]:
            if asset["name"] == ASSET:
                return (release["tag_name"].lstrip("v"), asset["browser_download_url"],
                        (release.get("body") or "").lstrip("﻿"))   # no byte-order mark
    except (OSError, ValueError, KeyError):
        pass
    return None


def update():
    """Offer a newer installer if there is one. "taken over": the player said Update and
    the new installer is running. "skipped": the player said Skip; the offer comes back
    the next time the setup is run. None: there was nothing newer."""
    installed = current_install()
    found = newer_installer(newest(installed, VERSION))
    if found is None:
        return None
    version, address, notes = found
    have = f"You have {installed}." if installed else f"This setup is {VERSION}."
    if SILENT:
        print(f"update found: {version}. {have}\n{notes}")
    elif not ui.ask_update(version, notes, have):
        return "skipped"
    target = os.path.join(tempfile.gettempdir(), f"RGAccess-Setup-{version}.exe")
    progress = ui.Progress(f"Downloading RG Access {version}", f"Downloading RG Access {version}",
                           "Stop downloading the update? Nothing has been changed.", SILENT)
    try:
        progress.run(lambda p: fetch(address, target + ".part", p))
        os.replace(target + ".part", target)
        subprocess.Popen([target, "--no-update"] + [a for a in sys.argv[1:] if a != "--no-update"])
    except OSError:
        return None             # the download failed: install the version we carry
    return "taken over"         # ui.Cancelled passes through to main(): stop, nothing changed


def is_running(exe):
    out = subprocess.run(["tasklist", "/FI", f"IMAGENAME eq {exe}", "/NH"],
                         capture_output=True, text=True, creationflags=HIDDEN).stdout
    return exe.lower() in out.lower()


def wait_for_game_closed():
    if SILENT:      # testing, on a scratch folder: nobody is there to close the game
        return True
    while is_running(GAME_EXE):
        if message(f"{GAME_NAME} is running. Please close it, then press OK.\n\n"
                   "Cancel stops the setup.", MB_OKCANCEL | MB_ICONWARN) != IDOK:
            return False
    # The speech helper closes with the game; stop a copy that's still running anyway.
    subprocess.run(["taskkill", "/F", "/IM", HELPER_EXE], capture_output=True, creationflags=HIDDEN)
    return True


def is_game_dir(folder):
    return os.path.exists(os.path.join(folder, GAME_EXE))


def browse_for_folder(title):
    """Windows' standard "Browse for folder" tree; the chosen path, or None."""
    from ctypes import wintypes

    class BROWSEINFO(ctypes.Structure):
        _fields_ = [("hwndOwner", wintypes.HWND), ("pidlRoot", ctypes.c_void_p),
                    # A buffer Windows writes into: a pointer field takes a ctypes array,
                    # LPWSTR (c_wchar_p) only takes a str and raised TypeError.
                    ("pszDisplayName", ctypes.POINTER(ctypes.c_wchar)), ("lpszTitle", wintypes.LPCWSTR),
                    ("ulFlags", wintypes.UINT), ("lpfn", ctypes.c_void_p),
                    ("lParam", wintypes.LPARAM), ("iImage", ctypes.c_int)]

    shell32, ole32 = ctypes.windll.shell32, ctypes.windll.ole32
    shell32.SHBrowseForFolderW.restype = ctypes.c_void_p
    shell32.SHBrowseForFolderW.argtypes = [ctypes.POINTER(BROWSEINFO)]
    ole32.CoInitialize.argtypes = [ctypes.c_void_p]
    shell32.SHGetPathFromIDListW.argtypes = [ctypes.c_void_p, wintypes.LPWSTR]
    ole32.CoTaskMemFree.argtypes = [ctypes.c_void_p]
    ole32.CoInitialize(None)
    name = ctypes.create_unicode_buffer(260)
    info = BROWSEINFO(None, None, name, title, 0x1 | 0x40, None, 0, 0)   # folders only, new style
    chosen = shell32.SHBrowseForFolderW(ctypes.byref(info))
    if not chosen:
        return None
    path = ctypes.create_unicode_buffer(1024)
    ok = shell32.SHGetPathFromIDListW(chosen, path)
    ole32.CoTaskMemFree(chosen)
    return os.path.normpath(path.value) if ok else None


def ask_for_game_dir():
    message(f"{GAME_NAME} wasn't found through Steam.\n\n"
            f"Next, choose the game's folder: the one that contains {GAME_EXE}.")
    while True:
        folder = browse_for_folder(f"{GAME_NAME} folder")
        if not folder:
            return None
        if is_game_dir(folder):
            return folder
        if message(f"{GAME_EXE} isn't in that folder. Choose again?", MB_YESNO | MB_ICONWARN) != IDYES:
            return None


def chosen_game_dir():
    if "--game" in sys.argv:
        return os.path.normpath(sys.argv[sys.argv.index("--game") + 1])
    return steam.find_game(GAME_FOLDER, GAME_EXE) or ask_for_game_dir()


def file_sha(path):
    """A file's fingerprint (SHA-256), or None when it isn't there."""
    try:
        with open(path, "rb") as f:
            return patch.sha256(f.read())
    except OSError:
        return None


def untouched_swf(game, target, original_sha):
    """The path of the game's untouched code file: the game's own if the mod isn't in it
    yet, else the copy an earlier setup kept. Raises Stop when the file in the game is
    neither the one this mod was made for nor one we wrote: the game was updated, or
    something else changed it, and patching it blindly could break the game."""
    swf, backup = os.path.join(game, SWF), os.path.join(game, SWF_BACKUP)
    now = file_sha(swf)
    if now == original_sha:
        return swf
    if now and now == read_text(os.path.join(target, SWF_MARK)) and file_sha(backup) == original_sha:
        return backup
    raise Stop(f"{GAME_NAME}'s code file isn't the version RG Access {VERSION} was made for. "
               "The game may have been updated, or another mod changed it.\n\n"
               "Nothing was changed. In Steam, right-click the game, choose Properties, "
               "Installed Files, Verify integrity of game files, then run this setup again. "
               "If that doesn't help, the mod needs an update for the new game version.")


def put_in_place(progress, game, target):
    """Unpack the speech helper beside the installed one (<game>\\RGAccess.new) and work
    out the modded game file in memory: the slow part, which Cancel can stop without harm.
    Then swap everything in: a second's work that Cancel can't break. Progress is counted
    in bytes, so one big file moves the bar as much as it should."""
    staging = target + ".new"
    shutil.rmtree(staging, ignore_errors=True)
    try:
        with zipfile.ZipFile(bundled("payload.zip")) as z:
            about = json.loads(z.read(PATCH + "swf.json"))
            source = untouched_swf(game, target, about["original_sha256"])
            files = [info for info in z.infolist() if not info.is_dir() and not info.filename.startswith(PATCH)]
            total, done = sum(info.file_size for info in files) or 1, 0
            for number, info in enumerate(files, 1):
                status = f"Copying files: {number} of {len(files)}"
                path = os.path.join(staging, *info.filename.split("/"))
                os.makedirs(os.path.dirname(path), exist_ok=True)
                with z.open(info) as piece_source, open(path, "wb") as out:
                    while piece := piece_source.read(1 << 20):
                        out.write(piece)
                        done += len(piece)
                        progress.update(0.8 * done / total, status)
                        progress.check()
            progress.update(0.8, "Adding the mod to the game")
            with open(source, "rb") as f:
                new_body = patch.apply(patch.body(f.read()), z.read(PATCH + "swf.delta"))
            if patch.sha256(new_body) != about["patched_body_sha256"]:
                raise Stop("The modded game file didn't come out right. Nothing was changed.\n\n"
                           "Please download the setup again.")
            progress.check()
            new_swf = patch.pack(bytes.fromhex(about["header"]), new_body)
        progress.finishing("Finishing")
    except BaseException:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    swf, backup = os.path.join(game, SWF), os.path.join(game, SWF_BACKUP)
    if source == swf:
        shutil.copy2(swf, backup)       # the untouched file, for the uninstaller and updates
    os.makedirs(target, exist_ok=True)
    for name in os.listdir(target):
        if name == UNINSTALLER:
            continue
        path = os.path.join(target, name)
        shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
    for name in os.listdir(staging):
        os.replace(os.path.join(staging, name), os.path.join(target, name))
    os.rmdir(staging)
    with open(swf + ".new", "wb") as f:
        f.write(new_swf)
    os.replace(swf + ".new", swf)       # whole file or nothing, never half of one
    if getattr(sys, "frozen", False):
        shutil.copy2(sys.executable, os.path.join(target, UNINSTALLER))
    with open(os.path.join(target, SWF_MARK), "w", encoding="utf-8") as f:
        f.write(patch.sha256(new_swf))  # how the next setup knows the game file is ours
    with open(os.path.join(target, VERSION_FILE), "w", encoding="utf-8") as f:
        f.write(VERSION)    # the next update reads it: "Updated from <this> to <that>"
    progress.update(1.0, "Done")


def install(skipped=False):
    """skipped: the player just said Skip to a newer version."""
    game = chosen_game_dir()
    if not game:
        message("Setup stopped: the game's folder wasn't chosen.", MB_OK | MB_ICONWARN)
        return
    target = os.path.join(game, MOD_FOLDER)
    old_version = installed_version(target)
    if old_version and numbers(old_version) > numbers(VERSION):
        if message(f"RG Access {old_version} is installed, and this setup is {VERSION}, an older "
                   f"version.\n\nInstall {VERSION} anyway?",
                   MB_YESNO | MB_ICONWARN | MB_DEFBUTTON2) != IDYES:
            return
    elif old_version == VERSION:
        if skipped:
            message(f"Update skipped. RG Access {VERSION} stays installed.\n\n"
                    "Run this setup again whenever you want the update.")
            return
        if message(f"RG Access {VERSION} is already installed and up to date.\n\nInstall it again?",
                   MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2) != IDYES:
            return
    if not wait_for_game_closed():
        return
    progress = ui.Progress(f"Installing RG Access {VERSION}", f"Installing RG Access {VERSION}",
                           "Stop installing? Nothing has been changed yet.", SILENT)
    progress.run(lambda p: put_in_place(p, game, target))
    if not SILENT:
        ui.alert()      # the player's Windows alert sound: done
    if old_version:
        if old_version == VERSION:
            done = f"Done: RG Access {VERSION} was installed again."
        elif numbers(old_version) > numbers(VERSION):
            done = f"Done: RG Access went back from {old_version} to {VERSION}."
        else:
            done = f"Done: Updated RG Access from {old_version} to {VERSION}."
        message(done, MB_OK)        # no icon: the alert above was its sound
        return
    message(f"Done: RG Access {VERSION} is installed.\n\n"
            f"Start {GAME_NAME} from Steam as usual. The mod starts with it and says "
            f'"RG Access {VERSION} loaded". Press F1 in the game for help.\n\n'
            "To update later, run this setup again. Run it again too if Steam updates or "
            "repairs the game, because that removes the mod.\n"
            f"To remove the mod, run \"{UNINSTALLER}\" in:\n{target}", MB_OK)


def uninstall():
    game = os.path.dirname(os.path.dirname(os.path.abspath(sys.executable)))
    if "--game" in sys.argv:
        game = chosen_game_dir()
    elif not is_game_dir(game):
        game = steam.find_game(GAME_FOLDER, GAME_EXE)
    if not game:
        message("The game's folder wasn't found, so nothing was removed.", MB_OK | MB_ICONWARN)
        return
    if message(f"Remove RG Access from {GAME_NAME}?", MB_YESNO | MB_ICONQUESTION) != IDYES:
        return
    if not wait_for_game_closed():
        return
    target = os.path.join(game, MOD_FOLDER)
    swf, backup = os.path.join(game, SWF), os.path.join(game, SWF_BACKUP)
    if os.path.exists(backup):
        # Put the untouched file back, unless the game's file isn't ours any more
        # (Steam updated it): then the kept copy is simply out of date.
        if file_sha(swf) == read_text(os.path.join(target, SWF_MARK)):
            os.replace(backup, swf)
        else:
            os.remove(backup)
    message("RG Access has been removed.")
    # This program is inside the folder being deleted: let cmd remove it a moment
    # after we exit.
    subprocess.Popen(f'cmd /c ping -n 3 127.0.0.1 >nul & rmdir /s /q "{target}"', creationflags=HIDDEN)


def main():
    name = os.path.basename(sys.executable if getattr(sys, "frozen", False) else sys.argv[0])
    try:
        if "--uninstall" in sys.argv or name.lower().startswith("uninstall"):
            uninstall()
        elif "--no-update" in sys.argv:
            install()
        else:
            outcome = update()
            if outcome != "taken over":
                install(skipped=outcome == "skipped")
    except ui.Cancelled:
        pass            # the player confirmed Cancel: nothing was changed, nothing to say
    except Stop as e:
        message(str(e), MB_OK | MB_ICONWARN)
    except PermissionError as e:
        message(f"Windows refused to change a file:\n{e}\n\n"
                "Try running the setup again as administrator.", MB_OK | MB_ICONERROR)
    except Exception as e:  # show the problem rather than vanish silently
        # Where it happened too (file, line, function), so a player's report pins it down.
        import traceback
        where = " < ".join(f"{os.path.basename(f.filename)}:{f.lineno} {f.name}"
                           for f in reversed(traceback.extract_tb(e.__traceback__)))
        message(f"Setup {VERSION} failed:\n{e!r}\n\nAt: {where}\n\n"
                "Press Control+C to copy this message and send it to the mod's author.",
                MB_OK | MB_ICONERROR)


if __name__ == "__main__":
    main()
