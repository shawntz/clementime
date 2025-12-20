#!/usr/bin/env python3
import re
import sys

project_path = "/Users/shawn.schwartz/Developer/Projects/clementime/clementime-mac/Clementime/Clementime.xcodeproj/project.pbxproj"

# Read the project file
with open(project_path, 'r') as f:
    content = f.read()

# New entries to add
sections_view_ref = "230DF7EBEBD3132EA3B3563F"
sections_view_build = "D02D87CB09F2F0A306CB8C7D"
editor_view_ref = "758B62CBB633544378819392"
editor_view_build = "54F2568EE86D2B737581D66C"
sections_group = "B43DEC72EA8247804A0E6898"

# 1. Add to PBXBuildFile section (after the first existing entry)
build_file_pattern = r'(/\* Begin PBXBuildFile section \*/\n)'
build_file_addition = f'''\t\t{sections_view_build} /* SectionsView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {sections_view_ref} /* SectionsView.swift */; }};
\t\t{editor_view_build} /* SectionEditorView.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {editor_view_ref} /* SectionEditorView.swift */; }};
'''
content = re.sub(build_file_pattern, r'\1' + build_file_addition, content)

# 2. Add to PBXFileReference section (after the first existing entry)
file_ref_pattern = r'(/\* Begin PBXFileReference section \*/\n)'
file_ref_addition = f'''\t\t{sections_view_ref} /* SectionsView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SectionsView.swift; sourceTree = "<group>"; }};
\t\t{editor_view_ref} /* SectionEditorView.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SectionEditorView.swift; sourceTree = "<group>"; }};
'''
content = re.sub(file_ref_pattern, r'\1' + file_ref_addition, content)

# 3. Add to PBXGroup for Views (find Views group and add Sections subgroup)
# First, find an existing view group pattern to copy
views_pattern = r'(path = Views;[^}]+children = \([^)]+)(\);)'
sections_group_entry = f'''
\t\t\t\t{sections_group} /* Sections */,'''
content = re.sub(views_pattern, r'\1' + sections_group_entry + r'\2', content, count=1)

# 4. Add the Sections group definition itself (before End PBXGroup)
group_pattern = r'(/\* End PBXGroup section \*/)'
sections_group_def = f'''\t\t{sections_group} /* Sections */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{sections_view_ref} /* SectionsView.swift */,
\t\t\t\t{editor_view_ref} /* SectionEditorView.swift */,
\t\t\t);
\t\t\tpath = Sections;
\t\t\tsourceTree = "<group>";
\t\t}};
'''
content = re.sub(group_pattern, sections_group_def + r'\1', content)

# 5. Add to PBXSourcesBuildPhase (find the files = section and add our build files)
sources_pattern = r'(isa = PBXSourcesBuildPhase;[^}]+files = \([^)]+)(\);)'
sources_addition = f'''
\t\t\t\t{sections_view_build} /* SectionsView.swift in Sources */,
\t\t\t\t{editor_view_build} /* SectionEditorView.swift in Sources */,'''
content = re.sub(sources_pattern, r'\1' + sources_addition + r'\2', content, count=1)

# Write back
with open(project_path, 'w') as f:
    f.write(content)

print("✅ Successfully added SectionsView and SectionEditorView to Xcode project!")
print("✅ Removed unassigned AppIcon.png file")
print("\nNow run: cd /Users/shawn.schwartz/Developer/Projects/clementime/clementime-mac/Clementime && xcodebuild -project Clementime.xcodeproj -scheme Clementime build")
