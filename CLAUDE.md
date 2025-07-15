# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dart library package (`claude_code_hooks_library`) that provides utility scripts for use with Claude Code and CI/CD pipelines. The library includes command-line tools for filtering command outputs and linting files, designed to be used as pre-commit hooks or in continuous integration workflows.

## Key Commands

### Development Commands

```bash
# Run tests
dart test

# Analyze code for issues
dart analyze

# Format code
dart format .

# Run a specific utility script
dart run lib/src/general/run_command_with_filter.dart --command="<command>" --task=<name>
dart run lib/src/typescript/single_file_lint.dart --file=<path> --command="<lint_command>"
```

### Available Utility Scripts

1. **run_command_with_filter.dart** - General command runner with output filtering
   - Location: `lib/src/general/run_command_with_filter.dart`
   - Usage: `dart run lib/src/general/run_command_with_filter.dart --command="<cmd>" [--task=<name>] [--ignore=pattern1,pattern2,...]`
   - Can filter output based on patterns to ignore noise

2. **single_file_lint.dart** - File-specific linter wrapper
   - Location: `lib/src/typescript/single_file_lint.dart`
   - Usage: `dart run lib/src/typescript/single_file_lint.dart --file=<path> --command="<lint_cmd>" [--extensions=.ts,.tsx] [--ignore=patterns]`
   - Designed for TypeScript/JavaScript files but configurable for other extensions

## Architecture

The library follows Dart package conventions:
- `/lib/` - Public API (main library file)
- `/lib/src/` - Private implementation code organized by language/purpose:
  - `/lib/src/general/` - General-purpose utility scripts
  - `/lib/src/typescript/` - TypeScript-specific utilities
  - `/lib/src/dart/` - Reserved for Dart-specific utilities (currently empty)
  - `/lib/src/javascript/` - Reserved for JavaScript-specific utilities (currently empty)

The main library export is through `lib/claude_code_hooks_library.dart`, though the primary functionality is in the executable scripts rather than importable classes.

## Important Notes

- This is a library package, so `pubspec.lock` should not be committed
- Scripts are designed to be run directly with `dart run`
- Scripts exit with code 0 if no errors remain after filtering, making them suitable for pre-commit hooks
- The library requires Dart SDK ^3.8.1