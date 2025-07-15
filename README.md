# Claude Code Hooks Library

A collection of utility scripts for Claude Code and CI/CD pipelines. This library provides command-line tools for filtering command outputs and linting files, designed to be used as pre-commit hooks or in continuous integration workflows.

## Features

- **Command Output Filtering**: Run any command and filter its output based on patterns
- **File-Specific Linting**: Run linting tools on individual files with configurable extensions
- **CI/CD Integration**: Designed for use in pre-commit hooks and continuous integration pipelines
- **Flexible Configuration**: Support for custom ignore patterns and task naming

## Getting started

This package requires Dart SDK ^3.8.1. Install it by adding to your `pubspec.yaml`:

```yaml
dependencies:
  claude_code_hooks_library: ^1.0.0
```

Or install globally to use the scripts directly:

```bash
dart pub global activate claude_code_hooks_library
```

## Usage

### General Command with Filtering

Filter output from any command to reduce noise:

```bash
dart run claude_code_hooks_library:run_command_with_filter \
  --command="npm test" \
  --task="tests" \
  --ignore="coverage/,*.snap"
```

### Single File Linting

Run linting on specific files with extension filtering:

```bash
dart run claude_code_hooks_library:single_file_lint \
  --file="src/components/Button.tsx" \
  --command="eslint" \
  --ignore="generated"
```

### Available Scripts

1. **run_command_with_filter**: General command runner with output filtering
   - `--command`: Command to run (required)
   - `--task`: Display name for the task (optional)
   - `--ignore`: Comma-separated patterns to ignore in output (optional)

2. **single_file_lint**: File-specific linter wrapper
   - `--file`: File path to lint (required)
   - `--command`: Lint command to run (required)
   - `--extensions`: Comma-separated file extensions (default: .ts,.tsx,.js,.jsx)
   - `--ignore`: Comma-separated patterns to ignore in output (optional)

## Additional information

This library is designed to work seamlessly with Claude Code and various CI/CD systems. The scripts exit with code 0 when no errors remain after filtering, making them suitable for pre-commit hooks that should pass when noise is filtered out but real errors are addressed.
