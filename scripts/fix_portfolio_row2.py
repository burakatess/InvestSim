#!/usr/bin/env python3
"""Move PortfolioRowView to after PortfolioHeader (before PortfolioMenuView)"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find PortfolioRowView (now at line 267)
portfolio_row_start = None
portfolio_row_end = None

for i, line in enumerate(lines):
    if 'struct PortfolioRowView: View' in line:
        portfolio_row_start = i
        depth = 0
        for j in range(i, len(lines)):
            for char in lines[j]:
                if char == '{':
                    depth += 1
                elif char == '}':
                    depth -= 1
                    if depth == 0:
                        portfolio_row_end = j
                        break
            if portfolio_row_end:
                break
        break

# Find PortfolioHeader end (line 120)
portfolio_header_end = 120

print(f"PortfolioHeader ends at: {portfolio_header_end}")
print(f"PortfolioRowView: lines {portfolio_row_start}-{portfolio_row_end}")

if portfolio_row_start and portfolio_row_end:
    # Extract PortfolioRowView
    row_view_lines = lines[portfolio_row_start:portfolio_row_end + 1]
    
    # Remove from current location
    new_lines = lines[:portfolio_row_start] + lines[portfolio_row_end + 1:]
    
    # Insert after PortfolioHeader (line 121)
    insert_point = portfolio_header_end + 1
    
    final_lines = (
        new_lines[:insert_point] + 
        ['\n'] + 
        row_view_lines + 
        ['\n'] + 
        new_lines[insert_point:]
    )
    
    with open(file_path, 'w') as f:
        f.writelines(final_lines)
    
    print(f"✅ Moved PortfolioRowView to line {insert_point + 1}")
else:
    print("❌ Failed")
