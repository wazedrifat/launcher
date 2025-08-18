import 'dart:io';
import 'package:process_run/process_run.dart';
import 'package:launcher/services/logger_service.dart';

class GitService {
  static final GitService instance = GitService._internal();
  factory GitService() => instance;
  GitService._internal();

  Future<bool> cloneRepository(String repoUrl, String localPath, String branch, {Function(String)? onProgress}) async {
    try {
      LoggerService.instance.logGitOperation('Clone repository', details: 'From $repoUrl to $localPath (branch: $branch)');

      onProgress?.call('Cloning repository...');

      final result = await Process.run(
        'git',
        ['clone', '-b', branch, repoUrl, localPath],
        workingDirectory: Directory.current.path,
      );

      if (result.exitCode == 0) {
        LoggerService.instance.logGitOperation('Clone successful', details: 'Repository cloned to $localPath');
        onProgress?.call('Repository cloned successfully');
        return true;
      } else {
        LoggerService.instance.logGitOperation('Clone failed', details: 'Exit code: ${result.exitCode}, Error: ${result.stderr}');
        onProgress?.call('Clone failed: ${result.stderr}');
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.instance.logGitOperation('Clone failed', error: e, stackTrace: stackTrace);
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stackTrace');
      onProgress?.call('Clone failed: $e');
      return false;
    }
  }

  Future<bool> pullRepository(String localPath, {Function(String)? onProgress}) async {
    try {
      LoggerService.instance.logGitOperation('Pull repository', details: 'From $localPath');

      onProgress?.call('Pulling latest changes...');

      final result = await Process.run(
        'git',
        ['pull', 'origin'],
        workingDirectory: localPath,
      );

      if (result.exitCode == 0) {
        LoggerService.instance.logGitOperation('Pull successful', details: 'Repository updated from $localPath');
        onProgress?.call('Repository updated successfully');
        return true;
      } else {
        LoggerService.instance.logGitOperation('Pull failed', details: 'Exit code: ${result.exitCode}, Error: ${result.stderr}');
        onProgress?.call('Pull failed: ${result.stderr}');
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.instance.logGitOperation('Pull failed', error: e, stackTrace: stackTrace);
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stackTrace');
      onProgress?.call('Pull failed: $e');
      return false;
    }
  }

  Future<String?> getLatestCommitHash(String localPath) async {
    try {
      final result = await Process.run(
        'git',
        ['rev-parse', 'HEAD'],
        workingDirectory: localPath,
      );
      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      return null;
    } catch (e, stack) {
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stack');
      return null;
    }
  }

  Future<String?> getRemoteCommitHash(String repoUrl, String branch) async {
    try {
      final result = await Process.run(
        'git',
        ['ls-remote', repoUrl, branch],
        workingDirectory: Directory.current.path,
      );
      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          return output.split('\t')[0];
        }
      }
      return null;
    } catch (e, stack) {
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stack');
      return null;
    }
  }

  Future<bool> hasUpdates(String repoUrl, String localPath, String branch) async {
    try {
      final localHash = await getLatestCommitHash(localPath);
      final remoteHash = await getRemoteCommitHash(repoUrl, branch);

      if (localHash == null || remoteHash == null) {
        return false;
      }

      return localHash != remoteHash;
    } catch (e, stack) {
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stack');
      return false;
    }
  }

  Future<bool> isRepositoryInitialized(String localPath) async {
    try {
      final gitDir = Directory('$localPath/.git');
      return gitDir.existsSync();
    } catch (e, stack) {
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stack');
      return false;
    }
  }
}
