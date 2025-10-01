import 'dart:convert';

// import 'package:flutter_secure_storage/flutter_secure_storage.dart';  // Temporarily disabled
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/logger_service.dart';

/// Unified credential storage service using Flutter's secure storage
/// Handles OAuth tokens and authentication data for all storage providers
class CredentialStorageService {
  static final CredentialStorageService instance =
      CredentialStorageService._internal();
  factory CredentialStorageService() => instance;
  CredentialStorageService._internal();

  // Temporary stub - replace with actual secure storage implementation
  static final Map<String, String> _tempStorage = <String, String>{};

  /// Storage keys for different providers
  static const String _keyPrefix = 'launcher_storage_';

  String _getStorageKey(StorageType type) {
    return '$_keyPrefix${type.value}';
  }

  /// Save credentials for a storage provider
  Future<void> saveCredentials(
      StorageType type, Map<String, dynamic> credentials) async {
    try {
      final key = _getStorageKey(type);
      final credentialsJson = json.encode(credentials);
      _tempStorage[key] = credentialsJson;

      LoggerService.instance.info(
          'Credentials saved successfully for ${type.value} (TEMP STORAGE)',
          tag: 'CREDENTIALS');
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Failed to save credentials for ${type.value}', e, stack,
          tag: 'CREDENTIALS');
      rethrow;
    }
  }

  /// Get credentials for a storage provider
  Future<Map<String, dynamic>?> getCredentials(StorageType type) async {
    try {
      final key = _getStorageKey(type);
      final credentialsJson = _tempStorage[key];

      if (credentialsJson == null) {
        LoggerService.instance
            .info('No credentials found for ${type.value}', tag: 'CREDENTIALS');
        return null;
      }

      final credentials = json.decode(credentialsJson) as Map<String, dynamic>;
      LoggerService.instance.info(
          'Credentials loaded successfully for ${type.value} (TEMP STORAGE)',
          tag: 'CREDENTIALS');

      return credentials;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Failed to load credentials for ${type.value}', e, stack,
          tag: 'CREDENTIALS');
      return null;
    }
  }

  /// Check if credentials exist for a storage provider
  Future<bool> hasCredentials(StorageType type) async {
    try {
      final credentials = await getCredentials(type);
      return credentials != null;
    } catch (e) {
      return false;
    }
  }

  /// Remove credentials for a storage provider
  Future<void> removeCredentials(StorageType type) async {
    try {
      final key = _getStorageKey(type);
      _tempStorage.remove(key);

      LoggerService.instance.info(
          'Credentials removed successfully for ${type.value} (TEMP STORAGE)',
          tag: 'CREDENTIALS');
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Failed to remove credentials for ${type.value}', e, stack,
          tag: 'CREDENTIALS');
      rethrow;
    }
  }

  /// Clear all stored credentials (useful for logout/reset)
  Future<void> clearAllCredentials() async {
    try {
      final launcherKeys =
          _tempStorage.keys.where((key) => key.startsWith(_keyPrefix)).toList();

      for (final key in launcherKeys) {
        _tempStorage.remove(key);
      }

      LoggerService.instance
          .info('All credentials cleared successfully (TEMP STORAGE)', tag: 'CREDENTIALS');
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Failed to clear all credentials', e, stack,
          tag: 'CREDENTIALS');
      rethrow;
    }
  }

  /// Update specific credential fields (useful for token refresh)
  Future<void> updateCredentials(
      StorageType type, Map<String, dynamic> updates) async {
    try {
      final existing = await getCredentials(type) ?? <String, dynamic>{};
      existing.addAll(updates);
      await saveCredentials(type, existing);

      LoggerService.instance.info(
          'Credentials updated successfully for ${type.value}',
          tag: 'CREDENTIALS');
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Failed to update credentials for ${type.value}', e, stack,
          tag: 'CREDENTIALS');
      rethrow;
    }
  }

  /// Get access token for OAuth-based providers
  Future<String?> getAccessToken(StorageType type) async {
    final credentials = await getCredentials(type);
    return credentials?['access_token'] as String?;
  }

  /// Get refresh token for OAuth-based providers
  Future<String?> getRefreshToken(StorageType type) async {
    final credentials = await getCredentials(type);
    return credentials?['refresh_token'] as String?;
  }

  /// Check if access token is expired
  bool isTokenExpired(Map<String, dynamic> credentials) {
    final expiresAt = credentials['expires_at'] as String?;
    if (expiresAt == null) return false;

    try {
      final expireTime = DateTime.parse(expiresAt);
      return DateTime.now().isAfter(expireTime);
    } catch (e) {
      return false;
    }
  }

  /// Save OAuth2 credentials with expiration calculation
  Future<void> saveOAuth2Credentials(
    StorageType type,
    String accessToken,
    String? refreshToken,
    int expiresIn, {
    Map<String, dynamic>? additionalData,
  }) async {
    final credentials = <String, dynamic>{
      'access_token': accessToken,
      'token_type': 'Bearer',
      'expires_in': expiresIn,
      'expires_at':
          DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    if (refreshToken != null) {
      credentials['refresh_token'] = refreshToken;
    }

    if (additionalData != null) {
      credentials.addAll(additionalData);
    }

    await saveCredentials(type, credentials);
  }
}
