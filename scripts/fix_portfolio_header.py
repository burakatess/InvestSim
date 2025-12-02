#!/usr/bin/env python3
"""Fix PortfolioHeader.swift syntax errors by moving PortfolioMenuView before usage"""

import re

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

# Read the file
with open(file_path, 'r') as f:
    content = f.read()
    lines = content.split('\n')

# Find the PortfolioMenuView struct (starts around line 546, ends around line 816)
# We need to move it to after PortfolioHeader struct (after line 120)

# Find PortfolioHeader end (line 120: "}")
# Find PortfolioMenuView start (line 546: "struct PortfolioMenuView: View {")
# Find PortfolioMenuView end (line 816: "}")

portfolio_header_end = None
portfolio_menu_start = None
portfolio_menu_end = None

# Track brace depth to find struct boundaries
for i, line in enumerate(lines):
    if i == 120 and line.strip() == '}':
        portfolio_header_end = i
    if 'struct PortfolioMenuView: View' in line:
        portfolio_menu_start = i
        # Find the matching closing brace
        depth = 0
        for j in range(i, len(lines)):
            for char in lines[j]:
                if char == '{':
                    depth += 1
                elif char == '}':
                    depth -= 1
                    if depth == 0:
                        portfolio_menu_end = j
                        break
            if portfolio_menu_end:
                break
        break

print(f"PortfolioHeader ends at line: {portfolio_header_end}")
print(f"PortfolioMenuView starts at line: {portfolio_menu_start}")
print(f"PortfolioMenuView ends at line: {portfolio_menu_end}")

if portfolio_header_end and portfolio_menu_start and portfolio_menu_end:
    # Extract PortfolioMenuView
    menu_view_lines = lines[portfolio_menu_start:portfolio_menu_end + 1]
    
    # Remove PortfolioMenuView from its current location
    new_lines = lines[:portfolio_menu_start] + lines[portfolio_menu_end + 1:]
    
    # Insert PortfolioMenuView after PortfolioHeader
    # Adjust insertion point since we removed lines
    insert_point = portfolio_header_end + 1
    
    # Add blank line, then PortfolioMenuView, then blank line
    final_lines = (
        new_lines[:insert_point] + 
        [''] + 
        menu_view_lines + 
        [''] + 
        new_lines[insert_point:]
    )
    
    # Write back
    with open(file_path, 'w') as f:
        f.write('\n'.join(final_lines))
    
    print(f"✅ Moved PortfolioMenuView ({len(menu_view_lines)} lines) to line {insert_point + 1}")
    print(f"✅ File restructured successfully!")
else:
    print("❌ Could not find struct boundaries")
