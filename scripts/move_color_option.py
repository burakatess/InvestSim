#!/usr/bin/env python3
"""Move colorOption function to before body in EditPortfolioView"""

file_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/Views/PortfolioHeader.swift"

with open(file_path, 'r') as f:
    lines = f.readlines()

# Find colorOption function (line 784-819)
color_option_start = None
color_option_end = None

for i, line in enumerate(lines):
    if i == 783 and 'func colorOption' in line:  # Line 784 (0-indexed 783)
        color_option_start = i
        # Find end (should be at line 819)
        depth = 0
        for j in range(i, len(lines)):
            for char in lines[j]:
                if char == '{':
                    depth += 1
                elif char == '}':
                    depth -= 1
                    if depth == 0:
                        color_option_end = j
                        break
            if color_option_end:
                break
        break

print(f"colorOption: lines {color_option_start + 1} to {color_option_end + 1}")

# Extract the function
func_lines = lines[color_option_start:color_option_end + 1]

# Remove from current location (including blank lines before)
new_lines = lines[:color_option_start - 1] + lines[color_option_end + 1:]

# Insert before body (line 615, but adjusted after removal)
# Find "var body: some View {" in new_lines
body_line = None
for i, line in enumerate(new_lines):
    if 'var body: some View {' in line and i > 600:
        body_line = i
        break

if body_line:
    print(f"Inserting before body at line {body_line + 1}")
    
    # Insert function before body
    final_lines = (
        new_lines[:body_line] +
        ['\n'] +
        func_lines +
        ['\n'] +
        new_lines[body_line:]
    )
    
    with open(file_path, 'w') as f:
        f.writelines(final_lines)
    
    print("✅ Moved colorOption before body!")
else:
    print("❌ Could not find body")
