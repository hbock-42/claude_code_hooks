#!/usr/bin/env dart

/// Claude Code Hook: General Command Runner
/// 
/// This script is designed to be used as a Claude Code hook that executes
/// arbitrary commands with proper output separation. Status messages go to
/// stderr (visible to Claude) while command output goes to stdout.
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
///             "command": "dart run path/to/run_command.dart --command='npm run lint' --task='linting'"
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
/// - `--task=<name>`: Display name for the task (default: "task")
/// - `--timeout=<seconds>`: Command timeout in seconds (default: 30)
/// - `--help, -h`: Show help message
/// 
/// ## Exit Codes (Hook Behavior)
/// 
/// - 0: Command succeeded (hook allows continuation)
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
/// // Pre-request linting
/// { "command": "dart run run_command.dart --command='npm run lint' --task='linting'" }
/// 
/// // Type checking before file edits
/// { "command": "dart run run_command.dart --command='tsc --noEmit' --task='type-check'" }
/// 
/// // Run tests before modifications
/// { "command": "dart run run_command.dart --command='npm test' --task='testing'" }
/// 
/// // Format code after edits
/// { "command": "dart run run_command.dart --command='prettier --write .' --task='formatting'" }
/// ```

import 'dart:async';
import 'dart:io';

void main(List<String> args) async {
  // Parse named arguments
  String? command;
  String? taskName;
  var timeout = 30; // Default timeout in seconds
  
  for (final arg in args) {
    if (arg.startsWith('--command=')) {
      command = arg.substring('--command='.length);
    } else if (arg.startsWith('--task=')) {
      taskName = arg.substring('--task='.length);
    } else if (arg.startsWith('--timeout=')) {
      timeout = int.tryParse(arg.substring('--timeout='.length)) ?? 30;
    } else if (arg == '--help' || arg == '-h') {
      printHelp();
      exit(0);
    }
  }
  
  if (command == null || command.isEmpty) {
    stderr.writeln('❌ No command provided');
    printHelp();
    exit(1);
  }
  
  // Default task name if not provided
  taskName ??= 'task';
  
  // Parse the command into executable and arguments
  final commandParts = command.split(' ');
  final executable = commandParts[0];
  final commandArgs = commandParts.skip(1).toList();
  
  stderr.writeln('🔍 Running $taskName');
  stderr.writeln('📋 Command: $command');
  
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
      stderr.writeln('✅ ${taskName[0].toUpperCase()}${taskName.substring(1)} passed!');
      exit(0);
    } else {
      stderr.writeln('❌ ${taskName[0].toUpperCase()}${taskName.substring(1)} failed with exit code: ${result.exitCode}');
      stderr.writeln('⚠️  Please fix the errors above.');
      exit(2); // Exit with code 2 for command errors
    }
  } on TimeoutException {
    stderr.writeln('❌ Command timed out after ${timeout}s');
    stderr.writeln('💡 Consider increasing timeout with --timeout=<seconds>');
    exit(1);
  } catch (e) {
    stderr.writeln('❌ Error running $taskName: $e');
    stderr.writeln('💡 Make sure the command "$executable" is available in your PATH');
    exit(1);
  }
}

void printHelp() {
  stderr.writeln('');
  stderr.writeln('📖 Usage: run_command.dart --command="<command>" [options]');
  stderr.writeln('');
  stderr.writeln('Options:');
  stderr.writeln('  --command="<cmd>"    The command to run (required)');
  stderr.writeln('  --task=<name>        Name of the task for display (default: "task")');
  stderr.writeln('  --timeout=<seconds>  Command timeout in seconds (default: 30)');
  stderr.writeln('  --help, -h           Show this help message');
  stderr.writeln('');
  stderr.writeln('Examples:');
  stderr.writeln('  run_command.dart --command="just lint" --task="lint"');
  stderr.writeln('  run_command.dart --command="just check" --task="checks"');
  stderr.writeln('  run_command.dart --command="npm test" --task="tests" --timeout=60');
}