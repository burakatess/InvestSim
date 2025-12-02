#!/usr/bin/env python3
"""Count all braces in PortfolioHeader.swift"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

with open(file_path, 'r') as f:
    content = f.read()

open_braces = content.count('{')
close_braces = content.count('}')

print(f"Opening braces: {open_braces}")
print(f"Closing braces: {close_braces}")
print(f"Difference: {open_braces - close_braces}")

if open_braces > close_braces:
    print(f"\n❌ Missing {open_braces - close_braces} closing braces")
elif close_braces > open_braces:
    print(f"\n❌ {close_braces - open_braces} extra closing braces")
else:
    print("\n✅ Braces are balanced!")

# Find where #Preview starts
lines = content.split('\n')
for i, line in enumerate(lines):
    if '#Preview' in line:
        print(f"\n#Preview starts at line {i + 1}")
        print("Context:")
        for j in range(max(0, i-3), min(len(lines), i+10)):
            print(f"{j+1}: {lines[j]}")
        break
