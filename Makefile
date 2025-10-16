# Makefile for building and publishing the static HTML site

# Variables
COMMIT_MESSAGE = "Rebuilding the HTML"

# Default target
.DEFAULT_GOAL := help

# Targets
.PHONY: help html rm-mdfiles rm-htmlfiles publish push test toc

help:
	@echo "Available targets:"
	@echo "  help            Show this help message (default)."
	@echo "  html            Generate HTML files from Markdown via script/convert.sh."
	@echo "  publish         Regenerate HTML, remove Markdown, and prepare the html branch."
	@echo "  push            Force-push the html branch to origin."
	@echo "  test            Lint and format Markdown files with markdownlint & prettier."
	@echo "  toc             Regenerate TableOfContents.md from tracked Markdown."

html:
	@echo "Generating HTML files..."
	@./script/convert.sh

rm-mdfiles:
	@echo "Removing markdown files... Disabled"
#	@find . -type f -name "*.md" -not -path "./script/*" -delete

rm-htmlfiles:
	@echo "Removing HTML files... Disabled"
#	@find . -type f -name "*.html" -delete

publish:
	@echo "Publishing website..."
	@git checkout -B html main
	@make html
	@echo "Removing markdown files..."
	@find . -type f -name "*.md" -not -path "./script/*" -delete
	@git add .
	@git commit -m "$(COMMIT_MESSAGE)"

push:
	@echo "Pushing to GitHub..."
	@git push -f origin html

test:
	@echo "Linting and formatting markdown files..."
	@markdownlint --fix **/*.md
	@prettier --write **/*.md

toc:
	@echo "Generating Table of Contents..."
	@./script/generate_toc.sh
