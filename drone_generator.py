#!/usr/bin/env python3
"""
Generate PneumaticCraft drone program from F3+C coordinates.
Paste your F3+C when prompted (standing at drone charging station).
"""

import re
import json

def parse_f3c(input_str):
    """Parse F3+C format: /execute in dimension run tp @s X Y Z ..."""
    match = re.search(r'@s\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)', input_str)
    if match:
        x = int(float(match.group(1))) - 1
        y = int(float(match.group(2)))
        z = int(float(match.group(3))) - 1
        return x, y, z
    return None

def generate_drone_program(x, y, z):
    """Generate drone program JSON with given home coordinates."""
    program = {
        "version": 3,
        "widgets": [
            {"pos": {"x": 72, "y": -19}, "type": "pneumaticcraft:start"},
            {"pos": {"x": 72, "y": 3}, "type": "pneumaticcraft:standby"},
            {"pos": {"x": 72, "y": 14}, "inv": {}, "type": "pneumaticcraft:computer_control"},
            {
                "area_type": {"type": "pneumaticcraft:box"},
                "pos": {"x": 87, "y": -8},
                "pos1": [x, y, z],
                "pos2": [x, y, z],
                "type": "pneumaticcraft:area"
            },
            {
                "area_type": {"type": "pneumaticcraft:box"},
                "pos": {"x": 87, "y": 14},
                "pos1": [x, y - 2, z],
                "pos2": [x, y - 2, z],
                "type": "pneumaticcraft:area"
            },
            {"pos": {"x": 72, "y": 25}, "type": "pneumaticcraft:teleport"},
            {"pos": {"x": 72, "y": -8}, "type": "pneumaticcraft:goto"},
            {
                "area_type": {"type": "pneumaticcraft:box"},
                "pos": {"x": 87, "y": 25},
                "pos1": [x, y, z],
                "pos2": [x, y, z],
                "type": "pneumaticcraft:area"
            }
        ]
    }
    return json.dumps(program, separators=(',', ':'))

def main():
    print("=== Drone Program Generator ===")
    print()
    print("Paste F3+C (standing at charging station):")
    
    f3c_input = input().strip()
    
    coords = parse_f3c(f3c_input)
    if not coords:
        print("Error: Could not parse coordinates")
        print("Expected format: /execute in ... run tp @s X Y Z ...")
        return
    
    x, y, z = coords
    print()
    print(f"Home: {x}, {y}, {z}")
    print()
    print("Drone program (copy this):")
    print()
    print(generate_drone_program(x, y, z))

if __name__ == "__main__":
    main()
