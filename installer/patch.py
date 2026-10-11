"""The game file as a patch: only the bytes the mod changes, not the game itself.

The mod lives inside the game's own code file, RealmGrinderDesktop.swf. A release doesn't
carry that file (it is the game's, not ours); it carries the differences between the
original and the modded one, and the installer rebuilds the modded file from the player's
own copy. A SWF is zlib-compressed, where one changed byte changes everything after it, so
the differences are taken between the unpacked contents ("bodies").

A patch is a list of steps: "copy <length> bytes from <offset> of the old body" or "insert
these new bytes". make() writes one (tools/build_release.py), apply() follows one (setup).
"""
import hashlib
import struct
import zlib

BLOCK = 24      # matches shorter than this aren't looked for


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def body(swf):
    """The unpacked contents of a SWF file's bytes (after its 8-byte header)."""
    if swf[:3] == b"CWS":
        return zlib.decompress(swf[8:])
    if swf[:3] == b"FWS":
        return swf[8:]
    raise ValueError("not a SWF file this mod can read")


def pack(header, new_body):
    """A SWF file's bytes from its 8-byte header and unpacked contents."""
    return header + (zlib.compress(new_body, 9) if header[:3] == b"CWS" else new_body)


def same_run(old, new, i, j):
    """How many bytes old[i:] and new[j:] have in common from there on."""
    n, step = 0, 4096
    while old[i + n:i + n + step] == new[j + n:j + n + step] and i + n < len(old) and j + n < len(new):
        n += step
    while i + n < len(old) and j + n < len(new) and old[i + n] == new[j + n]:
        n += 1
    return n


def make(old, new):
    """The patch that turns the old body into the new one."""
    where = {old[i:i + BLOCK]: i for i in range(0, len(old) - BLOCK + 1, BLOCK)}
    steps, i, unmatched = [], 0, 0      # unmatched: where the new bytes not yet written start
    while i <= len(new) - BLOCK:
        j = where.get(new[i:i + BLOCK])
        if j is None:
            i += 1
            continue
        while i > unmatched and j > 0 and old[j - 1] == new[i - 1]:    # the match may start earlier
            i, j = i - 1, j - 1
        length = same_run(old, new, j, i)
        if i > unmatched:
            steps.append(b"I" + struct.pack("<I", i - unmatched) + new[unmatched:i])
        steps.append(b"C" + struct.pack("<II", j, length))
        i = unmatched = i + length
    if unmatched < len(new):
        steps.append(b"I" + struct.pack("<I", len(new) - unmatched) + new[unmatched:])
    return b"".join(steps)


def apply(old, patch):
    """The new body: the old one with the patch's steps followed."""
    out, at = [], 0
    while at < len(patch):
        kind = patch[at:at + 1]
        if kind == b"C":
            offset, length = struct.unpack_from("<II", patch, at + 1)
            out.append(old[offset:offset + length])
            at += 9
        elif kind == b"I":
            length, = struct.unpack_from("<I", patch, at + 1)
            out.append(patch[at + 5:at + 5 + length])
            at += 5 + length
        else:
            raise ValueError("the patch is damaged")
    return b"".join(out)
