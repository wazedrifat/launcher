import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:launcher/models/app_config.dart';

class ConfigService {
  static final ConfigService instance = ConfigService._internal();
  factory ConfigService() => instance;
  ConfigService._internal();

  AppConfig? _config;
  AppConfig? get config => _config;

  Future<void> loadConfig() async {
    try {
      final String configString = await rootBundle.loadString('assets/config/app_settings.json');
      final Map<String, dynamic> configJson = json.decode(configString);
      _config = AppConfig.fromJson(configJson);
      print("--------------------config: ${_config?.toJson()}");
    } catch (e) {
      // Fallback to default config if file loading fails
      print("--------------------exception: $e");
      _config = AppConfig(
        appName: 'Launcher App',
        githubRepo: GitHubRepo(
          url: 'https://github.com/username/repository-name',
          branch: 'main',
        ),
        localFolder: 'C:\\Users\\User\\Documents\\GitHub\\repository-name',
        backgroundImage: 'assets/images/bg.jpg',
        updateCheckInterval: 300000,
        exeFilePattern: '*.exe',
      );
    }
  }

  Future<void> saveConfig(AppConfig newConfig) async {
    _config = newConfig;
    // In a real app, you might want to save this back to the file
  }
}
