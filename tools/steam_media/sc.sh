#!/bin/bash
# sc.sh name args...  -> store/name.png
S=/tmp/claude-0/-home-claude/0fa7620d-6560-519d-8fd8-414cd7d66eea/scratchpad
n=$1; shift
cd /home/claude/pickup
timeout 90 xvfb-run -a -s "-screen 0 1920x1080x24" godot3 --path . --resolution 1920x1080 res://main.tscn --showcase=$n --still=$S/${OUT:-store}/$n.png --len=4 "$@" > $S/${OUT:-store}/$n.log 2>&1
grep -h "SCRIPT ERROR\|^still" $S/${OUT:-store}/$n.log | head -5
