# compare_vcd.py — regression criterion of this repository (defined 2026-07-17):
# "the testbench output must not change AT ALL".
#
# Compares two VCDs ignoring only what is not DUT behavior:
#   - the $date ... $end and $version ... $end blocks (change on every run);
#   - the testbench RTL_DIR parameter (absolute path string to the .mif files —
#     machine/clone specific; testbench configuration, not a DUT signal);
#   - the ORDER of value changes WITHIN a timestep (iverilog emits them in its
#     internal evaluation order, which shifts under neutral refactors; the SET
#     of changes per timestep is what must be identical).
# Everything else — signal definitions, timestamps and values — must be
# IDENTICAL. This text mode is the default and the one of the regression.
#
# --by-signal compares behavior instead of text, for a VCD from another
# simulator (the Verilator of AURORA): the same signals by hierarchical path,
# the same timescale, and for each signal the same value changes at the same
# instants, the value compared as a number (width, leading zeros, declaration
# order, var type and identifiers do not matter); parameters by value.
# $date, $version and RTL_DIR are ignored here too.
#
# Usage:  python compare_vcd.py [--by-signal] <new.vcd> [golden.vcd]
#         (golden default: goldens/hits_tb_golden.vcd, under this script's folder)
#         After a simulation in AURORA (it writes FST under the name .vcd):
#         fst2vcd projects/aurora/hits_tb.vcd > aurora.vcd && python verification/compare_vcd.py --by-signal aurora.vcd
# Exits with code 0 if identical, 1 if different.

import sys
from pathlib import Path

ENVIRONMENT_PARAMS = {"RTL_DIR"}


def body(path):
    """Reads the VCD dropping $date/$version and the environment parameters
    (declaration + value), and canonicalizing the order of value changes
    within each timestep."""
    lines = []
    buffer = []          # value changes of the current timestep (sorted on flush)
    skipping = False
    ignored_ids = set()

    def flush():
        lines.extend(sorted(buffer))
        buffer.clear()

    with open(path) as f:
        for line in f:
            s = line.strip()
            if s.startswith(("$date", "$version")):
                skipping = True
            if not skipping:
                parts = s.split()
                # declaration: $var parameter <bits> <id> <name> $end
                if (len(parts) >= 6 and parts[0] == "$var" and parts[1] == "parameter"
                        and parts[4] in ENVIRONMENT_PARAMS):
                    ignored_ids.add(parts[3])
                    continue
                # ignored parameter value inside $dumpvars: b<bits> <id>
                if parts and parts[0].startswith("b") and len(parts) == 2 \
                        and parts[1] in ignored_ids:
                    continue
                if s.startswith("#"):            # new timestep: close the previous one
                    flush()
                    lines.append(line)
                elif s and (s[0] in "01xzbXZB"):  # value change
                    buffer.append(line)
                else:                             # header/directives
                    flush()
                    lines.append(line)
            if skipping and s.endswith("$end"):
                skipping = False
    flush()
    return lines


def number(v):
    """A value as a number when it is all 0/1 (so width and leading zeros do
    not matter); with x or z, the lowercase text without leading zeros."""
    v = v.lower()
    if set(v) <= {"0", "1"}:
        return int(v, 2)
    return v.lstrip("0") or "0"


def signals(path):
    """Reads the VCD into (timescale, {hierarchical path: [(time, value)]}),
    keeping only the instants where the value changes. Environment parameters
    are left out; $date and $version are never read."""
    timescale, changes, ids = [], {}, {}
    scope, t, block = [], 0, None
    with open(path) as f:
        for line in f:
            parts = line.split()
            if not parts:
                continue
            if block == "$timescale":
                if parts[0] != "$end":
                    timescale.extend(p for p in parts if p != "$end")
                    if parts[-1] != "$end":
                        continue
                block = None
                continue
            if block:
                if parts[-1] == "$end":
                    block = None
                continue
            word = parts[0]
            if word == "$timescale":
                rest = [p for p in parts[1:] if p != "$end"]
                timescale.extend(rest)
                block = None if parts[-1] == "$end" else "$timescale"
            elif word in ("$date", "$version", "$comment"):
                block = None if parts[-1] == "$end" else word
            elif word == "$scope":
                scope.append(parts[2])
            elif word == "$upscope":
                scope.pop()
            elif word == "$var":
                if parts[1] == "parameter" and parts[4] in ENVIRONMENT_PARAMS:
                    continue
                name = ".".join(scope + [parts[4]])
                changes[name] = []
                ids.setdefault(parts[3], []).append(name)
            elif word[0] == "#":
                t = int(word[1:])
            elif word[0] in "bBrR" and len(parts) == 2:
                value, ident = (number(word[1:]) if word[0] in "bB" else float(word[1:])), parts[1]
                record(changes, ids.get(ident, ()), t, value)
            elif word[0] in "01xzXZ":
                record(changes, ids.get(word[1:], ()), t, number(word[0]))
    return "".join(timescale), changes


def record(changes, names, t, value):
    for name in names:
        seq = changes[name]
        if not seq or seq[-1][1] != value:
            seq.append((t, value))


def compare_by_signal(golden, new):
    ts_a, a = signals(golden)
    ts_b, b = signals(new)
    problems = []
    if ts_a != ts_b:
        problems.append(f"  timescale: golden {ts_a}, new {ts_b}")
    missing, extra = sorted(set(a) - set(b)), sorted(set(b) - set(a))
    if missing:
        problems.append(f"  signals only in the golden: {', '.join(missing)}")
    if extra:
        problems.append(f"  signals only in the new: {', '.join(extra)}")
    # the first divergence of each signal; the earliest one is reported
    first, differing = None, 0
    for name in sorted(set(a) & set(b)):
        sa, sb = a[name], b[name]
        if sa == sb:
            continue
        differing += 1
        k = next((i for i, (pa, pb) in enumerate(zip(sa, sb)) if pa != pb), min(len(sa), len(sb)))
        pa = sa[k] if k < len(sa) else None
        pb = sb[k] if k < len(sb) else None
        t = min(p[0] for p in (pa, pb) if p)
        if first is None or t < first[0]:
            first = (t, name, pa, pb)
    if not problems and first is None:
        n = sum(len(s) for s in a.values())
        print(f"OK (by-signal mode): same behavior as the golden "
              f"({len(a)} signals, {n} value changes compared)")
        return 0
    print("DIFFERENT from the golden (by-signal mode)")
    for p in problems:
        print(p)
    if first:
        t, name, pa, pb = first
        show = lambda p: f"{p[1]} from #{p[0]}" if p else "no further change"
        print(f"  {differing} signal(s) differ; the first divergence is in {name} at #{t}:")
        print(f"    golden: {show(pa)}")
        print(f"    new:    {show(pb)}")
    return 1


def is_text_vcd(path):
    with open(path, "rb") as f:
        head = f.read(64).lstrip()
    return head[:1] in (b"$", b"#")


def main():
    args = sys.argv[1:]
    by_signal = "--by-signal" in args
    args = [a for a in args if a != "--by-signal"]
    if not args:
        print("usage: python compare_vcd.py [--by-signal] <new.vcd> [golden.vcd]")
        return 2
    new = Path(args[0])
    golden = Path(args[1]) if len(args) > 1 else Path(__file__).parent / "goldens" / "hits_tb_golden.vcd"
    for p in (new, golden):
        if not is_text_vcd(p):
            print(f"{p} is not a text VCD (the Verilator of AURORA writes FST under the name .vcd): "
                  f"convert it first, fst2vcd {p} > new.vcd")
            return 2

    if by_signal:
        return compare_by_signal(golden, new)

    a, b = body(golden), body(new)
    if a == b:
        print(f"OK (text mode): identical to the golden ({len(a)} lines compared)")
        return 0

    print(f"DIFFERENT from the golden (text mode; {len(a)} vs {len(b)} lines)")
    for i, (la, lb) in enumerate(zip(a, b)):
        if la != lb:
            print(f"  first difference at line {i+1}:")
            print(f"    golden: {la.rstrip()}")
            print(f"    new:    {lb.rstrip()}")
            break
    else:
        print(f"  (one file is a prefix of the other; sizes differ)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
