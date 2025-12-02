#!/usr/bin/env python3
"""Analyze brace balance in PortfolioHeader.swift"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find EditPortfolioView struct
edit_portfolio_start = None
for i, line in enumerate(lines):
    if 'struct EditPortfolioView: View' in line:
        edit_portfolio_start = i
        break

if edit_portfolio_start:
    print(f"EditPortfolioView starts at line {edit_portfolio_start + 1}")
    
    # Count braces from start
    depth = 0
    for i in range(edit_portfolio_start, len(lines)):
        line_num = i + 1
        for char in lines[i]:
            if char == '{':
                depth += 1
            elif char == '}':
                depth -= 1
                if depth == 0:
                    print(f"EditPortfolioView ends at line {line_num}")
                    print(f"\nLines around colorOption (784):")
                    for j in range(782, min(786, len(lines))):
                        print(f"{j+1}: {lines[j]}", end='')
                    break
        if depth == 0:
            break
    
    if depth != 0:
        print(f"ERROR: Brace mismatch! Depth = {depth}")
        print(f"Need to add {depth} closing braces" if depth > 0 else f"Need to remove {-depth} closing braces")
