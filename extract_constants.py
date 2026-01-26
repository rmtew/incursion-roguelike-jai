#!/usr/bin/env python3
"""Extract constants from Defines.h and generate Jai constants file."""

import re
import sys

def parse_defines(filepath):
    """Parse #define statements and return list of (name, value) tuples."""
    constants = []
    known = {}  # For resolving references

    with open(filepath, 'r') as f:
        for line in f:
            # Skip lines that don't start with #define
            if not line.startswith('#define'):
                continue

            # Parse: #define NAME VALUE
            match = re.match(r'#define\s+([A-Z][A-Z_0-9]+)\s+(-?\d+|0x[0-9a-fA-F]+)', line)
            if match:
                name = match.group(1)
                value_str = match.group(2)

                # Parse value
                if value_str.startswith('0x') or value_str.startswith('0X'):
                    value = int(value_str, 16)
                else:
                    value = int(value_str.rstrip('LlUu'))

                constants.append((name, value))
                known[name] = value

    # Sort by name for binary search
    constants.sort(key=lambda x: x[0])
    return constants

def generate_jai(constants, outpath):
    """Generate Jai constants file."""
    with open(outpath, 'w') as f:
        f.write("// Incursion Port - Resource Constants\n")
        f.write("// Auto-generated from Defines.h\n")
        f.write("// {} constants\n\n".format(len(constants)))

        # Generate sorted arrays for binary search
        f.write("CONSTANT_NAMES :: string.[\n")
        for i, (name, value) in enumerate(constants):
            comma = "," if i < len(constants) - 1 else ""
            f.write('    "{}"{}\n'.format(name, comma))
        f.write("];\n\n")

        f.write("CONSTANT_VALUES :: s64.[\n")
        for i, (name, value) in enumerate(constants):
            comma = "," if i < len(constants) - 1 else ""
            # Handle large values that might overflow
            if value > 0x7FFFFFFFFFFFFFFF:
                value = value - 0x10000000000000000
            f.write("    {}{}\n".format(value, comma))
        f.write("];\n\n")

        # Binary search lookup function
        f.write("""// Binary search lookup
lookup_resource_constant :: (name: string) -> s64, bool {
    lo := 0;
    hi := CONSTANT_NAMES.count - 1;

    while lo <= hi {
        mid := (lo + hi) / 2;
        cmp := compare_strings(name, CONSTANT_NAMES[mid]);
        if cmp == 0 {
            return CONSTANT_VALUES[mid], true;
        } else if cmp < 0 {
            hi = mid - 1;
        } else {
            lo = mid + 1;
        }
    }

    return 0, false;
}

compare_strings :: (a: string, b: string) -> s32 {
    len := min(a.count, b.count);
    for i: 0..len-1 {
        if a[i] < b[i] return -1;
        if a[i] > b[i] return 1;
    }
    if a.count < b.count return -1;
    if a.count > b.count return 1;
    return 0;
}
""")

if __name__ == '__main__':
    defines_path = r"C:\Data\R\roguelike - incursion\repo-work\inc\Defines.h"
    output_path = r"C:\Data\R\git\jai\incursion-port\src\resource\constants.jai"

    constants = parse_defines(defines_path)
    print(f"Found {len(constants)} constants")
    generate_jai(constants, output_path)
    print(f"Generated {output_path}")
