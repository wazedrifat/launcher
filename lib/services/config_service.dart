import 'dart:convert';
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
			final Map<String, dynamic> configJson = json.decode(configString) as Map<String, dynamic>;
			_config = AppConfig.fromJson(configJson);
			print('[CONFIG] loaded: ${_config?.toJson()}');
		} catch (e, stack) {
			// No fallbacks. Surface the exception for visibility.
			print('[CONFIG][ERROR] Failed to load config: $e');
			print('[CONFIG][STACK] $stack');
			_config = null;
			rethrow;
		}
	}

	Future<void> saveConfig(AppConfig newConfig) async {
		_config = newConfig;
	}
}
