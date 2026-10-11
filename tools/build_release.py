"""Build the release: the installer a GitHub release carries.

  python tools/build_release.py

1. The mod is compiled into a copy of the original game file (tools/build.py), without
   this computer's Python path in it.
2. The differences between the original and that modded file are worked out
   (installer/patch.py) and checked by rebuilding the modded file from them.
3. PyInstaller turns the speech helper into build/release/RGAccess/rga_speech.exe (Python
   included, so players don't need Python); the speech DLLs go next to it.
4. That folder and the differences are zipped and packed into the installer,
   installer/setup.py, which PyInstaller turns into dist/RGAccess-Setup.exe.

The version comes from the VERSION file. Releasing: raise it, build, then publish
dist/RGAccess-Setup.exe on a GitHub release tagged v<version>; the release's description
is the "what's new" the installer shows.
"""
import json
import os
import shutil
import subprocess
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "installer"))
import build  # noqa: E402     tools/build.py
import patch  # noqa: E402     installer/patch.py

BUILD = os.path.join(ROOT, "build", "release")
APP = os.path.join(BUILD, "RGAccess")
DIST = os.path.join(ROOT, "dist")
SEP = os.pathsep
# Parts of Python neither program uses, left out to keep the download small: web
# encryption (the installer downloads with Windows' own code), windowing toolkits, tests.
UNUSED = ["ssl", "_ssl", "tkinter", "_tkinter", "unittest", "pydoc", "doctest", "bz2", "_bz2",
          "http", "xml", "html", "numpy", "PIL", "pygame"]
SKIP = [a for name in UNUSED for a in ("--exclude-module", name)]


def pyinstaller(*args):
    subprocess.run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean",
                    "--workpath", os.path.join(BUILD, "work"),
                    "--specpath", os.path.join(BUILD, "spec"), *args], check=True, cwd=ROOT)


def build_patch():
    """The differences (swf.delta) and what the installer checks them against (swf.json)."""
    with open(build.compile_swf(build.bundle(release=True)), "rb") as f:
        modded = f.read()
    with open(build.ORIGINAL, "rb") as f:
        original = f.read()
    old, new = patch.body(original), patch.body(modded)
    delta = patch.make(old, new)
    if patch.apply(old, delta) != new:
        sys.exit("The patch doesn't rebuild the modded file.")
    folder = os.path.join(BUILD, "patch")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, "swf.delta"), "wb") as f:
        f.write(delta)
    with open(os.path.join(folder, "swf.json"), "w", encoding="utf-8") as f:
        json.dump({"original_sha256": patch.sha256(original), "patched_body_sha256": patch.sha256(new),
                   "header": modded[:8].hex()}, f)
    print(f"patch: {len(delta):,} bytes for a game file of {len(new):,}")
    return folder


def build_helper():
    shutil.rmtree(APP, ignore_errors=True)
    pyinstaller("--name", "rga_speech", "--noconsole", "--onedir", "--distpath", BUILD, *SKIP,
                os.path.join(ROOT, "src", "helper", "rga_speech.py"))
    os.rename(os.path.join(BUILD, "rga_speech"), APP)
    for dll in os.listdir(build.NATIVE):
        shutil.copy2(os.path.join(build.NATIVE, dll), APP)


def build_installer(patch_folder):
    payload = os.path.join(BUILD, "payload.zip")
    # LZMA (the 7-Zip method) packs program files about a third smaller than plain zip.
    with zipfile.ZipFile(payload, "w", zipfile.ZIP_LZMA) as z:
        for folder, _, files in os.walk(APP):
            for name in files:
                full = os.path.join(folder, name)
                z.write(full, os.path.relpath(full, APP))
        for name in os.listdir(patch_folder):
            z.write(os.path.join(patch_folder, name), "_patch/" + name)
    installer = os.path.join(ROOT, "installer")
    pyinstaller("--name", "RGAccess-Setup", "--onefile", "--noconsole", *SKIP,
                "--distpath", DIST, "--paths", installer, "--add-data", f"{payload}{SEP}.",
                "--add-data", f"{os.path.join(ROOT, 'VERSION')}{SEP}.",
                os.path.join(installer, "setup.py"))
    print("built", os.path.join(DIST, "RGAccess-Setup.exe"), "version", build.VERSION)


if __name__ == "__main__":
    made = build_patch()
    build_helper()
    build_installer(made)
