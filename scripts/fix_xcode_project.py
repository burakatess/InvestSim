#!/usr/bin/env python3
"""Remove deleted file references from Xcode project"""

pbxproj_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/InvestSimulator_v2.xcodeproj/project.pbxproj"

# Read the file
with open(pbxproj_path, 'r') as f:
    lines = f.readlines()

# Filter out lines containing the deleted file IDs
filtered_lines = []
skip_ids = [
    '670BE86C2ED59B460054A55D',  # TefasProvider.swift
    '670BE86F2ED59B460054A55D',  # TefasProvider.swift in Sources
    '670BE8152ECEF72A0054A55D',  # TEFASSyncService.swift
    '670BE8192ECEF72A0054A55D',  # TEFASSyncService.swift in Sources
]

for line in lines:
    should_skip = False
    for skip_id in skip_ids:
        if skip_id in line:
            should_skip = True
            break
    if not should_skip:
        filtered_lines.append(line)

# Write back
with open(pbxproj_path, 'w') as f:
    f.writelines(filtered_lines)

print(f"Removed {len(lines) - len(filtered_lines)} lines from project.pbxproj")
