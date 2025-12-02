#!/usr/bin/env python3
"""Find where body property ends in EditPortfolioView"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find EditPortfolioView body
body_start = None
for i, line in enumerate(lines):
    if i > 600 and 'var body: some View {' in line:
        body_start = i
        print(f"body starts at line {i + 1}")
        break

if body_start:
    # Track braces to find where body ends
    depth = 0
    started = False
    for i in range(body_start, min(body_start + 200, len(lines))):
        for char in lines[i]:
            if char == '{':
                depth += 1
                started = True
            elif char == '}':
                depth -= 1
                if started and depth == 0:
                    print(f"body SHOULD end at line {i + 1}")
                    print(f"\nContext:")
                    for j in range(max(0, i-2), min(i+5, len(lines))):
                        marker = " <-- HERE" if j == i else ""
                        print(f"{j+1}: {lines[j].rstrip()}{marker}")
                    
                    # Check what's after
                    print(f"\nWhat comes after (lines {i+2} to {i+10}):")
                    for j in range(i+1, min(i+10, len(lines))):
                        print(f"{j+1}: {lines[j].rstrip()}")
                    break
