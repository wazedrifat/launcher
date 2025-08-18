import 'dart:io';
import 'package:process_run/process_run.dart';
import 'package:launcher/services/logger_service.dart';

class ProcessService {
  static final ProcessService instance = ProcessService._internal();
  factory ProcessService() => instance;
  ProcessService._internal();

  Future<String?> findExecutable(String folderPath, String pattern) async {
    try {
      LoggerService.instance.logProcessOperation('Find executable', details: 'Searching in $folderPath for $pattern');
      
      final directory = Directory(folderPath);
      if (!directory.existsSync()) {
        LoggerService.instance.warning('Directory does not exist: $folderPath', tag: 'PROCESS');
        return null;
      }

      final files = directory.listSync();
      for (final file in files) {
        if (file is File && file.path.endsWith('.exe')) {
          LoggerService.instance.logProcessOperation('Executable found', details: 'Found: ${file.path}');
          return file.path;
        }
      }
      
      LoggerService.instance.warning('No executable found in directory: $folderPath', tag: 'PROCESS');
      return null;
    } catch (e, stackTrace) {
      LoggerService.instance.logProcessOperation('Find executable failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Future<bool> isProcessRunning(String exePath) async {
    try {
      final result = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq ${exePath.split('\\').last}'],
        workingDirectory: Directory.current.path,
      );
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        // Check if the process is actually running (not just found in tasklist)
        return output.contains(exePath.split('\\').last) && 
               !output.contains('INFO: No tasks are running');
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> launchExecutable(String exePath) async {
    try {
      final result = await Process.start(exePath, []);
      return result.pid != null;
    } catch (e) {
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
    } catch (e) {
      return [];
    }
  }
}
