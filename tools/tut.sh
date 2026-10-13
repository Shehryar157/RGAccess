#!/bin/bash
# Research helper: run remote commands, then show the dialog part of the page, dark quads and blocked presses.
S="$APPDATA/com.kongregate.mobile.realmgrinder.air/Local Store"
python tools/remote.py "$@" "wait 2" "dump tt" | grep -v -E "wait|dump"
grep -v 'tip:' "$S/rga_page_tt.txt" | head -4 | cut -c1-600
grep -E "Quad @|1Z::\+" "$S/rga_tree_tt.txt" | cut -c1-90
grep -v 'tip:' "$S/rga_page_tt.txt" | grep -E "^(Coins|Farm|Upgrades)" | cut -c1-80
