import os
import re
import uuid

PROJECT_PATH = "InvestSimulator_v2.xcodeproj/project.pbxproj"

def generate_id():
    return uuid.uuid4().hex[:24].upper()

def add_files_to_project():
    if not os.path.exists(PROJECT_PATH):
        print(f"Error: {PROJECT_PATH} not found.")
        return

    with open(PROJECT_PATH, 'r') as f:
        content = f.read()

    # Define new files
    new_files = [
        {"name": "UserAsset.swift", "path": "UserAsset.swift", "group": "Models"},
        {"name": "Trade.swift", "path": "Trade.swift", "group": "Models"}
    ]

    # Generate IDs
    for file in new_files:
        file["file_ref_id"] = generate_id()
        file["build_file_id"] = generate_id()

    # 1. Add PBXFileReference
    # Format: 67504A042EAA73E500D18E1A /* Portfolio.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = Portfolio.swift; sourceTree = "<group>"; };
    
    file_ref_section_end = content.find("/* End PBXFileReference section */")
    if file_ref_section_end == -1:
        print("Error: PBXFileReference section not found")
        return

    file_ref_insert = ""
    for file in new_files:
        file_ref_insert += f'\t\t{file["file_ref_id"]} /* {file["name"]} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file["path"]}; sourceTree = "<group>"; }};\n'
    
    content = content[:file_ref_section_end] + file_ref_insert + content[file_ref_section_end:]

    # 2. Add PBXBuildFile
    # Format: 67504A0D2EAA73E500D18E1A /* Portfolio.swift in Sources */ = {isa = PBXBuildFile; fileRef = 67504A042EAA73E500D18E1A /* Portfolio.swift */; };

    build_file_section_end = content.find("/* End PBXBuildFile section */")
    if build_file_section_end == -1:
        print("Error: PBXBuildFile section not found")
        return

    build_file_insert = ""
    for file in new_files:
        build_file_insert += f'\t\t{file["build_file_id"]} /* {file["name"]} in Sources */ = {{isa = PBXBuildFile; fileRef = {file["file_ref_id"]} /* {file["name"]} */; }};\n'

    content = content[:build_file_section_end] + build_file_insert + content[build_file_section_end:]

    # 3. Add to Models Group
    # Find Models group
    # 67504A082EAA73E500D18E1A /* Models */ = {
    # 	isa = PBXGroup;
    # 	children = (
    
    models_group_match = re.search(r'([A-F0-9]{24}) /\* Models \*/ = \{[^}]*children = \(([^)]*)\);', content, re.DOTALL)
    if not models_group_match:
        print("Error: Models group not found")
        return
    
    models_group_id = models_group_match.group(1)
    children_content = models_group_match.group(2)
    
    children_insert = ""
    for file in new_files:
        children_insert += f'\t\t\t\t{file["file_ref_id"]} /* {file["name"]} */,\n'
    
    # Insert before the closing parenthesis of children
    # We need to be careful with regex replacement.
    # Let's find the exact location in content.
    
    models_group_start = content.find(f'{models_group_id} /* Models */ = {{')
    if models_group_start == -1:
        print("Error: Models group start not found")
        return
        
    children_start = content.find('children = (', models_group_start)
    children_end = content.find(');', children_start)
    
    if children_start == -1 or children_end == -1:
        print("Error: Models group children not found")
        return

    # Insert at the end of children list
    content = content[:children_end] + children_insert + content[children_end:]

    # 4. Add to Sources Build Phase
    # Find Sources build phase
    # 675049D62EAA729C00D18E1A /* Sources */ = {
    # 	isa = PBXSourcesBuildPhase;
    # ...
    # 	files = (
    
    sources_phase_match = re.search(r'([A-F0-9]{24}) /\* Sources \*/ = \{[^}]*files = \(([^)]*)\);', content, re.DOTALL)
    if not sources_phase_match:
        print("Error: Sources build phase not found")
        return

    sources_phase_id = sources_phase_match.group(1)
    
    sources_insert = ""
    for file in new_files:
        sources_insert += f'\t\t\t\t{file["build_file_id"]} /* {file["name"]} in Sources */,\n'

    sources_phase_start = content.find(f'{sources_phase_id} /* Sources */ = {{')
    if sources_phase_start == -1:
        print("Error: Sources phase start not found")
        return

    files_start = content.find('files = (', sources_phase_start)
    files_end = content.find(');', files_start)

    if files_start == -1 or files_end == -1:
        print("Error: Sources phase files not found")
        return

    content = content[:files_end] + sources_insert + content[files_end:]

    with open(PROJECT_PATH, 'w') as f:
        f.write(content)
    
    print("Successfully added files to project.")

if __name__ == "__main__":
    add_files_to_project()
