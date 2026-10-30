#!/bin/sh
# build.sh -- builds the SAPHO of hits_menu.cpp with YANC and puts the processor, its
# memories and the blocks of SAPHO it needs (sapho/) in projects/de2_115_sapho/, where the
# simulation and the board project read them.
#
#   YANC=/path/to/yanc sh build.sh
#
# YANC is a clone of github.com/nipscernlab/yanc with its compilers built (Scripts/regress.sh
# leaves them in .smoke/bin); default c:/nipscern/yanc. The files written are generated:
# change hits_menu.cpp and build again, never edit them by hand.
#
# Refuses a clone of YANC with uncommitted changes (hits_menu.yanc could not say what
# built the files), and fails when YANC did not size the stacks of SAPHO from the
# program: its fallback, 128 words each, makes SAPHO several times bigger (yanc#54).
set -e
YANC=${YANC:-c:/nipscern/yanc}
BIN="$YANC/.smoke/bin"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/.."
if [ -n "$(git -C "$YANC" status --porcelain --untracked-files=no)" ]; then
    echo "build.sh: $YANC has uncommitted changes; commit or clean them first" >&2
    exit 1
fi
TMP="$(mktemp -d)"
"$BIN/cppcomp.exe" -o "$TMP/hits_menu" "$HERE/hits_menu.cpp"
"$BIN/asmcomp.exe" -f 40 -c 1000 "$TMP/hits_menu/hits_menu.asm" | tee "$TMP/asmcomp.log"
if ! grep -q "stack depths from the program" "$TMP/asmcomp.log"; then
    echo "build.sh: YANC did not size the stacks from the program (yanc#54); nothing written" >&2
    rm -rf "$TMP"
    exit 1
fi
for f in hits_menu.v hits_menu_data.mif hits_menu_inst.mif pc_hits_menu_mem.txt; do
    cp "$TMP/hits_menu/$f" "$OUT/$f"
done
mkdir -p "$OUT/sapho"
for f in addr_dec instr_dec processor core ula myKeyPS2 myVGAText; do
    cp "$YANC/SAPHO/$f.v" "$OUT/sapho/$f.v"
done
echo "yanc $(git -C "$YANC" log -1 --format='%h %cs')" > "$OUT/hits_menu.yanc"
rm -rf "$TMP"
echo "built: hits_menu.v, its memories and sapho/, with $(cat "$OUT/hits_menu.yanc")"
