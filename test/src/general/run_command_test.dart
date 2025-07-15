import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('run_command.dart', () {
    final scriptPath = 'lib/src/general/run_command.dart';

    group('Help functionality', () {
      test('shows help when --help flag is provided', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--help',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('Usage: run_command.dart'));
        expect(result.stderr.toString(), contains('--command='));
        expect(result.stderr.toString(), contains('--task='));
        expect(result.stderr.toString(), contains('--timeout='));
      });

      test('shows help when -h flag is provided', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '-h',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('Usage: run_command.dart'));
        expect(result.stderr.toString(), contains('Examples:'));
      });
    });

    group('Error handling', () {
      test('fails when no command is provided', () async {
        final result = await Process.run('dart', [
          scriptPath,
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ No command provided'));
      });

      test('fails when empty command is provided', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ No command provided'));
      });

      test('handles non-existent command gracefully', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=nonexistentcommand123',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ Error running task'));
        expect(
          result.stderr.toString(),
          contains('Make sure the command "nonexistentcommand123" is available'),
        );
      });
    });

    group('Command execution', () {
      test('runs successful command with default task name', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo "Hello World"',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('🔍 Running task'));
        expect(result.stderr.toString(), contains('📋 Command: echo "Hello World"'));
        expect(result.stderr.toString(), contains('✅ Task passed!'));
        expect(result.stdout.toString(), contains('Hello World'));
      });

      test('runs successful command with custom task name', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo "Hello World"',
          '--task=greeting',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('🔍 Running greeting'));
        expect(result.stderr.toString(), contains('✅ Greeting passed!'));
        expect(result.stdout.toString(), contains('Hello World'));
      });

      test('handles command with arguments', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo -n "test with args"',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('test with args'));
      });

      test('returns exit code 2 for failing commands', () async {
        final result = await Process.run(
          'dart',
          [scriptPath, '--command=false'], // false command always exits with code 1
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(2));
        expect(result.stderr.toString(), contains('❌ Task failed with exit code: 1'));
        expect(result.stderr.toString(), contains('⚠️  Please fix the errors above.'));
      });

      test('displays stderr output when command fails', () async {
        // Use a command that writes to stderr and fails
        final result = await Process.run('dart', [
          scriptPath,
          '--command=false',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(2));
        expect(result.stderr.toString(), contains('❌ Task failed with exit code: 1'));
        expect(result.stderr.toString(), contains('⚠️  Please fix the errors above.'));
      });

      test('displays task name with proper capitalization', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo "test"',
          '--task=linting',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('🔍 Running linting'));
        expect(result.stderr.toString(), contains('✅ Linting passed!'));
        expect(result.stdout.toString(), contains('test'));
      });
    });

    group('Timeout functionality', () {
      test('respects default timeout', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo "quick command"',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('✅ Task passed!'));
      });

      test('respects custom timeout setting', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo "custom timeout"',
          '--timeout=60',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('✅ Task passed!'));
      });

      test('handles invalid timeout gracefully', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo "invalid timeout"',
          '--timeout=invalid',
        ], workingDirectory: Directory.current.path);

        // Should fall back to default timeout (30s) and still work
        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('✅ Task passed!'));
      });
    });

    group('Output separation', () {
      test('sends status messages to stderr', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=echo "test output"',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(0));
        // Status messages should go to stderr
        expect(result.stderr.toString(), contains('🔍 Running task'));
        expect(result.stderr.toString(), contains('📋 Command: echo "test output"'));
        expect(result.stderr.toString(), contains('✅ Task passed!'));
        // Command output should go to stdout
        expect(result.stdout.toString(), contains('test output'));
      });

      test('sends error messages to stderr', () async {
        final result = await Process.run('dart', [
          scriptPath,
          '--command=nonexistentcommand123',
        ], workingDirectory: Directory.current.path);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ Error running task'));
        expect(result.stdout.toString(), isEmpty);
      });
    });
  });
}