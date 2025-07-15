#!/usr/bin/env dart

/// Claude Code Hook: Single File Command Runner
///
/// This script is designed to be used as a Claude Code hook that executes
/// commands on individual files (e.g., linting, type checking). It reads the
/// file path from hook data passed via stdin and automatically filters files
/// to TypeScript/JavaScript extensions.
///
/// ## Hook Configuration
///
/// Add to your Claude Code hooks configuration:
///
/// ```json
/// {
///   "hooks": {
///     "PreToolUse": [
///       {
///         "matcher": "Edit|Write|MultiEdit",
///         "hooks": [
///           {
///             "type": "command",
///             "command": "dart run path/to/single_file_lint.dart --command='eslint'"
///           }
///         ]
///       }
///     ]
///   }
/// }
/// ```
///
/// ## Parameters
///
/// - `--command="<cmd>"`: The command to execute (required)
/// - `--timeout=<seconds>`: Command timeout in seconds (default: 30)
/// - `--help, -h`: Show help message
///
/// ## Input Data
///
/// The script reads JSON data from stdin containing hook information:
/// - `tool_input.file_path`: Path to the file being processed
///
/// ## File Extension Support
///
/// Automatically processes files with these extensions:
/// - `.ts` (TypeScript)
/// - `.tsx` (TypeScript JSX)
/// - `.js` (JavaScript)
/// - `.jsx` (JavaScript JSX)
///
/// Files with other extensions are skipped with exit code 0.
///
/// ## Exit Codes (Hook Behavior)
///
/// - 0: Command succeeded or file skipped (hook allows continuation)
/// - 2: Command failed (hook blocks Claude Code execution)
/// - 1: Script error (hook reports error but doesn't block)
///
/// ## Output Behavior
///
/// - **stderr**: Status messages, progress info, errors (visible to Claude)
/// - **stdout**: Original command output (preserved for processing)
///
/// ## Common Hook Use Cases
///
/// ```json
/// // ESLint before file edits
/// { "command": "dart run single_file_lint.dart --command='eslint'" }
///
/// // TypeScript type checking
/// { "command": "dart run single_file_lint.dart --command='tsc --noEmit'" }
///
/// // Prettier formatting check
/// { "command": "dart run single_file_lint.dart --command='prettier --check'" }
///
/// // Custom linter
/// { "command": "dart run single_file_lint.dart --command='my-custom-linter'" }
/// ```

import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  // Parse command line arguments
  String? command;
  final allowedExtensions = <String>['.ts', '.tsx', '.js', '.jsx'];
  var timeout = 30; // Default timeout in seconds

  for (final arg in args) {
    if (arg.startsWith('--command=')) {
      command = arg.substring('--command='.length);
    } else if (arg.startsWith('--timeout=')) {
      timeout = int.tryParse(arg.substring('--timeout='.length)) ?? 30;
    } else if (arg == '--help' || arg == '-h') {
      printHelp();
      exit(0);
    }
  }

  // Read JSON from stdin to get file_path from hook data
  String? filePath;
  try {
    final stdinContent = await stdin.transform(utf8.decoder).join();
    final hookData = jsonDecode(stdinContent);
    filePath = hookData['tool_input']['file_path'];
  } catch (e) {
    stderr.writeln('❌ Error reading hook data from stdin: $e');
    exit(1);
  }

  if (filePath == null || filePath.isEmpty) {
    stderr.writeln('❌ No file path found in hook data');
    exit(1);
  }

  if (command == null || command.isEmpty) {
    stderr.writeln('❌ No command provided');
    printHelp();
    exit(1);
  }

  // Check if file exists
  final file = File(filePath);
  if (!await file.exists()) {
    stderr.writeln('❌ File does not exist: $filePath');
    exit(1);
  }

  // Check if the file has an allowed extension
  final hasAllowedExtension = allowedExtensions.any((ext) => filePath?.endsWith(ext) ?? false);

  if (!hasAllowedExtension) {
    stderr.writeln(
      'ℹ️  Skipping command - file does not match extensions: ${allowedExtensions.join(', ')}',
    );
    stderr.writeln('📄 File: $filePath');
    exit(0);
  }

  // Parse the command into executable and arguments
  final commandParts = command.split(' ');
  final executable = commandParts[0];
  final commandArgs = [...commandParts.skip(1), filePath];

  stderr.writeln('🔍 Running command on file');
  stderr.writeln('📄 File: $filePath');
  stderr.writeln('📋 Command: $command $filePath');

  try {
    // Run the command with timeout
    final result = await Process.run(
      executable,
      commandArgs,
      workingDirectory: Directory.current.path,
    ).timeout(Duration(seconds: timeout));

    // Handle stdout
    if (result.stdout.toString().isNotEmpty) {
      stdout.write(result.stdout.toString());
    }

    // Handle stderr and errors
    if (result.stderr.toString().isNotEmpty) {
      stderr.writeln('❌ Command errors:');
      stderr.write(result.stderr.toString());
    }

    if (result.exitCode == 0) {
      stderr.writeln('✅ Command passed for ${filePath.split('/').last}!');
      exit(0);
    } else {
      stderr.writeln('❌ Command failed with exit code: ${result.exitCode}');
      stderr.writeln('⚠️  Please fix issues before modifying.');
      exit(2);
    }
  } on TimeoutException {
    stderr.writeln('❌ Command timed out after ${timeout}s');
    stderr.writeln('💡 Consider increasing timeout with --timeout=<seconds>');
    exit(1);
  } catch (e) {
    stderr.writeln('❌ Error running command: $e');
    stderr.writeln('💡 Make sure the command "$executable" is available in your PATH');
    exit(1);
  }
}

void printHelp() {
  stderr.writeln('');
  stderr.writeln('📖 Usage: single_file_lint.dart --command="<command>" [options]');
  stderr.writeln('');
  stderr.writeln('This script reads file path from hook data via stdin.');
  stderr.writeln('');
  stderr.writeln('Options:');
  stderr.writeln('  --command="<cmd>"    The command to run (required)');
  stderr.writeln('  --timeout=<seconds>  Command timeout in seconds (default: 30)');
  stderr.writeln('  --help, -h           Show this help message');
  stderr.writeln('');
  stderr.writeln('Examples:');
  stderr.writeln('  single_file_lint.dart --command="eslint"');
  stderr.writeln('  single_file_lint.dart --command="tsc --noEmit" --timeout=60');
}
