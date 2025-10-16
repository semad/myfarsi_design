# CLI Contracts: Specification Improver

This document defines the command-line interface for the Specification Improver tool.

## Commands

### `spec-improver analyze`

- **Description**: Analyzes an existing component specification against the quality checklist.
- **Usage**: `spec-improver analyze <path-to-spec.md>`
- **Output**: A list of specific, actionable improvements.

### `spec-improver create`

- **Description**: Creates a new component specification from a template.
- **Usage**: `spec-improver create <feature-name>`
- **Output**: A new specification file with the given feature name.

### `spec-improver update`

- **Description**: Updates an existing component specification based on a list of improvements.
- **Usage**: `spec-improver update <path-to-spec.md> --improvements <path-to-improvements.md>`
- **Output**: The updated specification file.
