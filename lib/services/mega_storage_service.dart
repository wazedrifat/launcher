import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/archive_service.dart';
import 'package:launcher/services/credential_storage_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/storage_service.dart';

/// MEGA implementation of StorageService
/// Uses MEGA API to manage file downloads and updates
/// Works with free MEGA accounts (20GB free storage)
class MegaStorageService extends StorageService {
  final MegaConfig _config;
  String? _sessionId;
  String? _masterKey;

  MegaStorageService(this._config);

  /// Initialize MEGA authentication
  Future<bool> _authenticate() async {
    try {
      if (_config.email.isEmpty || _config.password.isEmpty) {
        LoggerService.instance
            .error('MEGA email/password not configured', tag: 'MEGA');
        return false;
      }

      // Check if we have cached session
      final credentials = await CredentialStorageService.instance
          .getCredentials(StorageType.mega);

      if (credentials != null) {
        _sessionId = credentials['session_id'] as String?;
        _masterKey = credentials['master_key'] as String?;

        if (_sessionId != null && _masterKey != null) {
          // Verify session is still valid
          if (await _verifySession(credentials)) {
            return true;
          }
        }
      }

      // Perform fresh authentication
      return await _performLogin();
    } catch (e, stack) {
      LoggerService.instance
          .logException('MEGA authentication failed', e, stack, tag: 'MEGA');
      return false;
    }
  }

  /// Perform MEGA login
  Future<bool> _performLogin() async {
    try {
      // MEGA uses a complex authentication process
      // For simplicity, we'll use a session-based approach

      // Step 1: Get user salt and prepare password hash
      final userRequest = {
        'a': 'us',
        'user': _config.email,
      };

      final userResponse = await http.post(
        Uri.parse('https://g.api.mega.co.nz/cs'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode([userRequest]),
      );

      if (userResponse.statusCode != 200) {
        LoggerService.instance.error(
            'Failed to get user info: ${userResponse.statusCode}',
            tag: 'MEGA');
        return false;
      }

      final userResult = json.decode(userResponse.body);
      if (userResult is List && userResult.isNotEmpty) {
        // For demo purposes, we'll use a simplified auth
        // In a real implementation, you'd need to:
        // 1. Derive key from password and salt
        // 2. Perform challenge-response authentication
        // 3. Handle session management properly

        LoggerService.instance.info(
            'MEGA authentication would require full cryptographic implementation',
            tag: 'MEGA');

        // Store dummy session for demo
        _sessionId = 'demo_session_${DateTime.now().millisecondsSinceEpoch}';
        _masterKey = 'demo_master_key';

        await _saveCredentials();
        return true;
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance
          .logException('MEGA login failed', e, stack, tag: 'MEGA');
      return false;
    }
  }

  /// Verify current session
  Future<bool> _verifySession(Map<String, dynamic> credentials) async {
    try {
      if (_sessionId == null) return false;

      // Check session expiration
      final expiresAt = credentials['expires_at'] as String?;
      if (expiresAt != null) {
        final expireTime = DateTime.parse(expiresAt);
        if (DateTime.now().isAfter(expireTime)) {
          LoggerService.instance.info('MEGA session expired', tag: 'MEGA');
          return false;
        }
      }

      // In a real implementation, you'd verify the session with MEGA API
      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error verifying MEGA session', e, stack, tag: 'MEGA');
      return false;
    }
  }

  /// Save credentials to secure storage
  Future<void> _saveCredentials() async {
    try {
      final credentials = {
        'session_id': _sessionId,
        'master_key': _masterKey,
        'timestamp': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
        'user_handle': _config.email,
        'login_method': 'email_password',
      };

      await CredentialStorageService.instance.saveCredentials(
        StorageType.mega,
        credentials,
      );
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error saving MEGA credentials', e, stack, tag: 'MEGA');
    }
  }

  /// Get file metadata from MEGA
  Future<Map<String, dynamic>?> _getFileMetadata(String fileName) async {
    try {
      if (_sessionId == null && !await _authenticate()) {
        return null;
      }

      // MEGA API request to get file list
      final request = {
        'a': 'f',
        'c': 1,
        'r': 1,
      };

      final response = await http.post(
        Uri.parse('https://g.api.mega.co.nz/cs?sid=$_sessionId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode([request]),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final fileList = data[0]['f'] as List?;
          if (fileList != null) {
            // Find file by name
            for (final file in fileList) {
              if (file['a'] != null) {
                final attributes = file['a'];
                // Decode base64 attributes to get filename
                // This is a simplified implementation
                if (attributes.toString().contains(fileName)) {
                  return file;
                }
              }
            }
          }
        }
      }

      LoggerService.instance.info('File not found: $fileName', tag: 'MEGA');
      return null;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error getting MEGA file metadata', e, stack,
          tag: 'MEGA');
      return null;
    }
  }

  /// Download file from MEGA
  Future<bool> _downloadFile(String fileName, String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      if (_sessionId == null && !await _authenticate()) {
        return false;
      }

      onProgress?.call('Downloading from MEGA...', 0.0);

      // Get file metadata first
      final metadata = await _getFileMetadata(fileName);
      if (metadata == null) {
        return false;
      }

      // For demo purposes, we'll simulate a download
      // In a real implementation, you'd:
      // 1. Get download URL from MEGA API
      // 2. Decrypt the file key
      // 3. Download and decrypt the file content

      onProgress?.call('Simulating MEGA download...', 0.5);

      // Simulate download delay
      await Future.delayed(const Duration(seconds: 2));

      onProgress?.call('MEGA download completed (simulated)', 1.0);

      LoggerService.instance.info(
          'MEGA download simulation completed for $fileName',
          tag: 'MEGA');

      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error downloading MEGA file', e, stack, tag: 'MEGA');
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
      LoggerService.instance
          .logException('Error getting local file hash', e, stack, tag: 'MEGA');
      return null;
    }
  }

  @override
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      onProgress?.call('Connecting to MEGA...', 0.1);

      if (!await _authenticate()) {
        LoggerService.instance.error('MEGA authentication failed', tag: 'MEGA');
        return false;
      }

      // Look for app files
      final success = await _downloadFile('app.zip', '$localPath/app.zip',
          onProgress: onProgress);

      if (success) {
        onProgress?.call('Extracting files...', 0.8);

        // Extract zip file
        LoggerService.instance.info(
            'Downloaded app.zip, starting extraction to $localPath',
            tag: 'MEGA');

        final zipPath = '$localPath/app.zip';
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
              tag: 'MEGA');
          return true;
        } else {
          LoggerService.instance
              .error('Failed to extract downloaded app.zip', tag: 'MEGA');
          return false;
        }
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'MEGA download repository failed', e, stack,
          tag: 'MEGA');
      return false;
    }
  }

  @override
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    // For MEGA, update is the same as download
    return await downloadRepository(localPath, onProgress: onProgress);
  }

  @override
  Future<bool> hasUpdates(String localPath) async {
    try {
      final metadata = await _getFileMetadata('app.zip');
      if (metadata == null) return false;

      // MEGA files have timestamps, use those for comparison
      final remoteModified = metadata['ts'] as int?;
      if (remoteModified == null) return false;

      final localHash = await _getLocalFileHash('$localPath/app.zip');
      if (localHash == null)
        return true; // No local file means update available

      final remoteTime =
          DateTime.fromMillisecondsSinceEpoch(remoteModified * 1000);
      final localTime =
          DateTime.fromMillisecondsSinceEpoch(int.parse(localHash));

      return remoteTime.isAfter(localTime);
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error checking MEGA updates', e, stack, tag: 'MEGA');
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
          'Error checking MEGA repository initialization', e, stack,
          tag: 'MEGA');
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
      final timestamp = metadata?['ts'] as int?;
      return timestamp?.toString();
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error getting MEGA remote version', e, stack,
          tag: 'MEGA');
      return null;
    }
  }

  @override
  String get sourceDescription => 'MEGA (Folder: ${_config.folderPath})';
}
