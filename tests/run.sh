#!/bin/bash
# Run the test bots:  tests/run.sh [name ...]      (no names: all of them, quickest first)
#   name = the part after test_, e.g.  tests/run.sh wood_oven look_stick
# Each bot plays the real game on a virtual screen. Its log and screenshots go to tests/out/<name>/.
# A bot passes when it exits 0, prints PASS, and the log has no script errors or engine errors from our code.
# GODOT=<path> picks the Godot 4.3 binary (default: godot on the PATH); T=<seconds> is the time limit per bot.
cd "$(dirname "$0")/.." || exit 2
GODOT=${GODOT:-godot}
ORDER="stores kitbox wood_oven traps boxes look_stick clock sound senior_training day day_2d day_wood first_week"
names=("$@")
if [ ${#names[@]} -eq 0 ]; then
	names=($ORDER)
	for f in tests/test_*.gd; do      # any test not in the list above runs last
		n=$(basename "$f" .gd); n=${n#test_}
		[[ " $ORDER " == *" $n "* ]] || names+=("$n")
	done
fi
fail=0
for n in "${names[@]}"; do
	f=tests/test_$n.gd
	if [ ! -f "$f" ]; then echo "FAIL  $n: no such test ($f)"; fail=1; continue; fi
	dir=tests/out/$n
	rm -rf "$dir"; mkdir -p "$dir"
	start=$(date +%s)
	timeout "${T:-1200}" xvfb-run -a "$GODOT" --path . --audio-driver Dummy --rendering-driver opengl3 \
		--resolution 1280x720 -s "$f" -- "$PWD/$dir" > "$dir/log.txt" 2>&1
	code=$?
	secs=$(( $(date +%s) - start ))
	# engine errors at exit (leaks, unfreed shaders) are Godot's own noise when a script quits; anything else counts
	bad=$(grep -E "SCRIPT ERROR|^ERROR:" "$dir/log.txt" | grep -v -E "at exit|never freed|leaked" | head -6)
	if [ $code -eq 0 ] && grep -q "^PASS" "$dir/log.txt" && [ -z "$bad" ]; then
		printf "pass  %-16s %4ss  %s\n" "$n" "$secs" "$(grep '^PASS' "$dir/log.txt")"
	else
		fail=1
		why="exit $code"; [ $code -eq 124 ] && why="timed out after ${T:-1200}s"
		printf "FAIL  %-16s %4ss  (%s)  log: %s\n" "$n" "$secs" "$why" "$dir/log.txt"
		{ grep -E "^  FAIL" "$dir/log.txt"; echo "$bad"; } | grep -v '^$' | head -10 | sed 's/^ */      /'
	fi
done
exit $fail
