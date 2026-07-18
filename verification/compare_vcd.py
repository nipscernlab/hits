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
# IDENTICAL.
#
# Usage:  python compare_vcd.py <new.vcd> [golden.vcd]
#         (golden default: sim_pulsos_tb_golden.vcd next to this script)
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


def main():
    if len(sys.argv) < 2:
        print(__doc__ or "usage: python compare_vcd.py <new.vcd> [golden.vcd]")
        return 2
    new = Path(sys.argv[1])
    golden = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).parent / "sim_pulsos_tb_golden.vcd"

    a, b = body(golden), body(new)
    if a == b:
        print(f"OK: identical to the golden ({len(a)} lines compared)")
        return 0

    print(f"DIFFERENT from the golden ({len(a)} vs {len(b)} lines)")
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
