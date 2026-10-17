#!/usr/bin/env python3
import sys


def convert_taps_line(input_file, output_file, scale=32768):
    """
    Convert a single-line 'taps = ...' file into a Vivado .coe file
    with 16-bit signed integer coefficients (Q1.15 format).
    """
    with open(input_file, "r") as f:
        line = f.read().strip()

    # Remove optional "taps =" prefix
    if line.startswith("taps"):
        line = line.split("=", 1)[1].strip()

    # Split by commas
    coeffs_str = line.split(",")
    coeffs_fixed = []

    for s in coeffs_str:
        s = s.strip()
        if not s:
            continue
        try:
            val = float(s)
        except ValueError:
            print(f"Skipping invalid entry: {s}")
            continue

        # Scale to fixed-point
        fixed_val = int(round(val * scale))

        # Clip to 16-bit signed range
        if fixed_val > 32767:
            fixed_val = 32767
        elif fixed_val < -32768:
            fixed_val = -32768

        coeffs_fixed.append(fixed_val)

    # Write output file in .coe format
    with open(output_file, "w") as f:
        f.write("Radix = 10;\n")
        f.write("Coefficient_Width = 16;\n")
        f.write("CoefData =\n")

        # Write coefficients separated by commas, end with semicolon
        for i, c in enumerate(coeffs_fixed):
            if i < len(coeffs_fixed) - 1:
                f.write(f"{c},\n")
            else:
                f.write(f"{c};\n")

    print(f"Converted {len(coeffs_fixed)} coefficients to {output_file}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python convert_taps.py <input_file> <output_file>")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    convert_taps_line(input_file, output_file)
