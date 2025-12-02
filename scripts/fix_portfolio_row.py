#!/usr/bin/env python3
"""Fix PortfolioHeader.swift - move PortfolioRowView before usage"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

# Read the file
with open(file_path, 'r') as f:
    lines = f.readlines()

# Find PortfolioRowView (starts at line 694)
# Find where to insert it (after PortfolioMenuView, around line 267)

portfolio_row_start = None
portfolio_row_end = None
insert_after_line = None

# Find PortfolioRowView
for i, line in enumerate(lines):
    if 'struct PortfolioRowView: View' in line:
        portfolio_row_start = i
        # Find matching closing brace
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

# Find where PortfolioMenuView ends (to insert after it)
for i, line in enumerate(lines):
    if i > 120 and i < 300 and line.strip() == '}' and i > 260:
        # This should be around line 267 (end of PortfolioMenuView)
        insert_after_line = i
        break

print(f"PortfolioRowView: lines {portfolio_row_start}-{portfolio_row_end}")
print(f"Insert after line: {insert_after_line}")

if portfolio_row_start and portfolio_row_end and insert_after_line:
    # Extract PortfolioRowView
    row_view_lines = lines[portfolio_row_start:portfolio_row_end + 1]
    
    # Remove from current location
    new_lines = lines[:portfolio_row_start] + lines[portfolio_row_end + 1:]
    
    # Insert after PortfolioMenuView
    # Adjust for removed lines
    if portfolio_row_start < insert_after_line:
        insert_point = insert_after_line
    else:
        insert_point = insert_after_line + 1
    
    final_lines = (
        new_lines[:insert_point] + 
        ['\n'] + 
        row_view_lines + 
        ['\n'] + 
        new_lines[insert_point:]
    )
    
    # Write back
    with open(file_path, 'w') as f:
        f.writelines(final_lines)
    
    print(f"✅ Moved PortfolioRowView ({len(row_view_lines)} lines)")
    print(f"✅ File restructured!")
else:
    print("❌ Could not find boundaries")
    print(f"  portfolio_row_start: {portfolio_row_start}")
    print(f"  portfolio_row_end: {portfolio_row_end}")
    print(f"  insert_after_line: {insert_after_line}")
