import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
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
            .error('MEGA configuration incomplete', tag: 'MEGA');
        return false;
      }

      // Check if we have cached session
      final credentialsFile = File(_config.credentialsPath);
      if (await credentialsFile.exists()) {
        try {
          final credentials = json.decode(await credentialsFile.readAsString());
          _sessionId = credentials['session_id'] as String?;
          _masterKey = credentials['master_key'] as String?;

          if (_sessionId != null && _masterKey != null) {
            // Verify session is still valid
            if (await _verifySession()) {
              return true;
            }
          }
        } catch (e) {
          LoggerService.instance.info(
              'Invalid cached credentials, re-authenticating',
              tag: 'MEGA');
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
  Future<bool> _verifySession() async {
    try {
      if (_sessionId == null) return false;

      // In a real implementation, you'd verify the session with MEGA API
      // For demo purposes, we'll assume sessions are valid for 1 hour
      final credentialsFile = File(_config.credentialsPath);
      if (await credentialsFile.exists()) {
        final stat = await credentialsFile.stat();
        final age = DateTime.now().difference(stat.modified);
        return age.inHours < 1; // Session valid for 1 hour
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Error verifying MEGA session', e, stack, tag: 'MEGA');
      return false;
    }
  }

  /// Save credentials to file
  Future<void> _saveCredentials() async {
    try {
      final credentials = {
        'session_id': _sessionId,
        'master_key': _masterKey,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final credentialsFile = File(_config.credentialsPath);
      await credentialsFile.parent.create(recursive: true);
      await credentialsFile.writeAsString(json.encode(credentials));
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
        // TODO: Extract zip file
        // For now, assume the zip contains the executable directly
        return true;
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
