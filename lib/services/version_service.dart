import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:launcher/services/logger_service.dart';

class VersionService {
  static final VersionService instance = VersionService._internal();
  factory VersionService() => instance;
  VersionService._internal();

  static const String _currentVersion = '1.0.0';
  static const String _buildNumber = '1';

  String get currentVersion => _currentVersion;
  String get buildNumber => _buildNumber;
  String get fullVersion => 'v$_currentVersion+$_buildNumber';

  // Returns the latest tag that exists LOCALLY in the repo at localPath
  Future<String?> getLocalLatestTag(String localPath) async {
    try {
      // Prefer `git describe` and fall back to `git tag` if no annotated tags
      final describe = await Process.run(
        'git',
        ['describe', '--tags', '--abbrev=0'],
        workingDirectory: localPath,
      );
      if (describe.exitCode == 0) {
        final tag = describe.stdout.toString().trim();
        if (tag.isNotEmpty) {
          LoggerService.instance.info('Local latest tag (describe): $tag', tag: 'VERSION');
          return tag;
        }
      }

      final listTags = await Process.run(
        'git',
        ['tag', '--sort=-creatordate'],
        workingDirectory: localPath,
      );
      if (listTags.exitCode == 0) {
        final lines = listTags.stdout.toString().trim().split('\n');
        if (lines.isNotEmpty && lines.first.trim().isNotEmpty) {
          final tag = lines.first.trim();
          LoggerService.instance.info('Local latest tag (list): $tag', tag: 'VERSION');
          return tag;
        }
      }
    } catch (e, stack) {
      LoggerService.instance.logException('Error reading local tag', e, stack, tag: 'VERSION');
      print('[VERSION][ERROR] $e');
      print('[VERSION][STACK] $stack');
    }
    return null;
  }

  // Kept for remote checks, but UI will not use this to render version until update/clone
  Future<String?> getLatestVersionFromGitHub(String repoUrl) async {
    try {
      LoggerService.instance.info('Fetching latest version from GitHub: $repoUrl', tag: 'VERSION');

      final apiUrl = _convertToApiUrl(repoUrl);
      if (apiUrl == null) {
        LoggerService.instance.error('Invalid GitHub URL: $repoUrl', tag: 'VERSION');
        return null;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> tags = json.decode(response.body) as List<dynamic>;
        if (tags.isNotEmpty) {
          final latestTag = (tags.first as Map<String, dynamic>)['name'] as String;
          LoggerService.instance.info('Latest version found: $latestTag', tag: 'VERSION');
          return latestTag;
        }
      } else {
        LoggerService.instance.error('Failed to fetch tags: ${response.statusCode}', tag: 'VERSION');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.logException('Error fetching latest version', e, stackTrace, tag: 'VERSION');
      print('[VERSION][ERROR] $e');
      print('[VERSION][STACK] $stackTrace');
    }
    return null;
  }

  String? _convertToApiUrl(String repoUrl) {
    try {
      if (repoUrl.startsWith('https://github.com/')) {
        final parts = repoUrl.replaceFirst('https://github.com/', '').split('/');
        if (parts.length >= 2) {
          final owner = parts[0];
          final repo = parts[1].replaceAll('.git', '');
          return 'https://api.github.com/repos/$owner/$repo/tags';
        }
      }
    } catch (e, stack) {
      LoggerService.instance.error('Error converting GitHub URL: $e', tag: 'VERSION');
      print('[VERSION][STACK] $stack');
    }
    return null;
  }

  bool isUpdateAvailable(String currentVersion, String latestVersion) {
    try {
      final current = _parseVersion(currentVersion);
      final latest = _parseVersion(latestVersion);

      if (current == null || latest == null) return false;

      for (int i = 0; i < 3; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      return false;
    } catch (e, stack) {
      LoggerService.instance.error('Error comparing versions: $e', tag: 'VERSION');
      print('[VERSION][STACK] $stack');
      return false;
    }
  }

  List<int>? _parseVersion(String version) {
    try {
      final cleanVersion = version.startsWith('v') ? version.substring(1) : version;
      final parts = cleanVersion.split('.');
      if (parts.length >= 3) {
        return [
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ];
      }
    } catch (e, stack) {
      LoggerService.instance.error('Error parsing version: $e', tag: 'VERSION');
      print('[VERSION][STACK] $stack');
    }
    return null;
  }

  String getVersionDisplayText() {
    return 'v$_currentVersion';
  }

  String getFullVersionInfo() {
    return 'Version $_currentVersion (Build $_buildNumber)';
  }
}
