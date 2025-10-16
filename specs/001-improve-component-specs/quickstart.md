# Quickstart: Specification Improver

This guide provides a quick overview of how to use the Specification Improver tool.

## Installation

```bash
# (Assuming the tool is built and available in the PATH)
go build -o /usr/local/bin/spec-improver ./cmd/spec-improver
```

## Usage

### Analyze a Specification

To analyze an existing specification, use the `analyze` command:

```bash
spec-improver analyze specs/001-improve-component-specs/spec.md
```

### Create a New Specification

To create a new specification from a template, use the `create` command:

```bash
spec-improver create "My New Feature"
```

### Update a Specification

To update an existing specification with a list of improvements, use the `update` command:

```bash
spec-improver update specs/001-improve-component-specs/spec.md --improvements improvements.md
```
