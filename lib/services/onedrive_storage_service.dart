import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/archive_service.dart';
import 'package:launcher/services/credential_storage_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/oauth2_service.dart';
import 'package:launcher/services/storage_service.dart';

/// OneDrive implementation of StorageService
/// Uses Microsoft Graph API to manage file downloads and updates
/// Works with free OneDrive personal accounts
class OneDriveStorageService extends StorageService {
  final OneDriveConfig _config;
  String? _accessToken;

  OneDriveStorageService(this._config);

  /// Initialize OneDrive authentication
  Future<bool> _authenticate() async {
    try {
      if (_config.clientId.isEmpty) {
        LoggerService.instance
            .error('OneDrive client ID not configured', tag: 'ONEDRIVE');
        return false;
      }

      // Check if we have stored credentials
      final credentials = await CredentialStorageService.instance
          .getCredentials(StorageType.oneDrive);

      if (credentials == null) {
        LoggerService.instance.info(
            'No OneDrive credentials found. Triggering OAuth2 authentication.',
            tag: 'ONEDRIVE');
        return await authenticateUser();
      }

      // Check if token is expired
      if (CredentialStorageService.instance.isTokenExpired(credentials)) {
        LoggerService.instance.info(
            'OneDrive token expired. Attempting refresh.',
            tag: 'ONEDRIVE');
        return await _refreshToken(credentials);
      }

      _accessToken = credentials['access_token'] as String?;
      return _accessToken != null;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'OneDrive authentication failed', e, stack,
          tag: 'ONEDRIVE');
      return false;
    }
  }

  /// Refresh expired access token
  Future<bool> _refreshToken(Map<String, dynamic> credentials) async {
    try {
      final refreshToken = credentials['refresh_token'] as String?;
      if (refreshToken == null) {
        LoggerService.instance
            .error('No refresh token available for OneDrive', tag: 'ONEDRIVE');
        return false;
      }

      return await OAuth2Service.instance.refreshOneDriveToken(credentials);
    } catch (e, stack) {
      LoggerService.instance.logException(
          'OneDrive token refresh failed', e, stack,
          tag: 'ONEDRIVE');
      return false;
    }
  }

  /// Trigger OAuth2 authentication flow for OneDrive
  Future<bool> authenticateUser() async {
    try {
      LoggerService.instance.info(
          'Starting OneDrive OAuth2 authentication flow',
          tag: 'ONEDRIVE');

      final success =
          await OAuth2Service.instance.authenticateOneDrive(_config.clientId);

      if (success) {
        // Reload credentials after successful authentication
        final credentials = await CredentialStorageService.instance
            .getCredentials(StorageType.oneDrive);
        _accessToken = credentials?['access_token'] as String?;
      }

      return success;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'OneDrive OAuth2 flow failed', e, stack,
          tag: 'ONEDRIVE');
      return false;
    }
  }

  /// Get file metadata from OneDrive using Microsoft Graph API
  Future<Map<String, dynamic>?> _getFileMetadata(String fileName) async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return null;
      }

      // Use Microsoft Graph API to search for files
      // For personal OneDrive, we can use /me/drive/root/children or search
      final encodedPath =
          Uri.encodeComponent('${_config.folderPath}/$fileName');
      final response = await http.get(
        Uri.parse(
            'https://graph.microsoft.com/v1.0/me/drive/root:$encodedPath'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 404) {
        // File not found
        LoggerService.instance
            .info('File not found: $fileName', tag: 'ONEDRIVE');
        return null;
      } else {
        LoggerService.instance.error(
            'Failed to get file metadata: ${response.statusCode} ${response.body}',
            tag: 'ONEDRIVE');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error getting file metadata', e, stack,
          tag: 'ONEDRIVE');
      return null;
    }
  }

  /// Download file from OneDrive
  Future<bool> _downloadFile(String downloadUrl, String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return false;
      }

      onProgress?.call('Downloading from OneDrive...', 0.0);

      final response = await http.get(
        Uri.parse(downloadUrl),
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
        LoggerService.instance.info(
            'File downloaded successfully to $localPath',
            tag: 'ONEDRIVE');
        return true;
      } else {
        LoggerService.instance.error(
            'Failed to download file: ${response.statusCode}',
            tag: 'ONEDRIVE');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error downloading file', e, stack, tag: 'ONEDRIVE');
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
          tag: 'ONEDRIVE');
      return null;
    }
  }

  /// Create folder structure in OneDrive if it doesn't exist
  Future<bool> _ensureFolderExists() async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return false;
      }

      // Check if folder exists, create if not
      final encodedPath = Uri.encodeComponent(_config.folderPath);
      final response = await http.get(
        Uri.parse(
            'https://graph.microsoft.com/v1.0/me/drive/root:$encodedPath'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return true; // Folder exists
      } else if (response.statusCode == 404) {
        // Folder doesn't exist, try to create it
        LoggerService.instance.info(
            'OneDrive folder not found, you may need to create it manually: ${_config.folderPath}',
            tag: 'ONEDRIVE');
        return false;
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error ensuring folder exists', e, stack,
          tag: 'ONEDRIVE');
      return false;
    }
  }

  @override
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      onProgress?.call('Connecting to OneDrive...', 0.1);

      if (!await _ensureFolderExists()) {
        LoggerService.instance.error(
            'OneDrive folder does not exist: ${_config.folderPath}',
            tag: 'ONEDRIVE');
        return false;
      }

      // Look for app files (zip or executable)
      final metadata = await _getFileMetadata('app.zip');
      if (metadata == null) {
        LoggerService.instance
            .error('No app.zip found in OneDrive folder', tag: 'ONEDRIVE');
        return false;
      }

      final downloadUrl = metadata['@microsoft.graph.downloadUrl'] as String?;
      if (downloadUrl == null) {
        LoggerService.instance
            .error('No download URL available for file', tag: 'ONEDRIVE');
        return false;
      }

      final zipPath = '$localPath/app.zip';
      if (await _downloadFile(downloadUrl, zipPath, onProgress: onProgress)) {
        onProgress?.call('Extracting files...', 0.8);

        // Extract zip file
        LoggerService.instance.info(
            'Downloaded app.zip, starting extraction to $localPath',
            tag: 'ONEDRIVE');

        final extractSuccess = await ArchiveService.instance.extractZipFile(
          zipPath,
          localPath,
          onProgress: onProgress,
        );

        // Clean up temporary zip file
        await ArchiveService.instance.cleanupTempFile(zipPath);

        if (extractSuccess) {
          LoggerService.instance.info(
              'Successfully downloaded and extracted app.zip to $localPath',
              tag: 'ONEDRIVE');
          return true;
        } else {
          LoggerService.instance
              .error('Failed to extract downloaded app.zip', tag: 'ONEDRIVE');
          return false;
        }
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Download repository failed', e, stack,
          tag: 'ONEDRIVE');
      return false;
    }
  }

  @override
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    // For OneDrive, update is the same as download
    return await downloadRepository(localPath, onProgress: onProgress);
  }

  @override
  Future<bool> hasUpdates(String localPath) async {
    try {
      final metadata = await _getFileMetadata('app.zip');
      if (metadata == null) return false;

      final remoteModified = metadata['lastModifiedDateTime'] as String?;
      if (remoteModified == null) return false;

      final localHash = await _getLocalFileHash('$localPath/app.zip');
      if (localHash == null) {
        return true; // No local file means update available
      }

      final remoteTime = DateTime.parse(remoteModified);
      final localTime =
          DateTime.fromMillisecondsSinceEpoch(int.parse(localHash));

      return remoteTime.isAfter(localTime);
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error checking for updates', e, stack,
          tag: 'ONEDRIVE');
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
          tag: 'ONEDRIVE');
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
      return metadata?['lastModifiedDateTime'] as String?;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error getting remote version', e, stack,
          tag: 'ONEDRIVE');
      return null;
    }
  }

  @override
  String get sourceDescription => 'OneDrive (Folder: ${_config.folderPath})';
}
