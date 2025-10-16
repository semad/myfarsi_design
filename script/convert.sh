#!/bin/bash
find . -name "*.md" -not -name "TableOfContents.md" -not -path "./node_modules/*" | while read -r file; do
  pandoc --standalone --metadata title="$(basename "$file" .md)" "$file" -o "${file%.md}.html"
done
