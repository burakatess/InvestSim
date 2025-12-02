#!/usr/bin/env python3
"""Find where EditPortfolioView ends"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find EditPortfolioView
edit_start = None
for i, line in enumerate(lines):
    if 'struct EditPortfolioView: View' in line:
        edit_start = i
        print(f"EditPortfolioView starts at line {i + 1}")
        break

if edit_start:
    # Track braces
    depth = 0
    for i in range(edit_start, len(lines)):
        for char in lines[i]:
            if char == '{':
                depth += 1
            elif char == '}':
                depth -= 1
                if depth == 0:
                    print(f"EditPortfolioView SHOULD end at line {i + 1}")
                    print(f"\nContext around line {i + 1}:")
                    for j in range(max(0, i-5), min(len(lines), i+8)):
                        marker = " <-- EditPortfolioView ends here" if j == i else ""
                        print(f"{j+1}: {lines[j].rstrip()}{marker}")
                    
                    # Check what's after
                    if i + 1 < len(lines):
                        print(f"\nNext line ({i+2}): {lines[i+1].rstrip()}")
                        if '#Preview' in lines[i+1]:
                            print("✅ #Preview is right after EditPortfolioView - CORRECT!")
                        else:
                            print(f"⚠️ Expected #Preview but found: {lines[i+1].rstrip()}")
                    return
        if depth == 0:
            break
