"""Build RGAccess: bundle our code into Main.as, compile it into the game with JPEXS, deploy.

    python tools/build.py            build and install into the game
    python tools/build.py --restore  put the original game file back
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = r"D:\Steam\steamapps\common\Realm Grinder"
ORIGINAL = os.path.join(ROOT, "original", "RealmGrinderDesktop.swf")
JAVA = os.path.join(ROOT, "tools", "jdk-21.0.12.1+1-jre", "bin", "java.exe")
FFDEC = os.path.join(ROOT, "tools", "ffdec", "ffdec-cli.jar")
FFC_NATIVE = r"E:\code\mods\FFCAccess\native"
BUILD = os.path.join(ROOT, "build")
PYTHONW = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")


def bundle(only=None):
    """Main.as + generated config + every src/mod/*.as, with their imports hoisted together.
    only: optional list of src/mod file names (without .as) to include, for smoke tests."""
    main = open(os.path.join(ROOT, "src", "scripts", "Main.as"), encoding="utf-8").read()
    imports, bodies = [], []
    config = 'class RGAConfig\n{\n   public static const PYTHONW:String = "%s";\n}\n' % PYTHONW.replace("\\", "\\\\")
    bodies.append(config)
    mod_dir = os.path.join(ROOT, "src", "mod")
    for name in sorted(os.listdir(mod_dir)):
        if name.endswith(".as") and (only is None or name[:-3] in only):
            text = open(os.path.join(mod_dir, name), encoding="utf-8").read()
            for line in text.splitlines():
                if re.match(r"\s*import\s", line):
                    if line.strip() not in imports:
                        imports.append(line.strip())
            bodies.append(re.sub(r"(?m)^\s*import\s.*\n", "", text))
    out = main.rstrip() + "\n\n" + "\n".join(imports) + "\n\n" + "\n".join(bodies)
    os.makedirs(BUILD, exist_ok=True)
    path = os.path.join(BUILD, "Main.as")
    open(path, "w", encoding="utf-8").write(out)
    return path


def compile_swf(main_as):
    out_swf = os.path.join(BUILD, "RealmGrinderDesktop.swf")
    if os.path.exists(out_swf):
        os.remove(out_swf)
    result = subprocess.run([JAVA, "-jar", FFDEC, "-replace", ORIGINAL, out_swf, "Main", main_as],
                            capture_output=True, text=True)
    output = re.sub(r"\x1b\[[0-9;]*m", "", result.stdout + result.stderr)
    errors = [l for l in output.splitlines() if "SEVERE" in l or "rror" in l]
    if errors or not os.path.exists(out_swf):
        print("Compile FAILED:")
        print("\n".join(errors or output.splitlines()[-10:]))
        sys.exit(1)
    return out_swf


def deploy(swf):
    shutil.copy2(swf, os.path.join(GAME, "RealmGrinderDesktop.swf"))
    helper = os.path.join(GAME, "RGAccess")
    os.makedirs(helper, exist_ok=True)
    shutil.copy2(os.path.join(ROOT, "src", "helper", "rga_speech.py"), helper)
    for dll in ("Tolk.dll", "nvdaControllerClient64.dll", "SAAPI64.dll"):
        shutil.copy2(os.path.join(FFC_NATIVE, dll), helper)
    print("Built and installed into the game.")


if __name__ == "__main__":
    if "--restore" in sys.argv:
        shutil.copy2(ORIGINAL, os.path.join(GAME, "RealmGrinderDesktop.swf"))
        print("Original game file restored.")
    else:
        deploy(compile_swf(bundle()))
