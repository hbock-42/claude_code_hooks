import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';

/// Helper function to create hook JSON input for stdin
String createHookJson(String filePath) {
  return jsonEncode({
    'session_id': 'test_session',
    'transcript_path': '/path/to/transcript.json',
    'hook_event_name': 'PreToolUse',
    'tool_name': 'Edit',
    'tool_input': {
      'file_path': filePath,
      'old_string': 'test',
      'new_string': 'updated'
    }
  });
}

/// Helper function to run the script with JSON input via stdin
Future<ProcessResult> runScriptWithStdin(String jsonInput, List<String> args) async {
  final process = await Process.start(
    'dart',
    ['lib/src/typescript/single_file_lint.dart', ...args],
    workingDirectory: Directory.current.path,
  );

  // Write JSON to stdin
  process.stdin.write(jsonInput);
  await process.stdin.close();

  // Wait for process to complete
  final exitCode = await process.exitCode;
  final stdout = await process.stdout.transform(utf8.decoder).join();
  final stderr = await process.stderr.transform(utf8.decoder).join();

  return ProcessResult(process.pid, exitCode, stdout, stderr);
}

void main() {
  group('single_file_lint.dart', () {
    final scriptPath = 'lib/src/typescript/single_file_lint.dart';

    setUpAll(() async {
      // Create test files for testing
      await Directory('test/fixtures').create(recursive: true);
      await File('test/fixtures/test.ts').writeAsString('const x: number = 42;');
      await File('test/fixtures/test.js').writeAsString('const x = 42;');
      await File('test/fixtures/test.tsx').writeAsString('const Component = () => <div>Hello</div>;');
      await File('test/fixtures/test.jsx').writeAsString('const Component = () => <div>Hello</div>;');
      await File('test/fixtures/test.py').writeAsString('print("hello")');
      await File('test/fixtures/test.txt').writeAsString('plain text');
    });

    tearDownAll(() async {
      // Clean up test files
      final testDir = Directory('test/fixtures');
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    group('Help functionality', () {
      test('shows help when --help flag is provided', () async {
        final result = await Process.run(
          'dart',
          [scriptPath, '--help'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('Usage: single_file_lint.dart'));
        expect(result.stderr.toString(), contains('--command='));
        expect(result.stderr.toString(), contains('--timeout='));
        expect(result.stderr.toString(), contains('reads file path from hook data via stdin'));
      });

      test('shows help when -h flag is provided', () async {
        final result = await Process.run(
          'dart',
          [scriptPath, '-h'],
          workingDirectory: Directory.current.path,
        );

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('Usage: single_file_lint.dart'));
        expect(result.stderr.toString(), contains('Examples:'));
      });
    });

    group('Error handling', () {
      test('fails when malformed JSON is provided via stdin', () async {
        final result = await runScriptWithStdin('invalid json', ['--command=echo']);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ Error reading hook data from stdin'));
      });

      test('fails when no file path is in hook data', () async {
        final hookJson = jsonEncode({
          'session_id': 'test_session',
          'hook_event_name': 'PreToolUse',
          'tool_input': {} // Missing file_path
        });
        final result = await runScriptWithStdin(hookJson, ['--command=echo']);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ No file path found in hook data'));
      });

      test('fails when empty file path is in hook data', () async {
        final hookJson = jsonEncode({
          'session_id': 'test_session',
          'hook_event_name': 'PreToolUse',
          'tool_input': {'file_path': ''}
        });
        final result = await runScriptWithStdin(hookJson, ['--command=echo']);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ No file path found in hook data'));
      });

      test('fails when no command is provided', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), []);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ No command provided'));
      });

      test('fails when empty command is provided', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=']);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ No command provided'));
      });

      test('fails when file does not exist', () async {
        final result = await runScriptWithStdin(createHookJson('nonexistent.ts'), ['--command=echo']);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ File does not exist: nonexistent.ts'));
      });

      test('handles non-existent command gracefully', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=nonexistentcommand123']);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ Error running command'));
        expect(result.stderr.toString(), contains('Make sure the command "nonexistentcommand123" is available'));
      });
    });

    group('File extension filtering', () {
      test('skips files with non-matching extensions', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.py'), ['--command=echo']);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('ℹ️  Skipping command - file does not match extensions'));
        expect(result.stderr.toString(), contains('.ts, .tsx, .js, .jsx'));
        expect(result.stderr.toString(), contains('📄 File: test/fixtures/test.py'));
      });

      test('processes TypeScript files with default extensions', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo "Processing:"']);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('🔍 Running command on file'));
        expect(result.stderr.toString(), contains('📄 File: test/fixtures/test.ts'));
        expect(result.stderr.toString(), contains('📋 Command: echo "Processing:" test/fixtures/test.ts'));
        expect(result.stderr.toString(), contains('✅ Command passed for test.ts!'));
      });

      test('processes JavaScript files with default extensions', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.js'), ['--command=echo "Processing:"']);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('📄 File: test/fixtures/test.js'));
        expect(result.stderr.toString(), contains('✅ Command passed for test.js!'));
      });

      test('processes TSX files with default extensions', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.tsx'), ['--command=echo "Processing:"']);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('📄 File: test/fixtures/test.tsx'));
        expect(result.stderr.toString(), contains('✅ Command passed for test.tsx!'));
      });

      test('processes JSX files with default extensions', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.jsx'), ['--command=echo "Processing:"']);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('📄 File: test/fixtures/test.jsx'));
        expect(result.stderr.toString(), contains('✅ Command passed for test.jsx!'));
      });

    });

    group('Command execution', () {
      test('passes file path as argument to command', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo "Processing file:"']);

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('"Processing file:" test/fixtures/test.ts'));
      });

      test('displays full command being run', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo --version']);

        expect(result.stderr.toString(), contains('📋 Command: echo --version test/fixtures/test.ts'));
      });

      test('returns exit code 2 for failing commands', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=false']);

        expect(result.exitCode, equals(2));
        expect(result.stderr.toString(), contains('❌ Command failed with exit code: 1'));
        expect(result.stderr.toString(), contains('⚠️  Please fix issues before modifying.'));
      });

      test('handles command stdout output', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo "stdout output"']);

        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('stdout output'));
      });

      test('handles command stderr output', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=sh -c "echo \\"Error message\\" >&2; exit 1"']);

        expect(result.exitCode, equals(2));
        expect(result.stderr.toString(), contains('❌ Command errors:'));
        expect(result.stderr.toString(), contains('Error message'));
      });
    });

    group('Timeout functionality', () {
      test('respects default timeout', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo "quick command"']);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('✅ Command passed for test.ts!'));
      });

      test('respects custom timeout setting', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo "custom timeout"', '--timeout=60']);

        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('✅ Command passed for test.ts!'));
      });

      test('handles invalid timeout gracefully', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo "invalid timeout"', '--timeout=invalid']);

        // Should fall back to default timeout (30s) and still work
        expect(result.exitCode, equals(0));
        expect(result.stderr.toString(), contains('✅ Command passed for test.ts!'));
      });
    });

    group('Output separation', () {
      test('sends status messages to stderr', () async {
        final result = await runScriptWithStdin(createHookJson('test/fixtures/test.ts'), ['--command=echo "test output"']);

        expect(result.exitCode, equals(0));
        // Status messages should go to stderr
        expect(result.stderr.toString(), contains('🔍 Running command on file'));
        expect(result.stderr.toString(), contains('📄 File: test/fixtures/test.ts'));
        expect(result.stderr.toString(), contains('✅ Command passed for test.ts!'));
        // Command output should go to stdout
        expect(result.stdout.toString(), contains('test output'));
      });

      test('sends error messages to stderr', () async {
        final result = await runScriptWithStdin(createHookJson('nonexistent.ts'), ['--command=echo']);

        expect(result.exitCode, equals(1));
        expect(result.stderr.toString(), contains('❌ File does not exist: nonexistent.ts'));
        expect(result.stdout.toString(), isEmpty);
      });
    });
  });
}