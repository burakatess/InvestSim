#!/usr/bin/env python3
"""Analyze brace balance line by line to find unclosed blocks"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

with open(file_path, 'r') as f:
    lines = f.readlines()

depth = 0
stack = [] # Stack to keep track of what opened the brace (optional, but helpful for debugging context)

for i, line in enumerate(lines):
    line_num = i + 1
    stripped = line.strip()
    
    # Simple check for declarations
    if stripped.startswith("struct ") or stripped.startswith("class ") or stripped.startswith("extension ") or stripped.startswith("func ") or stripped.startswith("var body:"):
        # print(f"Line {line_num}: {stripped} (Current depth: {depth})")
        pass

    for char in line:
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
    
    if depth == 0 and (stripped.startswith("struct ") or stripped.startswith("class ")):
         print(f"Line {line_num}: Root level declaration finished or started? {stripped}")

    if line_num > 810:
        print(f"Line {line_num}: Depth {depth} | {stripped}")

print(f"Final Depth: {depth}")
if depth > 0:
    print(f"Missing {depth} closing braces.")
