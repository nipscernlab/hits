"""Compares a Signal Tap capture of the board with the ARM against the simulation,
sample by sample (README of this project, Step 12).

Usage, from this folder (tools/):
    python compare_capture.py capture.csv [reference.csv]

The capture is a .csv exported from Signal Tap with the columns shaper_clip and
rst_sync[1] (the reset of the top), in Unsigned Decimal; event_bt and bt_mask_out
are compared too when they are in it. The reference (default board_reference.csv,
next to this script) is the simulation of the same circuit with occupancy 64 and
pedestal 146, written by board_reference.v.

The script finds the sample where rst_sync[1] falls from 1 to 0, tries the
alignments -4 to +4 (the board and the simulation may differ by a sample or two
only in where each one reads the signal), and requires EVERY sample after it to be
equal. Exit code 0 if equal, 1 if different, 2 if the file cannot be read.
"""
import csv
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SHIFTS = range(-4, 5)
WINDOW = 200
COLUMNS = ("shaper_clip", "event_bt", "bt_mask_out")


def read_capture(path):
    rows = list(csv.reader(open(path, encoding="utf-8", errors="replace")))
    head = None
    for i, r in enumerate(rows):
        if any("shaper_clip" in c.lower() for c in r) and i + 1 < len(rows):
            nxt = rows[i + 1]
            if nxt and nxt[0].strip().lstrip("-").isdigit():
                head = i
                break
    if head is None:
        print(f"{path}: no header with shaper_clip followed by data. Send the first 20 lines of the file.")
        sys.exit(2)
    names = [c.strip().lower() for c in rows[head]]
    col = {}
    for want in COLUMNS:
        for i, c in enumerate(names):
            if c.endswith(want) or f"|{want}" in c or c == want:
                col[want] = i
                break
    rst = next((i for i, c in enumerate(names) if "rst" in c), None)
    if "shaper_clip" not in col or rst is None:
        print(f"{path}: the capture needs the columns shaper_clip and rst_sync[1]; it has {names}")
        sys.exit(2)
    data = {k: [] for k in col}
    rsts, last = [], None
    for r in rows[head + 1:]:
        if len(r) <= max(list(col.values()) + [rst]) or not r[col["shaper_clip"]].strip():
            continue
        if r == last:                         # Signal Tap may repeat the last line
            continue
        last = r
        vals = [r[i].strip().strip('"').upper() for i in list(col.values()) + [rst]]
        if "X" in vals:                       # unknown value in the first sample
            continue
        for k, v in zip(col, vals):
            data[k].append(int(v))
        rsts.append(int(vals[-1]))
    return data, rsts


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    cap, rst = read_capture(sys.argv[1])
    refpath = Path(sys.argv[2]) if len(sys.argv) > 2 else HERE / "board_reference.csv"
    ref = {k: [] for k in COLUMNS}
    with open(refpath) as f:
        for r in csv.DictReader(f):
            for k in COLUMNS:
                ref[k].append(int(r[k]))
    falls = [i for i in range(len(rst) - 1) if rst[i] == 1 and rst[i + 1] == 0]
    if not falls:
        print("rst_sync[1] does not fall from 1 to 0 in the capture: trigger on its falling edge, "
              "with the trigger near the start of the window, and press and release KEY0.")
        sys.exit(1)
    start = falls[0] + 1
    clip = cap["shaper_clip"][start:]
    best = min(SHIFTS, key=lambda d: sum(a != b for a, b in
               zip(clip[max(0, d):][:WINDOW], ref["shaper_clip"][max(0, -d):][:WINDOW])))
    ok = True
    for k in cap:
        a = cap[k][start:][max(0, best):]
        b = ref[k][max(0, -best):]
        n = min(len(a), len(b))
        diff = [i for i in range(n) if a[i] != b[i]]
        print(f"{k}: {n} samples after the reset compared (alignment {best:+d}), {len(diff)} different")
        if diff:
            i = diff[0]
            print(f"  first difference at sample {i} after the reset: board {a[i]}, simulation {b[i]}")
            ok = False
    print("EQUAL to the simulation, sample by sample." if ok else "DIFFERENT from the simulation.")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
