#!/bin/bash
# Generate README.md with embedded Table of Contents
#
# This script merges the auto-generated table of contents into README.md
# while preserving any manual content that exists above the TOC marker.
#
# Behavior:
# - Extracts manual content before <!-- AUTO-GENERATED --> marker
# - If no marker exists, treats entire README as manual content
# - Generates TOC from tracked markdown files (excluding patterns)
# - Merges manual content + TOC section with markers
# - Writes result to README.md

# 1. Extract manual content from existing README.md
if [ -f README.md ]; then
    if grep -q "^---$" README.md 2>/dev/null && grep -q "## Documentation Table of Contents" README.md 2>/dev/null; then
        # Extract everything before the "---" separator that precedes the TOC
        sed -n '1,/^---$/p' README.md | sed '$d' > README.manual.tmp
    else
        # No TOC section = treat entire file as manual content
        cp README.md README.manual.tmp
    fi
else
    # No README.md exists - create minimal header
    echo "# myfarsi_design" > README.manual.tmp
    echo "" >> README.manual.tmp
fi

# 2. Generate TOC section
echo "" > README.toc.tmp
echo "---" >> README.toc.tmp
echo "" >> README.toc.tmp
echo "## Documentation Table of Contents" >> README.toc.tmp
echo "" >> README.toc.tmp
echo "<!-- AUTO-GENERATED: Do not edit below this line -->" >> README.toc.tmp

# Get the list of tracked markdown files (both root and subdirectories), excluding patterns
# Separate root files (no /) and directory files, then combine with root first
root_files=$(git ls-files '*.md' | grep -v '/' | grep -v -E '(README\.md|TableOfContents\.md)' | sort)
dir_files=$(git ls-files '**/*.md' | grep -v -E '(^specs/|^\.specify/|^\.claude/)' | sort)
files=$(printf "%s\n%s\n" "$root_files" "$dir_files" | grep -v '^$')

# Process the file list and generate the TOC (with root files first)
echo "$files" | awk -F/ '
BEGIN {
    prev_dir = ""
    root_section_printed = 0
}
{
    if (NF==1) {
        # Root-level file
        if (root_section_printed == 0) {
            print "\n## Root Documentation\n"
            root_section_printed = 1
        }
        print "- [" $0 "](" $0 ")"
    } else {
        # File in subdirectory
        dir = $1
        for (i = 2; i < NF; i++) {
            dir = dir "/" $i
        }
        if (dir != prev_dir) {
            print "\n## `" dir "`\n"
            prev_dir = dir
        }
        print "- [" $NF "](" $0 ")"
    }
}' >> README.toc.tmp

echo "" >> README.toc.tmp
echo "<!-- END AUTO-GENERATED -->" >> README.toc.tmp

# 3. Merge manual content and TOC
cat README.manual.tmp README.toc.tmp > README.md

# 4. Cleanup temporary files
rm README.manual.tmp README.toc.tmp

echo "README.md generated successfully with merged table of contents."
