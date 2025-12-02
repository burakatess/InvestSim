#!/usr/bin/env python3
import sys

pbxproj_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/InvestSimulator_v2.xcodeproj/project.pbxproj"
file_to_remove = "BISTSyncService.swift"

with open(pbxproj_path, 'r') as f:
    lines = f.readlines()

filtered_lines = []
removed_count = 0

for line in lines:
    if file_to_remove in line:
        removed_count += 1
        continue
    filtered_lines.append(line)

with open(pbxproj_path, 'w') as f:
    f.writelines(filtered_lines)

print(f"Removed {removed_count} lines referencing {file_to_remove}")
