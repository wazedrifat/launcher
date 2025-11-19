import 'dart:io';
import 'package:launcher/services/logger_service.dart';

class ProcessService {
  static final ProcessService instance = ProcessService._internal();
  factory ProcessService() => instance;
  ProcessService._internal();

  Future<String?> findExecutable(String folderPath, String exeFileName) async {
    try {
      LoggerService.instance.logProcessOperation('Find executable', details: 'Searching ${exeFileName} in $folderPath');

      final directory = Directory(folderPath);
      if (!directory.existsSync()) {
        LoggerService.instance.warning('Directory does not exist: $folderPath', tag: 'PROCESS');
        return null;
      }

      final candidate = File('${folderPath.replaceAll('\\', '/')}/$exeFileName');
      if (candidate.existsSync()) {
        LoggerService.instance.logProcessOperation('Executable found', details: 'Found: ${candidate.path}');
        return candidate.path;
      }

      LoggerService.instance.warning('Executable not found: $exeFileName in $folderPath', tag: 'PROCESS');
      return null;
    } catch (e, stackTrace) {
      LoggerService.instance.logProcessOperation('Find executable failed', error: e, stackTrace: stackTrace);
      print('[PROCESS][ERROR] $e');
      print('[PROCESS][STACK] $stackTrace');
      return null;
    }
  }

  String _extractImageName(String exePath) {
    try {
      // Works for both C:\path\app.exe and C:/path/app.exe
      final parts = exePath.split(RegExp(r'[\\/]'));
      return parts.isNotEmpty ? parts.last : exePath;
    } catch (_) {
      return exePath;
    }
  }

  Future<bool> isProcessRunning(String exePath) async {
    try {
      final imageName = _extractImageName(exePath);
      LoggerService.instance.logProcessOperation('Check if process is running', details: 'Executable: $imageName');

      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq $imageName', '/FO', 'LIST'],
        workingDirectory: Directory.current.path,
      );

      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        final isRunning = output.contains(imageName) && !output.contains('INFO: No tasks are running');
        LoggerService.instance.info('Process $imageName running: $isRunning', tag: 'PROCESS');
        return isRunning;
      }
      return false;
    } catch (e, stack) {
      LoggerService.instance.logProcessOperation('Failed to check process status', error: e, stackTrace: stack);
      print('[PROCESS][ERROR] $e');
      print('[PROCESS][STACK] $stack');
      return false;
    }
  }

  Future<bool> launchExecutable(String exePath) async {
    try {
      LoggerService.instance.logProcessOperation('Launch executable', details: 'Launching: $exePath');
      
      // Get the directory of the executable - many apps need to run from their own directory
      final exeFile = File(exePath);
      final workingDir = exeFile.parent.path;
      
      // Launch the process in detached mode to prevent hanging
      // This ensures the process doesn't inherit stdin/stdout/stderr from the launcher
      final process = await Process.start(
        exePath,
        [],
        workingDirectory: workingDir,
        mode: ProcessStartMode.detached,
        runInShell: Platform.isWindows, // Use shell on Windows for better compatibility
      );
      
      // For detached mode, the process starts immediately and is independent
      // The process handle is still valid for getting the PID
      final pid = process.pid;
      LoggerService.instance.logProcessOperation('Executable launched', details: 'PID: $pid, Working directory: $workingDir');
      
      // With detached mode, we don't need to manage the process handle
      // The process will continue running independently
      // If we reach here, the process started successfully
      return true;
    } catch (e, stack) {
      LoggerService.instance.logProcessOperation('Failed to launch executable', error: e, stackTrace: stack);
      print('[PROCESS][ERROR] $e');
      print('[PROCESS][STACK] $stack');
      return false;
    }
  }

  Future<List<String>> getRunningProcesses() async {
    try {
      final result = await Process.run(
        'tasklist',
        ['/FO', 'CSV'],
        workingDirectory: Directory.current.path,
      );

      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        return lines.where((line) => line.trim().isNotEmpty).toList();
      }
      return [];
    } catch (e, stack) {
      LoggerService.instance.logProcessOperation('Failed to get running processes', error: e, stackTrace: stack);
      print('[PROCESS][ERROR] $e');
      print('[PROCESS][STACK] $stack');
      return [];
    }
  }
}
