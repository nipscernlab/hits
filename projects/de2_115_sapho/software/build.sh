#!/bin/sh
# build.sh -- builds the SAPHO of hits_menu.cpp with YANC and puts the processor and its
# memories in projects/de2_115_sapho/, where the simulation and the board project read them.
#
#   YANC=/path/to/yanc sh build.sh
#
# YANC is a clone of github.com/nipscernlab/yanc with its compilers built (Scripts/regress.sh
# leaves them in .smoke/bin); default c:/nipscern/yanc. The files written are generated:
# change hits_menu.cpp and build again, never edit them by hand.
set -e
YANC=${YANC:-c:/nipscern/yanc}
BIN="$YANC/.smoke/bin"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/.."
TMP="$(mktemp -d)"
"$BIN/cppcomp.exe" -o "$TMP/hits_menu" "$HERE/hits_menu.cpp"
"$BIN/asmcomp.exe" -f 40 -c 1000 "$TMP/hits_menu/hits_menu.asm"
for f in hits_menu.v hits_menu_data.mif hits_menu_inst.mif pc_hits_menu_mem.txt; do
    cp "$TMP/hits_menu/$f" "$OUT/$f"
done
echo "yanc $(git -C "$YANC" log -1 --format='%h %cs')" > "$OUT/hits_menu.yanc"
rm -rf "$TMP"
echo "built: hits_menu.v and its memories, with $(cat "$OUT/hits_menu.yanc")"
