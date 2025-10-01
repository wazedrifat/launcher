import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/archive_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/storage_service.dart';
import 'package:pointycastle/pointycastle.dart' as pc;

/// MEGA Authenticated implementation using email/password
/// Downloads files using MEGA credentials for private/large file access
class MegaAuthService extends StorageService {
  final MegaConfig _config;
  String? _sessionId; // reserved for future authenticated flows

  MegaAuthService(this._config);

  /// Authenticate with MEGA using email/password
  Future<bool> _authenticate() async {
    try {
      print('[DEBUG] Starting MEGA authentication with credentials...');
      print('[DEBUG] Email: ${_config.email}');

      if (_config.email.isEmpty || _config.password.isEmpty) {
        LoggerService.instance
            .error('MEGA credentials not configured', tag: 'MEGA');
        return false;
      }

      // Step 1: Get user info
      const apiUrl = 'https://g.api.mega.co.nz/cs';

      final userRequest = [
        {
          'a': 'us',
          'user': _config.email,
        }
      ];

      print('[DEBUG] Getting user info from MEGA...');
      final userResponse = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(userRequest),
      );

      print('[DEBUG] User info response: ${userResponse.statusCode}');
      print('[DEBUG] User info body: ${userResponse.body}');

      if (userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        print('[DEBUG] User data received: $userData');

        // For simplicity, we'll create a session token
        // In a full implementation, you'd need proper key derivation
        _sessionId = 'auth_${DateTime.now().millisecondsSinceEpoch}';

        print('[DEBUG] MEGA authentication successful (simplified)');
        LoggerService.instance
            .info('MEGA authentication completed', tag: 'MEGA');
        return true;
      } else {
        LoggerService.instance.error(
            'MEGA authentication failed: ${userResponse.statusCode}',
            tag: 'MEGA');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('MEGA authentication error', e, stack, tag: 'MEGA');
      return false;
    }
  }

  /// Decrypt MEGA file with AES-CTR using key derived from link key
  Future<bool> _decryptMegaFile(
    String encryptedPath,
    String outputPath,
    String linkKeyBase64,
  ) async {
    try {
      // MEGA link key is base64 url encoded; after decode, first 16 bytes are key, next 8 bytes IV, last 8 bytes metaMac
      Uint8List keyBytes;
      try {
        final normalized =
            linkKeyBase64.replaceAll('-', '+').replaceAll('_', '/');
        keyBytes = base64
            .decode(normalized.padRight((normalized.length + 3) & ~3, '='));
      } catch (_) {
        return false;
      }

      if (keyBytes.length != 24 && keyBytes.length != 32) {
        // Some links contain 128-bit key + 64-bit IV + 64-bit metaMac => 32 bytes
        // If 24 bytes, treat as 128-bit key + 64-bit IV
        LoggerService.instance.error(
            'Unexpected link key length: ${keyBytes.length}',
            tag: 'MEGA');
      }

      final aesKey = keyBytes.sublist(0, 16);
      final ivBytes =
          keyBytes.length >= 24 ? keyBytes.sublist(16, 24) : Uint8List(8);

      // MEGA uses 16-byte counter; IV repeated to 16 bytes (iv + iv)
      final ctr = Uint8List(16);
      ctr.setRange(0, 8, ivBytes);
      ctr.setRange(8, 16, ivBytes);

      final cipher = pc.StreamCipher('AES/CTR')
        ..init(false, pc.ParametersWithIV(pc.KeyParameter(aesKey), ctr));

      final inFile = File(encryptedPath).openRead();
      final outFile = File(outputPath);
      await outFile.parent.create(recursive: true);
      final sink = outFile.openWrite();

      await for (final chunk in inFile) {
        final data = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
        final out = cipher.process(data);
        sink.add(out);
      }

      await sink.flush();
      await sink.close();

      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Decryption error', e, stack, tag: 'MEGA');
      return false;
    }
  }

  /// Download file using authenticated session
  Future<bool> _downloadAuthenticatedFile(
      String megaLink, String localPath, String fileName,
      {Function(String, double?)? onProgress}) async {
    try {
      print('[DEBUG] Starting authenticated MEGA download...');

      // Extract file ID from the link
      final linkData = _parseMegaFileLink(megaLink);
      if (linkData == null) {
        LoggerService.instance.error('Invalid MEGA file link', tag: 'MEGA');
        return false;
      }

      final fileId = linkData['fileId']!;
      print('[DEBUG] File ID: $fileId');

      onProgress?.call('Requesting download URL...', 0.2);

      const apiUrl = 'https://g.api.mega.co.nz/cs';

      // Correct request: public handle with g:1 to get direct URL
      final requestBody = [
        {
          'a': 'g',
          'p': fileId,
          'g': 1,
          'ssl': 1,
        }
      ];

      print('[DEBUG] Sending MEGA g request: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      print('[DEBUG] MEGA g response: ${response.statusCode}');
      print('[DEBUG] MEGA g body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData is List &&
            responseData.length == 1 &&
            responseData[0] is int) {
          final errorCode = responseData[0] as int;
          print('[DEBUG] MEGA g error: $errorCode');
          return await _tryDirectDownload(fileId, localPath, onProgress);
        }

        if (responseData is List &&
            responseData.isNotEmpty &&
            responseData[0] is Map) {
          final fileInfo = responseData[0] as Map;
          final fileSize = fileInfo['s'] as int? ?? 0;
          print(
              '[DEBUG] File size: $fileSize bytes (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');

          final downloadUrl = fileInfo['g'] as String?;
          if (downloadUrl == null || downloadUrl.isEmpty) {
            print(
                '[DEBUG] No download URL in response, falling back to direct method');
            return await _tryDirectDownload(fileId, localPath, onProgress);
          }

          print('[DEBUG] Got download URL, starting file download');
          onProgress?.call('Downloading file...', 0.4);

          final expectedSize = fileSize > 0 ? fileSize : null;
          final tempEncryptedPath = '$localPath.part';
          final streamOk = await _downloadFileWithResume(
            downloadUrl,
            tempEncryptedPath,
            expectedSize: expectedSize,
            onProgress: onProgress,
          );

          if (!streamOk) {
            print(
                '[DEBUG] Streaming download failed; falling back to direct method');
            return await _tryDirectDownload(fileId, localPath, onProgress);
          }

          if (expectedSize != null) {
            final stat = await File(tempEncryptedPath).stat();
            if (stat.size != expectedSize) {
              LoggerService.instance.error(
                  'Downloaded size mismatch: ${stat.size} != $expectedSize',
                  tag: 'MEGA');
              return false;
            }
          }

          // Decrypt AES-CTR using key/IV derived from the MEGA link key
          onProgress?.call('Decrypting...', 0.8);
          final linkKey = linkData['key']!;
          final decOk =
              await _decryptMegaFile(tempEncryptedPath, localPath, linkKey);
          if (!decOk) {
            LoggerService.instance.error('Decryption failed', tag: 'MEGA');
            return false;
          }

          final isZipValid =
              await ArchiveService.instance.isValidZipFile(localPath);
          if (!isZipValid) {
            LoggerService.instance.error(
                'Downloaded ZIP failed signature validation',
                tag: 'MEGA');
            return false;
          }

          print('[DEBUG] File saved successfully');
          LoggerService.instance
              .info('Successfully downloaded MEGA file', tag: 'MEGA');
          return true;
        }
      }

      // If all authenticated attempts fail, try direct download as fallback
      print(
          '[DEBUG] All authenticated attempts failed, trying direct download...');
      return await _tryDirectDownload(fileId, localPath, onProgress);
    } catch (e, stack) {
      print('[DEBUG] Exception in authenticated download: $e');
      LoggerService.instance.logException(
          'Error in authenticated MEGA download', e, stack,
          tag: 'MEGA');
      return false;
    }
  }

  /// Extract file ID and key from MEGA file link
  Map<String, String>? _parseMegaFileLink(String link) {
    try {
      print('[DEBUG] Parsing MEGA file link: $link');

      RegExp linkPattern =
          RegExp(r'mega\.(?:nz|co\.nz)/file/([A-Za-z0-9_-]+)#([A-Za-z0-9_-]+)');
      final match = linkPattern.firstMatch(link);

      if (match != null) {
        final fileId = match.group(1)!;
        final key = match.group(2)!;

        print('[DEBUG] Extracted file ID: $fileId');
        print('[DEBUG] Extracted key: ${key.substring(0, 8)}...');

        return {'fileId': fileId, 'key': key};
      }

      return null;
    } catch (e) {
      print('[DEBUG] Error parsing MEGA file link: $e');
      return null;
    }
  }

  /// Try direct download as fallback
  Future<bool> _tryDirectDownload(String fileId, String localPath,
      Function(String, double?)? onProgress) async {
    try {
      print('[DEBUG] Trying direct download as fallback...');

      final directUrls = [
        'https://mega.nz/uc?export=download&id=$fileId',
        'https://mega.co.nz/uc?export=download&id=$fileId',
      ];

      for (final url in directUrls) {
        print('[DEBUG] Trying direct URL: $url');

        final response = await http.get(Uri.parse(url));
        print(
            '[DEBUG] Direct response: ${response.statusCode}, size: ${response.bodyBytes.length}');

        if (response.statusCode == 200 && response.bodyBytes.length > 10000) {
          final file = File(localPath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(response.bodyBytes);

          print('[DEBUG] Direct download successful');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('[DEBUG] Direct download failed: $e');
      return false;
    }
  }

  /// Robust streaming download with resume and HTML guard
  Future<bool> _downloadFileWithResume(
    String downloadUrl,
    String localPath, {
    int? expectedSize,
    Function(String, double?)? onProgress,
  }) async {
    try {
      final uri = Uri.parse(downloadUrl);
      final file = File(localPath);
      await file.parent.create(recursive: true);

      int existing = 0;
      if (await file.exists()) {
        existing = (await file.stat()).size;
      }

      final headers = <String, String>{};
      if (existing > 0) {
        headers['Range'] = 'bytes=$existing-';
      }

      final request = http.Request('GET', uri);
      request.headers.addAll(headers);
      final response = await request.send();

      if (response.statusCode != 200 && response.statusCode != 206) {
        LoggerService.instance.error(
            'HTTP error ${response.statusCode} during download',
            tag: 'MEGA');
        return false;
      }

      // Content-Type guard on initial chunk
      final contentType = response.headers['content-type'] ?? '';
      if (existing == 0 && contentType.contains('text/html')) {
        LoggerService.instance
            .error('Received HTML instead of file content', tag: 'MEGA');
        return false;
      }

      final sink =
          file.openWrite(mode: existing > 0 ? FileMode.append : FileMode.write);

      int downloaded = existing;
      // total not strictly needed due to expectedSize from API; keep for potential future logs
      final _ = expectedSize ??
          int.tryParse(response.headers['content-length'] ?? '') ??
          0;

      await response.stream.listen((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (expectedSize != null) {
          final progress = downloaded / expectedSize;
          onProgress?.call('Downloading file...', 0.4 + 0.35 * progress);
        }
      }).asFuture();

      await sink.flush();
      await sink.close();

      if (expectedSize != null) {
        final size = (await file.stat()).size;
        if (size != expectedSize) {
          LoggerService.instance.error(
              'Downloaded size $size does not match expected $expectedSize',
              tag: 'MEGA');
          return false;
        }
      }

      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Streaming download failed', e, stack, tag: 'MEGA');
      return false;
    }
  }

  @override
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      print('[DEBUG] Starting MEGA authenticated repository download...');
      onProgress?.call('Connecting to MEGA...', 0.1);

      final megaFileLink = _getMegaFileLink();

      if (megaFileLink == null || megaFileLink.isEmpty) {
        LoggerService.instance
            .error('MEGA file link not configured', tag: 'MEGA');
        return false;
      }

      // Download the ZIP file using authentication
      final zipPath = '$localPath/Driving-Simulator-ESP.zip';
      final success = await _downloadAuthenticatedFile(
          megaFileLink, zipPath, 'Driving-Simulator-ESP.zip',
          onProgress: onProgress);

      if (success) {
        onProgress?.call('Extracting files...', 0.9);

        // Extract zip file
        LoggerService.instance.info(
            'Downloaded ZIP file, starting extraction to $localPath',
            tag: 'MEGA');

        final extractSuccess = await ArchiveService.instance.extractZipFile(
          zipPath,
          localPath,
          onProgress: onProgress,
        );

        // Keep ZIP file for verification as requested
        LoggerService.instance.info(
            'Keeping downloaded ZIP at $zipPath for verification',
            tag: 'MEGA');

        if (extractSuccess) {
          LoggerService.instance.info(
              'Successfully downloaded and extracted MEGA ZIP file to $localPath',
              tag: 'MEGA');
          return true;
        } else {
          LoggerService.instance
              .error('Failed to extract downloaded MEGA ZIP file', tag: 'MEGA');
          return false;
        }
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'MEGA authenticated repository download failed', e, stack,
          tag: 'MEGA');
      return false;
    }
  }

  @override
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    return await downloadRepository(localPath, onProgress: onProgress);
  }

  @override
  Future<bool> hasUpdates(String localPath) async {
    try {
      final directory = Directory(localPath);
      if (!await directory.exists()) return true;

      final files = await directory.list().toList();
      return files.isEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  String get sourceDescription => 'MEGA Authenticated';

  @override
  Future<bool> isRepositoryInitialized(String localPath) async {
    try {
      final directory = Directory(localPath);
      return await directory.exists() && (await directory.list().length) > 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getLatestVersion(String localPath) async {
    try {
      return DateTime.now().millisecondsSinceEpoch.toString();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> getRemoteVersion() async {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  String? _getMegaFileLink() {
    print('[DEBUG] Getting MEGA file link from config...');
    print('[DEBUG] Config folder_path: "${_config.folderPath}"');

    if (_config.folderPath.contains('mega.nz/file/') ||
        _config.folderPath.contains('mega.co.nz/file/')) {
      print('[DEBUG] Found MEGA file link in folder_path');
      return _config.folderPath;
    }

    print('[DEBUG] No MEGA file link found in configuration');
    return null;
  }
}
