#!/usr/bin/env python3
"""pngdiff — детектор **near-duplicate** скриншотов без внешних зависимостей.

Зачем: гейт уникальности по md5 пропускал почти одинаковые кадры (независимый
аудит: SC-5 отличался от SC-1 на 0.006 % пикселей, но md5 разный). Здесь мы
сравниваем РАЗМЕР и разреженную подпись распакованного потока PNG (zlib) —
при минимальных отличиях картинок подпись совпадает ⇒ near-duplicate.

Только stdlib (struct+zlib): контейнер ORC без PIL/ImageMagick.

Использование:  python3 pngdiff.py [--thresh 0.005] file1.png file2.png ...
Код возврата 1, если найдена пара near-duplicate.
"""
import argparse
import struct
import sys
import zlib


def _sig(path, samples=4096):
    """Размеры + разреженная подпись распакованного IDAT (быстро, без фильтров)."""
    data = open(path, "rb").read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    pos, idat = 8, b""
    w = h = None
    while pos + 8 <= len(data):
        ln = struct.unpack(">I", data[pos:pos + 4])[0]
        typ = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + ln]
        pos += 12 + ln
        if typ == b"IHDR":
            w, h = struct.unpack(">II", chunk[:8])
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
    try:
        raw = zlib.decompress(idat)
    except Exception:
        return (w, h, 0, b"")
    step = max(1, len(raw) // samples)
    sig = raw[::step]
    return (w, h, len(raw), sig)


def _diff_frac(a, b):
    if a[0] != b[0] or a[1] != b[1] or a[2] != b[2]:
        return 1.0  # разные размеры/распакованный объём ⇒ не near-dup
    n = min(len(a[3]), len(b[3]))
    if n == 0:
        return 1.0
    d = sum(1 for i in range(n) if a[3][i] != b[3][i])
    return d / n


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--thresh", type=float, default=0.005,
                    help="доля различающихся сэмплов ниже которой кадры считаются near-duplicate (default 0.005)")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args(argv)
    sigs = [(f, _sig(f)) for f in a.files]
    bad = 0
    for i in range(len(sigs)):
        for j in range(i + 1, len(sigs)):
            fi, si = sigs[i]
            fj, sj = sigs[j]
            if si is None or sj is None:
                continue
            fr = _diff_frac(si, sj)
            if fr < a.thresh:
                print(f"near-duplicate: {fi.split('/')[-1]} ≈ {fj.split('/')[-1]} (diff={fr*100:.3f}% < {a.thresh*100:.1f}%)")
                bad += 1
    if bad:
        return 1
    print(f"pngdiff: OK — {len(sigs)} скриншотов, near-duplicate не найдено")
    return 0


if __name__ == "__main__":
    sys.exit(main())
