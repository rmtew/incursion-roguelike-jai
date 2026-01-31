#!/bin/bash
# Analyze a minidump with cdb. Usage:
#   ./analyze-dump.sh <dump-file> [pdb-directory]
#
# Resolves cdb path dynamically (MSIX package, version changes on update).
# Uses Microsoft symbol server with local cache at C:\symbols.

set -euo pipefail

DUMP="${1:?Usage: analyze-dump.sh <dump-file> [pdb-dir]}"
PDB_DIR="${2:-$(dirname "$DUMP")}"

# Resolve cdb from WinDbg MSIX package
CDB_DIR=$(powershell -NoProfile -Command "(Get-AppxPackage *WinDbg*).InstallLocation" | tr -d '\r')
CDB="$CDB_DIR/amd64/cdb.exe"

if [[ ! -f "$CDB" ]]; then
    echo "ERROR: cdb.exe not found at: $CDB" >&2
    echo "Install with: winget install Microsoft.WinDbg" >&2
    exit 1
fi

if [[ ! -f "$DUMP" ]]; then
    echo "ERROR: dump file not found: $DUMP" >&2
    exit 1
fi

# Build cdb command script in a temp file
SCRIPT=$(mktemp /tmp/cdb-analyze-XXXXXX.txt)
trap 'rm -f "$SCRIPT"' EXIT

# Convert PDB_DIR to Windows path for cdb
PDB_DIR_WIN=$(cygpath -w "$PDB_DIR" 2>/dev/null || echo "$PDB_DIR")

cat > "$SCRIPT" <<EOF
.sympath srv*C:\\symbols*https://msdl.microsoft.com/download/symbols;$PDB_DIR_WIN
.reload
!analyze -v
.ecxr
kb
q
EOF

"$CDB" -sins -z "$DUMP" -cf "$SCRIPT" 2>&1 | grep -v NatVis
