import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/credential_storage_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/storage_service.dart';

/// Dropbox implementation of StorageService
/// Uses Dropbox API v2 to manage file downloads and updates
/// Works with free Dropbox accounts (2GB+ free storage)
class DropboxStorageService extends StorageService {
  final DropboxConfig _config;
  String? _accessToken;

  DropboxStorageService(this._config);

  /// Initialize Dropbox authentication
  Future<bool> _authenticate() async {
    try {
      if (_config.appKey.isEmpty) {
        LoggerService.instance
            .error('Dropbox app key not configured', tag: 'DROPBOX');
        return false;
      }

      // Check if we have stored credentials
      final credentials = await CredentialStorageService.instance
          .getCredentials(StorageType.dropbox);

      if (credentials == null) {
        LoggerService.instance.info(
            'No Dropbox credentials found. User needs to authenticate.',
            tag: 'DROPBOX');
        return false;
      }

      _accessToken = credentials['access_token'] as String?;
      return _accessToken != null;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Dropbox authentication failed', e, stack,
          tag: 'DROPBOX');
      return false;
    }
  }

  /// Trigger OAuth2 authentication flow for Dropbox
  Future<bool> authenticateUser() async {
    try {
      // TODO: Implement Dropbox OAuth2 flow
      LoggerService.instance.info(
          'Dropbox OAuth2 flow should be implemented here',
          tag: 'DROPBOX');
      return false;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Dropbox OAuth2 flow failed', e, stack, tag: 'DROPBOX');
      return false;
    }
  }

  /// Get file metadata from Dropbox
  Future<Map<String, dynamic>?> _getFileMetadata(String fileName) async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return null;
      }

      final filePath = '${_config.folderPath}/$fileName';
      final response = await http.post(
        Uri.parse('https://api.dropboxapi.com/2/files/get_metadata'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'path': filePath,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 409) {
        // File not found (path/not_found)
        LoggerService.instance
            .info('File not found: $fileName', tag: 'DROPBOX');
        return null;
      } else {
        LoggerService.instance.error(
            'Failed to get file metadata: ${response.statusCode} ${response.body}',
            tag: 'DROPBOX');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error getting file metadata', e, stack,
          tag: 'DROPBOX');
      return null;
    }
  }

  /// Download file from Dropbox
  Future<bool> _downloadFile(String fileName, String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      if (_accessToken == null && !await _authenticate()) {
        return false;
      }

      onProgress?.call('Downloading from Dropbox...', 0.0);

      final filePath = '${_config.folderPath}/$fileName';
      final response = await http.post(
        Uri.parse('https://content.dropboxapi.com/2/files/download'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Dropbox-API-Arg': json.encode({'path': filePath}),
        },
      );

      if (response.statusCode == 200) {
        onProgress?.call('Saving file...', 0.7);

        final file = File(localPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(response.bodyBytes);

        onProgress?.call('Download completed', 1.0);
        LoggerService.instance
            .info('File downloaded successfully to $localPath', tag: 'DROPBOX');
        return true;
      } else {
        LoggerService.instance.error(
            'Failed to download file: ${response.statusCode} ${response.body}',
            tag: 'DROPBOX');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error downloading file', e, stack, tag: 'DROPBOX');
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
          tag: 'DROPBOX');
      return null;
    }
  }

  @override
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      onProgress?.call('Connecting to Dropbox...', 0.1);

      // Look for app files (zip or executable)
      final metadata = await _getFileMetadata('app.zip');
      if (metadata == null) {
        LoggerService.instance
            .error('No app.zip found in Dropbox folder', tag: 'DROPBOX');
        return false;
      }

      final zipPath = '$localPath/app.zip';
      if (await _downloadFile('app.zip', zipPath, onProgress: onProgress)) {
        onProgress?.call('Extracting files...', 0.8);
        // TODO: Extract zip file
        // For now, assume the zip contains the executable directly
        return true;
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Download repository failed', e, stack, tag: 'DROPBOX');
      return false;
    }
  }

  @override
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    // For Dropbox, update is the same as download
    return await downloadRepository(localPath, onProgress: onProgress);
  }

  @override
  Future<bool> hasUpdates(String localPath) async {
    try {
      final metadata = await _getFileMetadata('app.zip');
      if (metadata == null) return false;

      final remoteModified = metadata['client_modified'] as String?;
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
          .logException('Error checking for updates', e, stack, tag: 'DROPBOX');
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
          tag: 'DROPBOX');
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
      return metadata?['client_modified'] as String?;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error getting remote version', e, stack,
          tag: 'DROPBOX');
      return null;
    }
  }

  @override
  String get sourceDescription => 'Dropbox (Folder: ${_config.folderPath})';
}
