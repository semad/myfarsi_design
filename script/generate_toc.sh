#!/bin/bash
# Generate TableOfContents.md

# Get the list of tracked markdown files, sorted
files=$(git ls-files '**/*.md' | sort)

# Start the TOC file
echo "# Table of Contents" > TableOfContents.md
echo "" >> TableOfContents.md

# Process the file list and generate the TOC
echo "$files" | awk -F/ ' 
BEGIN {
    prev_dir = ""
}
{
    if (NF==1) {
        print "- [" $0 "](" $0 ")"
    } else {
        dir = $1
        for (i = 2; i < NF; i++) {
            dir = dir "/" $i
        }
        if (dir != prev_dir) {
            print "\n## `" dir "`\n"
            prev_dir = dir
        }
        print "    - [" $NF "](" $0 ")"
    }
}' >> TableOfContents.md