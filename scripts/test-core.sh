#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BINARY="${TMPDIR:-/tmp}/dualtyper-core-tests"

cd "$ROOT"
swiftc -parse-as-library \
  Sources/DualTyperCore/*.swift \
  Tests/Direct/CoreTestRunner.swift \
  -o "$BINARY"
"$BINARY"
