# Makefile for myfarsi_design documentation

# Default target
.DEFAULT_GOAL := help

# Targets
.PHONY: help test toc

help:
	@echo "Available targets:"
	@echo "  help            Show this help message (default)."
	@echo "  test            Lint and format Markdown files with markdownlint & prettier."
	@echo "  toc             Regenerate TableOfContents.md from tracked Markdown."

test:
	@echo "Linting and formatting markdown files..."
	@markdownlint --fix **/*.md
	@prettier --write **/*.md

toc:
	@echo "Generating Table of Contents..."
	@./script/generate_toc.sh
