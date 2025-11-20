import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/logger_service.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._internal();
  factory ConfigService() => instance;
  ConfigService._internal();

  AppConfig? _config;
  AppConfig? get config => _config;

  Future<void> loadConfig() async {
    try {
      // Load base config from app_settings.json
      final String configString =
          await rootBundle.loadString('assets/config/app_settings.json');
      final Map<String, dynamic> configJson =
          json.decode(configString) as Map<String, dynamic>;
      AppConfig baseConfig = AppConfig.fromJson(configJson);

      // Try to fetch repository config from Google Drive
      final String? googleDriveFileId =
          configJson['google_drive_file_id'] as String?;
      if (googleDriveFileId != null && googleDriveFileId.isNotEmpty) {
        try {
          final GitHubRepo? driveRepo =
              await _fetchRepositoryFromGoogleDrive(googleDriveFileId);
          if (driveRepo != null) {
            // Override with Google Drive config
            _config = AppConfig(
              appName: baseConfig.appName,
              githubRepo: driveRepo,
              localFolder: baseConfig.localFolder,
              backgroundImage: baseConfig.backgroundImage,
              updateCheckInterval: baseConfig.updateCheckInterval,
              exeFileName: baseConfig.exeFileName,
              appIcon: baseConfig.appIcon,
            );
            LoggerService.instance.info(
                'Config loaded with Google Drive repository override',
                tag: 'CONFIG');
            print(
                '[CONFIG] loaded with Google Drive override: ${_config?.toJson()}');
            return;
          }
        } catch (e, stack) {
          LoggerService.instance.warning(
              'Failed to fetch Google Drive config, using app_settings.json',
              tag: 'CONFIG');
          print('[CONFIG][WARNING] Failed to fetch Google Drive config: $e');
          print('[CONFIG][STACK] $stack');
          // Fall through to use base config
        }
      }

      // Use base config from app_settings.json
      _config = baseConfig;
      LoggerService.instance
          .info('Config loaded from app_settings.json', tag: 'CONFIG');
      print('[CONFIG] loaded: ${_config?.toJson()}');
    } catch (e, stack) {
      // No fallbacks. Surface the exception for visibility.
      LoggerService.instance
          .logException('Failed to load config', e, stack, tag: 'CONFIG');
      print('[CONFIG][ERROR] Failed to load config: $e');
      print('[CONFIG][STACK] $stack');
      _config = null;
      rethrow;
    }
  }

  /// Fetches repository configuration from Google Drive file
  /// Returns null if fetch fails or data is invalid
  Future<GitHubRepo?> _fetchRepositoryFromGoogleDrive(String fileId) async {
    try {
      final String fileUrl = 'https://drive.google.com/uc?id=$fileId';
      LoggerService.instance.info(
          'Fetching repository config from Google Drive: $fileUrl',
          tag: 'CONFIG');

      final response = await http.get(
        Uri.parse(fileUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> driveJson =
            json.decode(response.body) as Map<String, dynamic>;

        final Map<String, dynamic>? sources = (driveJson['Sources'] ??
            driveJson['Source']) as Map<String, dynamic>?;
        final Map<String, dynamic>? github =
            (sources?['Github'] ?? sources?['github']) as Map<String, dynamic>?;
        final String? url =
            github != null ? (github['Url'] ?? github['url']) as String? : null;
        final String? branch = github != null
            ? (github['Branch'] ?? github['branch']) as String?
            : null;

        if (url != null &&
            url.isNotEmpty &&
            branch != null &&
            branch.isNotEmpty) {
          LoggerService.instance.info(
              'Successfully fetched repository config from Google Drive: $url (branch: $branch)',
              tag: 'CONFIG');
          return GitHubRepo(url: url, branch: branch);
        }

        LoggerService.instance.warning(
            'Google Drive config missing required Sources.Github fields',
            tag: 'CONFIG');
        return null;
      } else {
        LoggerService.instance.warning(
            'Google Drive fetch failed with status: ${response.statusCode}',
            tag: 'CONFIG');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error fetching Google Drive config', e, stack,
          tag: 'CONFIG');
      print('[CONFIG][ERROR] Google Drive fetch error: $e');
      print('[CONFIG][STACK] $stack');
      return null;
    }
  }

  Future<void> saveConfig(AppConfig newConfig) async {
    _config = newConfig;
  }
}
