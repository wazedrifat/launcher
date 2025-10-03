import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/credential_storage_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/oauth2_service.dart';
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
            'No Google Drive credentials found. Triggering OAuth2 authentication.',
            tag: 'DRIVE');
        return await authenticateUser();
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

      return await OAuth2Service.instance.refreshGoogleDriveToken(credentials);
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
      LoggerService.instance.info(
          'Starting Google Drive OAuth2 authentication flow',
          tag: 'DRIVE');

      // Note: This requires a client secret for OAuth2 flow
      // In a real app, you might want to use a different flow or store client secret securely
      const clientSecret = ''; // This should be configured or obtained securely

      if (clientSecret.isEmpty) {
        LoggerService.instance.error(
            'Google Drive client secret not configured. OAuth2 authentication requires both client ID and secret.',
            tag: 'DRIVE');
        return false;
      }

      final success = await OAuth2Service.instance.authenticateGoogleDrive(
        _config.clientId,
        clientSecret,
      );

      if (success) {
        // Reload credentials after successful authentication
        final credentials = await CredentialStorageService.instance
            .getCredentials(StorageType.googleDrive);
        _accessToken = credentials?['access_token'] as String?;
      }

      return success;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Google Drive OAuth2 flow failed', e, stack,
          tag: 'DRIVE');
      return false;
    }
  }

  /// Download file from Google Drive
  Future<bool> _downloadFile(String fileId, String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return false;
      }

      onProgress?.call('Downloading file...', 0.0);

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

      if (_accessToken == null && !await _authenticate()) {
        return false;
      }

      onProgress?.call('Listing folder contents...', 0.2);

      // Get all files in the folder
      final files = await _listFolderContents();
      if (files == null || files.isEmpty) {
        LoggerService.instance
            .error('No files found in Google Drive folder', tag: 'DRIVE');
        return false;
      }

      final totalFiles = files.length;
      int downloadedFiles = 0;

      for (final file in files) {
        final fileName = file['name'] as String;
        final fileId = file['id'] as String;

        onProgress?.call('Downloading $fileName...',
            0.2 + (0.7 * (downloadedFiles / totalFiles)));

        // Create the full local path for this file
        final fileLocalPath = '$localPath/$fileName';

        if (await _downloadFile(fileId, fileLocalPath)) {
          downloadedFiles++;
          LoggerService.instance
              .info('Downloaded $fileName successfully', tag: 'DRIVE');
        } else {
          LoggerService.instance
              .error('Failed to download $fileName', tag: 'DRIVE');
          return false;
        }
      }

      onProgress?.call('Download completed', 1.0);
      LoggerService.instance.info(
          'Successfully downloaded $downloadedFiles/$totalFiles files to $localPath',
          tag: 'DRIVE');
      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Download repository failed', e, stack, tag: 'DRIVE');
      return false;
    }
  }

  /// List all files in the configured Google Drive folder
  Future<List<Map<String, dynamic>>?> _listFolderContents() async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return null;
      }

      final response = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeComponent("'${_config.folderId}' in parents")}&fields=files(id,name,modifiedTime,md5Checksum)'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final files = data['files'] as List;
        return files.cast<Map<String, dynamic>>();
      } else {
        LoggerService.instance.error(
            'Failed to list folder contents: ${response.statusCode} ${response.body}',
            tag: 'DRIVE');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error listing folder contents', e, stack,
          tag: 'DRIVE');
      return null;
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
      final files = await _listFolderContents();
      if (files == null || files.isEmpty) return false;

      // Check each file to see if it's newer than the local version
      for (final file in files) {
        final fileName = file['name'] as String;
        final remoteModified = file['modifiedTime'] as String?;

        if (remoteModified == null) continue;

        final localFilePath = '$localPath/$fileName';
        final localHash = await _getLocalFileHash(localFilePath);

        if (localHash == null) return true; // File doesn't exist locally

        final remoteTime = DateTime.parse(remoteModified);
        final localTime =
            DateTime.fromMillisecondsSinceEpoch(int.parse(localHash));

        if (remoteTime.isAfter(localTime)) {
          return true; // File has been updated
        }
      }

      return false; // No updates found
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

      // Check if there are any files in the directory
      final files = await directory.list().toList();
      return files.isNotEmpty;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error checking repository initialization', e, stack,
          tag: 'DRIVE');
      return false;
    }
  }

  @override
  Future<String?> getLatestVersion(String localPath) async {
    try {
      final directory = Directory(localPath);
      if (!await directory.exists()) return null;

      // Find the latest modification time among all local files
      DateTime? latestModified;

      await for (final file in directory.list(recursive: true)) {
        if (file is File) {
          final stat = await file.stat();
          if (latestModified == null || stat.modified.isAfter(latestModified)) {
            latestModified = stat.modified;
          }
        }
      }

      return latestModified?.toIso8601String();
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error getting latest version', e, stack, tag: 'DRIVE');
      return null;
    }
  }

  @override
  Future<String?> getRemoteVersion() async {
    try {
      final files = await _listFolderContents();
      if (files == null || files.isEmpty) return null;

      // Find the latest modification time among all files
      DateTime? latestModified;

      for (final file in files) {
        final modifiedTime = file['modifiedTime'] as String?;
        if (modifiedTime != null) {
          final modifiedDateTime = DateTime.parse(modifiedTime);
          if (latestModified == null ||
              modifiedDateTime.isAfter(latestModified)) {
            latestModified = modifiedDateTime;
          }
        }
      }

      return latestModified?.toIso8601String();
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
