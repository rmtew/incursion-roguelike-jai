#!/bin/bash
# Attach to a running/hung process, dump all thread stacks, and detach.
# Usage:
#   ./attach-dump.sh <exe-name-or-pid>
#
# If given a name (e.g., "stress_test.exe"), finds the PID automatically.
# Creates a minidump of the live process, then detaches (process continues).

set -euo pipefail

TARGET="${1:?Usage: attach-dump.sh <exe-name-or-pid>}"

# Resolve PID if given a name
if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
    PID="$TARGET"
else
    PID=$(tasklist //FI "IMAGENAME eq $TARGET" //FO CSV //NH 2>/dev/null \
        | head -1 | cut -d'"' -f4)
    if [[ -z "$PID" || "$PID" == "INFO:" ]]; then
        echo "ERROR: No process found matching: $TARGET" >&2
        exit 1
    fi
    echo "Found $TARGET with PID $PID"
fi

# Resolve cdb from WinDbg MSIX package
CDB_DIR=$(powershell -NoProfile -Command "(Get-AppxPackage *WinDbg*).InstallLocation" | tr -d '\r')
CDB="$CDB_DIR/amd64/cdb.exe"

if [[ ! -f "$CDB" ]]; then
    echo "ERROR: cdb.exe not found at: $CDB" >&2
    exit 1
fi

# Build command script
SCRIPT=$(mktemp /tmp/cdb-attach-XXXXXX.txt)
trap 'rm -f "$SCRIPT"' EXIT

DUMP_PATH="C:/Data/R/git/incursion-port-jai/crash-dumps/hang-$(date +%Y%m%d-%H%M%S).dmp"
mkdir -p "C:/Data/R/git/incursion-port-jai/crash-dumps"

cat > "$SCRIPT" <<EOF
~*kb
.dump /ma $DUMP_PATH
.detach
q
EOF

echo "Attaching to PID $PID..."
echo "Dump will be saved to: $DUMP_PATH"
"$CDB" -sins -p "$PID" -cf "$SCRIPT" 2>&1 | grep -v NatVis
echo ""
echo "Process detached (still running). Dump: $DUMP_PATH"
