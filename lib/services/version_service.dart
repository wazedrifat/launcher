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

  Future<String?> getLatestVersionFromGitHub(String repoUrl) async {
    try {
      LoggerService.instance.info('Fetching latest version from GitHub: $repoUrl', tag: 'VERSION');
      
      // Convert GitHub URL to API URL
      final apiUrl = _convertToApiUrl(repoUrl);
      if (apiUrl == null) {
        LoggerService.instance.error('Invalid GitHub URL: $repoUrl', tag: 'VERSION');
        return null;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> tags = json.decode(response.body);
        if (tags.isNotEmpty) {
          // Sort tags by creation date (newest first)
          tags.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
          
          final latestTag = tags.first['name'] as String;
          LoggerService.instance.info('Latest version found: $latestTag', tag: 'VERSION');
          return latestTag;
        }
      } else {
        LoggerService.instance.error('Failed to fetch tags: ${response.statusCode}', tag: 'VERSION');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.logException('Error fetching latest version', e, stackTrace, tag: 'VERSION');
    }
    return null;
  }

  String? _convertToApiUrl(String repoUrl) {
    try {
      // Handle different GitHub URL formats
      if (repoUrl.startsWith('https://github.com/')) {
        final parts = repoUrl.replaceFirst('https://github.com/', '').split('/');
        if (parts.length >= 2) {
          final owner = parts[0];
          final repo = parts[1].replaceAll('.git', '');
          return 'https://api.github.com/repos/$owner/$repo/tags';
        }
      }
    } catch (e) {
      LoggerService.instance.error('Error converting GitHub URL: $e', tag: 'VERSION');
    }
    return null;
  }

  bool isUpdateAvailable(String currentVersion, String latestVersion) {
    try {
      final current = _parseVersion(currentVersion);
      final latest = _parseVersion(latestVersion);
      
      if (current == null || latest == null) return false;
      
      // Compare major.minor.patch versions
      for (int i = 0; i < 3; i++) {
        if (latest[i] > current[i]) return true;
        if (latest[i] < current[i]) return false;
      }
      return false;
    } catch (e) {
      LoggerService.instance.error('Error comparing versions: $e', tag: 'VERSION');
      return false;
    }
  }

  List<int>? _parseVersion(String version) {
    try {
      // Remove 'v' prefix if present
      final cleanVersion = version.startsWith('v') ? version.substring(1) : version;
      
      // Split by dots and convert to integers
      final parts = cleanVersion.split('.');
      if (parts.length >= 3) {
        return [
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ];
      }
    } catch (e) {
      LoggerService.instance.error('Error parsing version: $e', tag: 'VERSION');
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
