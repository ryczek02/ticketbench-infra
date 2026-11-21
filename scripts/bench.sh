#!/usr/bin/env bash
# One script for the whole benchmark: start the stack, run the matrix,
# generate tables and plots, and build the PDF when the report repo is next to us.
#
#   scripts/bench.sh                 # full matrix (config/matrix.yaml)
#   scripts/bench.sh config/smoke.yaml
#   DEV=1 scripts/bench.sh           # build images from ../services and ../cli
set -euo pipefail
cd "$(dirname "$0")/.."

config=${1:-config/matrix.yaml}
run=${RUN:-$(date -u +%Y%m%d-%H%M%S)}
out=results/$run
compose=(docker compose -f docker-compose.yml)
[[ -n "${DEV:-}" ]] && compose+=(-f docker-compose.dev.yml)

echo "== starting the stack"
if [[ -n "${DEV:-}" ]]; then "${compose[@]}" build; else "${compose[@]}" pull --quiet; fi
"${compose[@]}" up -d --wait --wait-timeout 300

if command -v tbench >/dev/null; then
  tb=(tbench --runner "localhost:${TB_RUNNER_PORT:-7070}")
  export OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4317} OTEL_EXPORTER_OTLP_INSECURE=true
else
  export TB_UID=$(id -u) TB_GID=$(id -g)
  tb=("${compose[@]}" run --rm tbench)
fi

echo "== stores"
"${tb[@]}" ping

echo "== matrix $config -> $out"
"${tb[@]}" plan --config "$config" | tail -1
"${tb[@]}" matrix --config "$config" --out "$out"

echo "== report"
"${tb[@]}" report "$out" --out "$out/report"
if [[ -d ../report ]]; then
  rm -rf ../report/generated ../report/data/results
  cp -R "$out/report" ../report/generated
  mkdir -p ../report/data && cp -R "$out" ../report/data/results
  if command -v tectonic >/dev/null; then
    (cd ../report && tectonic -X compile sprawozdanie.tex)
    echo "PDF: ../report/sprawozdanie.pdf"
  fi
fi
echo "== done: $out (Jaeger http://localhost:16686, Grafana http://localhost:3000)"
