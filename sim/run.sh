#!/usr/bin/env bash
# sim/run.sh -- regenerate golden, compile and run tb_systolic_row
#
# Usage (from anywhere):
#   bash sim/run.sh [extra vvp plusargs, e.g. +vcd=sim/other.vcd]
#
# Exit code: 0 = ALL PASS; non-zero = golden/compile failure, test FAIL,
# or simulation timeout (passed through from vvp / $fatal).

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

# oss-cad-suite: vvp/yosys segfault or fail to start without lib/ on PATH
OSS_CAD="${OSS_CAD:-/c/oss-cad-suite}"
if [ -d "$OSS_CAD/bin" ]; then
    export PATH="$OSS_CAD/bin:$OSS_CAD/lib:$PATH"
fi

PY="${PYTHON:-python3}"
VVP_OUT="sim/tb_systolic_row.vvp"

echo "== [1/3] golden =="
"$PY" -I golden/gen_golden.py || { echo "run.sh: golden generation failed"; exit 2; }

echo "== [2/3] compile =="
iverilog -g2005 -Wall -I golden -o "$VVP_OUT" \
    rtl/mac_pe.v rtl/systolic_row.v tb/tb_systolic_row.v \
    || { echo "run.sh: compile failed"; exit 3; }

echo "== [3/3] simulate =="
vvp -n "$VVP_OUT" "$@"
rc=$?

if [ $rc -eq 0 ]; then
    echo "run.sh: PASS (exit 0)"
else
    echo "run.sh: FAIL (vvp exit $rc)"
fi
exit $rc
