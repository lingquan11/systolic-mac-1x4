#!/usr/bin/env bash
# synth/run_synth.sh -- yosys generic synthesis of systolic_row + report
#
# Usage (from anywhere):  bash synth/run_synth.sh
# Outputs: synth/synth_report.txt (report), synth/out/ (log, stat, netlists)
# Exit code: 0 = synthesized, no latches, no combinational loops.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# oss-cad-suite: yosys fails to start without lib/ on PATH
OSS_CAD="${OSS_CAD:-/c/oss-cad-suite}"
if [ -d "$OSS_CAD/bin" ]; then
    export PATH="$OSS_CAD/bin:$OSS_CAD/lib:$PATH"
fi
PY="${PYTHON:-python3}"

mkdir -p synth/out

echo "== [1/2] yosys =="
yosys -q -l synth/out/yosys.log -s synth/synth.ys \
    || { echo "run_synth.sh: yosys failed (see synth/out/yosys.log)"; exit 2; }

echo "== [2/2] report =="
"$PY" -I synth/make_report.py
rc=$?
if [ $rc -eq 0 ]; then
    echo "run_synth.sh: PASS (no latches, no combinational loops)"
else
    echo "run_synth.sh: FAIL (see synth/synth_report.txt)"
fi
exit $rc
