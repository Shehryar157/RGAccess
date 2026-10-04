"""RGAccess speech helper.

The patched game starts this script (with pythonw, so no window appears) and
writes one command per line to our standard input:

    S <text>   speak now, interrupting whatever is being said
    Q <text>   speak after the current speech (queue)
    X          silence speech

Speech goes through Tolk, which talks to NVDA, JAWS or SAPI.
Every command is also written to rga_speech.log next to this file.
"""
import ctypes
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LOG = open(os.path.join(HERE, "rga_speech.log"), "w", encoding="utf-8", buffering=1)


def log(msg):
    LOG.write(msg + "\n")


def load_tolk():
    # Load the screen reader client DLLs by full path first, so Tolk finds them.
    for name in ("nvdaControllerClient64.dll", "SAAPI64.dll"):
        try:
            ctypes.WinDLL(os.path.join(HERE, name))
        except OSError as e:
            log(f"could not load {name}: {e}")
    tolk = ctypes.WinDLL(os.path.join(HERE, "Tolk.dll"))
    tolk.Tolk_Output.argtypes = [ctypes.c_wchar_p, ctypes.c_bool]
    tolk.Tolk_Speak.argtypes = [ctypes.c_wchar_p, ctypes.c_bool]
    tolk.Tolk_DetectScreenReader.restype = ctypes.c_wchar_p
    tolk.Tolk_TrySAPI(True)
    tolk.Tolk_Load()
    log(f"screen reader: {tolk.Tolk_DetectScreenReader()}")
    return tolk


def main():
    tolk = load_tolk()
    # The game sends UTF-8 text; read raw bytes so Windows' code page can't garble it.
    for raw in sys.stdin.buffer:
        line = raw.decode("utf-8", "replace").rstrip("\r\n")
        if not line:
            continue
        cmd, _, text = line.partition(" ")
        log(line)
        if cmd == "S":
            tolk.Tolk_Output(text, True)
        elif cmd == "Q":
            tolk.Tolk_Output(text, False)
        elif cmd == "X":
            tolk.Tolk_Silence()
    # stdin closed: the game has exited.
    tolk.Tolk_Unload()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # log crashes; there's no window to show them in
        log(f"CRASH: {e!r}")
