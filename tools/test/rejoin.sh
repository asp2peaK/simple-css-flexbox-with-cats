#!/bin/sh
# кооп: гость вылетает и заходит снова в идущую смену
G=${G:-/tmp/gs/Godot_v3.6.2-stable_x11.64}
export SHOT_DIR=${SHOT_DIR:-/tmp/rj}
mkdir -p "$SHOT_DIR"
(timeout 70 xvfb-run -a $G --path . --nethost --rejointest > "$SHOT_DIR/h.log" 2>&1 &)
sleep 3
timeout 14 xvfb-run -a $G --path . --netjoin=127.0.0.1 --rejointest > "$SHOT_DIR/c1.log" 2>&1
sleep 8
timeout 25 xvfb-run -a $G --path . --netjoin=127.0.0.1 --rejointest > "$SHOT_DIR/c2.log" 2>&1
sleep 25
grep -h -E "HOST|CLIENT" "$SHOT_DIR"/*.log
