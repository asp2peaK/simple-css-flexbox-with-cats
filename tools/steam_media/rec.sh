#!/bin/bash
S=/tmp/claude-0/-home-claude/0fa7620d-6560-519d-8fd8-414cd7d66eea/scratchpad
n=$1; len=$2; shift 2
d=$S/clips/${TAG:-$n}; rm -rf $d; mkdir -p $d
cd /home/claude/pickup
timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot3 --path . --resolution 1280x720 --fixed-fps 30 res://main.tscn --showcase=$n --rec=$d --len=$len "$@" > $d.log 2>&1
echo "$n: $(ls $d | wc -l) frames; $(grep -c 'SCRIPT ERROR' $d.log) errors"
