#!/usr/bin/env python3
import uuid

pbxproj_path = "/Users/burak/Yedek/InvestSimulator_v2_21.11.2025/InvestSim.xcodeproj/project.pbxproj"

def generate_id():
    return str(uuid.uuid4()).replace('-', '').upper()[:24]

file_ref_id = generate_id()
build_file_id = generate_id()

print(f"Generated IDs: FileRef={file_ref_id}, BuildFile={build_file_id}")

with open(pbxproj_path, 'r') as f:
    lines = f.readlines()

new_lines = []
in_build_files = False
in_file_refs = False
in_main_group = False
in_resources = False

# IDs to look for
main_group_id = "675049D12EAA729C00D18E1A"
resources_phase_id = "675049D82EAA729C00D18E1A"

added_build_file = False
added_file_ref = False
added_to_group = False
added_to_resources = False

for line in lines:
    new_lines.append(line)
    
    # 1. Add to PBXBuildFile
    if "/* Begin PBXBuildFile section */" in line:
        in_build_files = True
    elif "/* End PBXBuildFile section */" in line:
        in_build_files = False
    
    if in_build_files and not added_build_file:
        new_lines.append(f'\t\t{build_file_id} /* Localizable.strings in Resources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* Localizable.strings */; }};\n')
        added_build_file = True

    # 2. Add to PBXFileReference
    if "/* Begin PBXFileReference section */" in line:
        in_file_refs = True
    elif "/* End PBXFileReference section */" in line:
        in_file_refs = False
        
    if in_file_refs and not added_file_ref:
        new_lines.append(f'\t\t{file_ref_id} /* Localizable.strings */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.strings; path = Localizable.strings; sourceTree = "<group>"; }};\n')
        added_file_ref = True

    # 3. Add to Main Group
    if main_group_id in line and "isa = PBXGroup" in line:
        in_main_group = True
    
    if in_main_group and "children = (" in line:
        # We are inside the children list of the main group
        pass
        
    if in_main_group and not added_to_group and "children = (" in line:
        new_lines.append(f'\t\t\t\t{file_ref_id} /* Localizable.strings */,\n')
        added_to_group = True
        in_main_group = False # Stop tracking after adding

    # 4. Add to PBXResourcesBuildPhase
    if resources_phase_id in line and "isa = PBXResourcesBuildPhase" in line:
        in_resources = True
        
    if in_resources and "files = (" in line:
        pass
        
    if in_resources and not added_to_resources and "files = (" in line:
        new_lines.append(f'\t\t\t\t{build_file_id} /* Localizable.strings in Resources */,\n')
        added_to_resources = True
        in_resources = False

with open(pbxproj_path, 'w') as f:
    f.writelines(new_lines)

print("Successfully added Localizable.strings to project.pbxproj")
