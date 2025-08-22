import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/credential_storage_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/storage_service.dart';

/// Google Drive implementation of StorageService
/// Uses Google Drive API to manage file downloads and updates
class GoogleDriveStorageService extends StorageService {
  final GoogleDriveConfig _config;
  String? _accessToken;

  GoogleDriveStorageService(this._config);

  /// Initialize Google Drive authentication
  Future<bool> _authenticate() async {
    try {
      if (_config.clientId.isEmpty) {
        LoggerService.instance
            .error('Google Drive client ID not configured', tag: 'DRIVE');
        return false;
      }

      // Check if we have stored credentials
      final credentials = await CredentialStorageService.instance
          .getCredentials(StorageType.googleDrive);

      if (credentials == null) {
        LoggerService.instance.info(
            'No Google Drive credentials found. User needs to authenticate.',
            tag: 'DRIVE');
        // TODO: Trigger OAuth2 flow in UI
        return false;
      }

      // Check if token is expired
      if (CredentialStorageService.instance.isTokenExpired(credentials)) {
        LoggerService.instance.info(
            'Google Drive token expired. Attempting refresh.',
            tag: 'DRIVE');
        return await _refreshToken(credentials);
      }

      _accessToken = credentials['access_token'] as String?;
      return _accessToken != null;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Google Drive authentication failed', e, stack,
          tag: 'DRIVE');
      return false;
    }
  }

  /// Refresh expired access token
  Future<bool> _refreshToken(Map<String, dynamic> credentials) async {
    try {
      final refreshToken = credentials['refresh_token'] as String?;
      if (refreshToken == null) {
        LoggerService.instance
            .error('No refresh token available for Google Drive', tag: 'DRIVE');
        return false;
      }

      // TODO: Implement token refresh with Google OAuth2
      // For now, just return false to trigger re-authentication
      LoggerService.instance.info(
          'Token refresh not yet implemented. User needs to re-authenticate.',
          tag: 'DRIVE');
      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Google Drive token refresh failed', e, stack,
          tag: 'DRIVE');
      return false;
    }
  }

  /// Trigger OAuth2 authentication flow
  /// This should be called from the UI when user wants to connect Google Drive
  Future<bool> authenticateUser() async {
    try {
      // TODO: Implement OAuth2 flow
      // This is a placeholder for the actual OAuth2 implementation
      LoggerService.instance
          .info('OAuth2 flow should be implemented here', tag: 'DRIVE');

      // For demo purposes, return false
      // In real implementation, this would:
      // 1. Open OAuth2 authorization URL
      // 2. Handle callback with authorization code
      // 3. Exchange code for access/refresh tokens
      // 4. Store tokens using CredentialStorageService

      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Google Drive OAuth2 flow failed', e, stack,
          tag: 'DRIVE');
      return false;
    }
  }

  /// Get file metadata from Google Drive
  Future<Map<String, dynamic>?> _getFileMetadata(String fileName) async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return null;
      }

      final query = "'${_config.folderId}' in parents and name='$fileName'";
      final response = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeComponent(query)}&fields=files(id,name,modifiedTime,md5Checksum)'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final files = data['files'] as List;
        return files.isNotEmpty ? files.first : null;
      } else {
        LoggerService.instance.error(
            'Failed to get file metadata: ${response.statusCode} ${response.body}',
            tag: 'DRIVE');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error getting file metadata', e, stack, tag: 'DRIVE');
      return null;
    }
  }

  /// Download file from Google Drive
  Future<bool> _downloadFile(String fileId, String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return false;
      }

      onProgress?.call('Downloading from Google Drive...', 0.0);

      final response = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files/$fileId?alt=media'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        onProgress?.call('Saving file...', 0.7);

        final file = File(localPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);

        onProgress?.call('Download completed', 1.0);
        LoggerService.instance
            .info('File downloaded successfully to $localPath', tag: 'DRIVE');
        return true;
      } else {
        LoggerService.instance.error(
            'Failed to download file: ${response.statusCode}',
            tag: 'DRIVE');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error downloading file', e, stack, tag: 'DRIVE');
      return false;
    }
  }

  /// Get local file hash for comparison
  Future<String?> _getLocalFileHash(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      // For simplicity, use file modification time as version identifier
      final stat = await file.stat();
      return stat.modified.millisecondsSinceEpoch.toString();
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error getting local file hash', e, stack,
          tag: 'DRIVE');
      return null;
    }
  }

  @override
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      onProgress?.call('Connecting to Google Drive...', 0.1);

      // For apps, we'll look for a zip file with the same name as the exe
      final directory = Directory(localPath);
      final exeFiles =
          directory.listSync().where((f) => f.path.endsWith('.exe')).toList();

      if (exeFiles.isEmpty) {
        // Look for a default zip file
        final metadata = await _getFileMetadata('app.zip');
        if (metadata == null) {
          LoggerService.instance
              .error('No app files found in Google Drive folder', tag: 'DRIVE');
          return false;
        }

        final zipPath = '$localPath/app.zip';
        if (await _downloadFile(metadata['id'], zipPath,
            onProgress: onProgress)) {
          onProgress?.call('Extracting files...', 0.8);
          // TODO: Extract zip file
          // For now, assume the zip contains the executable directly
          return true;
        }
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Download repository failed', e, stack, tag: 'DRIVE');
      return false;
    }
  }

  @override
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    // For Google Drive, update is the same as download
    return await downloadRepository(localPath, onProgress: onProgress);
  }

  @override
  Future<bool> hasUpdates(String localPath) async {
    try {
      final metadata = await _getFileMetadata('app.zip');
      if (metadata == null) return false;

      final remoteModified = metadata['modifiedTime'] as String?;
      if (remoteModified == null) return false;

      final localHash = await _getLocalFileHash('$localPath/app.zip');
      if (localHash == null)
        return true; // No local file means update available

      final remoteTime = DateTime.parse(remoteModified);
      final localTime =
          DateTime.fromMillisecondsSinceEpoch(int.parse(localHash));

      return remoteTime.isAfter(localTime);
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error checking for updates', e, stack, tag: 'DRIVE');
      return false;
    }
  }

  @override
  Future<bool> isRepositoryInitialized(String localPath) async {
    try {
      final directory = Directory(localPath);
      if (!await directory.exists()) return false;

      // Check if there are any executable files
      final files = directory.listSync();
      return files
          .any((f) => f.path.endsWith('.exe') || f.path.endsWith('.zip'));
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error checking repository initialization', e, stack,
          tag: 'DRIVE');
      return false;
    }
  }

  @override
  Future<String?> getLatestVersion(String localPath) async {
    return await _getLocalFileHash('$localPath/app.zip');
  }

  @override
  Future<String?> getRemoteVersion() async {
    try {
      final metadata = await _getFileMetadata('app.zip');
      return metadata?['modifiedTime'] as String?;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error getting remote version', e, stack, tag: 'DRIVE');
      return null;
    }
  }

  @override
  String get sourceDescription =>
      'Google Drive (Folder ID: ${_config.folderId})';
}
