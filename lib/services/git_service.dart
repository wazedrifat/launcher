import 'dart:convert';
import 'dart:io';
import 'package:launcher/services/logger_service.dart';

class GitService {
  static final GitService instance = GitService._internal();
  factory GitService() => instance;
  GitService._internal();

  Future<void> _ensureDir(String path) async {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        LoggerService.instance.logGitOperation('Create directory', details: path);
        await dir.create(recursive: true);
      }
    } catch (e, stack) {
      LoggerService.instance.logGitOperation('Create directory failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<bool> cloneRepository(String repoUrl, String localPath, String branch, {Function(String, double?)? onProgress}) async {
    try {
      await _ensureDir(localPath);
      LoggerService.instance.logGitOperation('Clone repository', details: 'From $repoUrl to $localPath (branch: $branch)');
      onProgress?.call('Starting clone...', 0.0);

      final process = await Process.start(
        'git',
        ['-c', 'core.longpaths=true', 'clone', '--progress', '-b', branch, repoUrl, localPath],
        workingDirectory: Directory.current.path,
        runInShell: true,
      );

      final percentReg = RegExp(r'(\d+)%');
      process.stderr.transform(const SystemEncoding().decoder).transform(const LineSplitter()).listen((line) {
        LoggerService.instance.logGitOperation('clone: $line');
        double? p;
        final m = percentReg.firstMatch(line);
        if (m != null) {
          final val = int.tryParse(m.group(1)!);
          if (val != null) p = val / 100.0;
        }
        onProgress?.call(line, p);
      });
      process.stdout.transform(const SystemEncoding().decoder).transform(const LineSplitter()).listen((line) {
        LoggerService.instance.logGitOperation('clone(out): $line');
      });

      final exit = await process.exitCode;
      if (exit == 0) {
        onProgress?.call('Repository cloned successfully', 1.0);
        LoggerService.instance.logGitOperation('Clone successful', details: 'Repository cloned to $localPath');
        return true;
      } else {
        final err = await process.stderr.transform(const SystemEncoding().decoder).join();
        onProgress?.call('Clone failed: $err', null);
        LoggerService.instance.logGitOperation('Clone failed', details: 'Exit code: $exit, Error: $err');
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.instance.logGitOperation('Clone failed', error: e, stackTrace: stackTrace);
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stackTrace');
      onProgress?.call('Clone failed: $e', null);
      return false;
    }
  }

  Future<bool> pullRepository(String localPath, {Function(String, double?)? onProgress}) async {
    try {
      await _ensureDir(localPath);
      LoggerService.instance.logGitOperation('Pull repository', details: 'From $localPath');
      onProgress?.call('Fetching latest changes...', 0.0);

      final process = await Process.start(
        'git',
        ['-c', 'core.longpaths=true', 'pull', '--progress', 'origin'],
        workingDirectory: localPath,
        runInShell: true,
      );

      final percentReg = RegExp(r'(\d+)%');
      process.stderr.transform(const SystemEncoding().decoder).transform(const LineSplitter()).listen((line) {
        LoggerService.instance.logGitOperation('pull: $line');
        double? p;
        final m = percentReg.firstMatch(line);
        if (m != null) {
          final val = int.tryParse(m.group(1)!);
          if (val != null) p = val / 100.0;
        }
        onProgress?.call(line, p);
      });
      process.stdout.transform(const SystemEncoding().decoder).transform(const LineSplitter()).listen((line) {
        LoggerService.instance.logGitOperation('pull(out): $line');
      });

      final exit = await process.exitCode;
      if (exit == 0) {
        onProgress?.call('Repository updated successfully', 1.0);
        LoggerService.instance.logGitOperation('Pull successful', details: 'Repository updated from $localPath');
        return true;
      } else {
        final err = await process.stderr.transform(const SystemEncoding().decoder).join();
        onProgress?.call('Pull failed: $err', null);
        LoggerService.instance.logGitOperation('Pull failed', details: 'Exit code: $exit, Error: $err');
        return false;
      }
    } catch (e, stackTrace) {
      LoggerService.instance.logGitOperation('Pull failed', error: e, stackTrace: stackTrace);
      print('[GIT][ERROR] $e');
      print('[GIT][STACK] $stackTrace');
      onProgress?.call('Pull failed: $e', null);
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
