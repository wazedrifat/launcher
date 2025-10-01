import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/archive_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/storage_service.dart';

/// Public Google Drive implementation of StorageService
/// Downloads files from publicly shared Google Drive folders
/// NO authentication required from clients - they just download!
class PublicGoogleDriveService extends StorageService {
  final GoogleDriveConfig _config;

  PublicGoogleDriveService(this._config);

  /// Download file directly from public Google Drive share
  /// Uses direct download URLs - no authentication needed
  Future<bool> _downloadPublicFile(String fileId, String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      print('[DEBUG] Starting _downloadPublicFile...');
      print('[DEBUG] File ID: $fileId');
      print('[DEBUG] Local path: $localPath');

      onProgress?.call('Downloading from Google Drive...', 0.1);

      // Use Google Drive's direct download URL for public files
      // Try multiple URL formats for better compatibility
      final downloadUrl =
          'https://drive.google.com/uc?export=download&id=$fileId&confirm=t';

      print('[DEBUG] Download URL: $downloadUrl');
      LoggerService.instance.info('Downloading public file from: $downloadUrl',
          tag: 'PUBLIC_DRIVE');

      print('[DEBUG] Making HTTP GET request...');
      var response = await http.get(Uri.parse(downloadUrl));

      // Check if we got a virus scan warning page and extract the real download URL
      if (response.statusCode == 200 && (response.body.contains('virus scan') || response.body.contains('uc-download-link'))) {
        print('[DEBUG] Got virus scan warning page, extracting download link...');
        
        // Look for the download link in the HTML using multiple patterns
        final body = response.body;
        print('[DEBUG] Searching for download link in HTML...');
        
        // Try multiple regex patterns to find the download link
        final patterns = [
          RegExp(r'href="([^"]*&confirm=t&uuid=[^"]*)"'),
          RegExp(r'href="([^"]*uc\?export=download[^"]*)"'),
          RegExp(r'action="([^"]*uc\?export=download[^"]*)"'),
        ];
        
        String? realDownloadUrl;
        for (final pattern in patterns) {
          final match = pattern.firstMatch(body);
          if (match != null) {
            realDownloadUrl = match.group(1)!;
            // Clean up HTML entities
            realDownloadUrl = realDownloadUrl.replaceAll('&amp;', '&');
            print('[DEBUG] Found download URL with pattern: $realDownloadUrl');
            break;
          }
        }
        
        if (realDownloadUrl != null) {
          print('[DEBUG] Making second HTTP GET request to real download URL...');
          response = await http.get(Uri.parse(realDownloadUrl));
        } else {
          // Fallback: try with confirm parameter
          print('[DEBUG] Could not extract download link from HTML, trying fallback URL...');
          final altUrl = 'https://drive.google.com/uc?export=download&id=$fileId&confirm=t&uuid=${DateTime.now().millisecondsSinceEpoch}';
          print('[DEBUG] Fallback URL: $altUrl');
          response = await http.get(Uri.parse(altUrl));
        }
      }

      print('[DEBUG] HTTP Response status: ${response.statusCode}');
      print('[DEBUG] HTTP Response headers: ${response.headers}');
      print('[DEBUG] HTTP Response body length: ${response.bodyBytes.length}');

      // Check if we got HTML instead of the actual file
      final contentType = response.headers['content-type'] ?? '';
      final isHtml = contentType.contains('text/html') ||
          response.body.contains('<html') ||
          response.body.contains('<!DOCTYPE');

      print('[DEBUG] Content-Type: $contentType');
      print('[DEBUG] Is HTML response: $isHtml');

      if (response.statusCode != 200 || isHtml) {
        if (isHtml) {
          print(
              '[DEBUG] ERROR: Got HTML page instead of file - this means the file is not publicly accessible');
          print(
              '[DEBUG] HTML Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
          LoggerService.instance.error(
              'Google Drive returned HTML page instead of file - check sharing permissions',
              tag: 'PUBLIC_DRIVE');
        } else {
          print(
              '[DEBUG] HTTP Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
        }
        return false;
      }

      if (response.statusCode == 200 && !isHtml) {
        print('[DEBUG] Download successful, saving file...');
        onProgress?.call('Saving file...', 0.8);

        final file = File(localPath);
        print('[DEBUG] Creating parent directories for: $localPath');
        await file.parent.create(recursive: true);

        print('[DEBUG] Writing ${response.bodyBytes.length} bytes to file...');
        await file.writeAsBytes(response.bodyBytes);

        print('[DEBUG] File saved successfully');
        final fileExists = await file.exists();
        final fileSize = await file.length();
        print('[DEBUG] File exists: $fileExists, File size: $fileSize bytes');

        onProgress?.call('Download completed', 1.0);
        LoggerService.instance.info(
            'Successfully downloaded public file to $localPath',
            tag: 'PUBLIC_DRIVE');
        return true;
      } else {
        print(
            '[DEBUG] Download failed with status code: ${response.statusCode}');
        LoggerService.instance.error(
            'Failed to download public file: ${response.statusCode} ${response.body}',
            tag: 'PUBLIC_DRIVE');
        return false;
      }
    } catch (e, stack) {
      print('[DEBUG] Exception in _downloadPublicFile: $e');
      print('[DEBUG] Stack trace: $stack');
      LoggerService.instance.logException(
          'Error downloading public Google Drive file', e, stack,
          tag: 'PUBLIC_DRIVE');
      return false;
    }
  }

  /// Check if app files exist and get metadata
  /// For public files, we can use the file ID directly
  Future<Map<String, dynamic>?> _getPublicFileInfo(String fileId) async {
    try {
      // For public files, we'll do a simple HEAD request to check existence
      final response = await http.head(
          Uri.parse('https://drive.google.com/uc?export=download&id=$fileId'));

      if (response.statusCode == 200) {
        return {
          'id': fileId,
          'exists': true,
          'size': response.headers['content-length'],
          'lastModified': response.headers['last-modified'],
        };
      }
      return null;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error checking public file info', e, stack,
          tag: 'PUBLIC_DRIVE');
      return null;
    }
  }

  @override
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    try {
      print('[DEBUG] Starting downloadRepository...');
      print('[DEBUG] Local path: $localPath');

      onProgress?.call('Connecting to Google Drive...', 0.1);

      // Get the file ID from the configured folder
      // For public sharing, you'll need to provide the file ID of your zip file (any name)
      final appFileId = _getAppFileId();

      print('[DEBUG] App file ID from config: $appFileId');

      if (appFileId == null) {
        print('[DEBUG] App file ID is null - not configured!');
        LoggerService.instance.error(
            'App file ID not configured for public Google Drive access',
            tag: 'PUBLIC_DRIVE');
        return false;
      }

      // Download the app file (can be any zip name in Google Drive)
      final success = await _downloadPublicFile(
          appFileId, '$localPath/downloaded_app.zip',
          onProgress: onProgress);

      if (success) {
        onProgress?.call('Extracting files...', 0.8);

        // Extract zip file
        LoggerService.instance.info(
            'Downloaded zip file, starting extraction to $localPath',
            tag: 'PUBLIC_DRIVE');

        final zipPath = '$localPath/downloaded_app.zip';
        final extractSuccess = await ArchiveService.instance.extractZipFile(
          zipPath,
          localPath,
          onProgress: onProgress,
        );

        // Clean up temporary zip file
        await ArchiveService.instance.cleanupTempFile(zipPath);

        if (extractSuccess) {
          LoggerService.instance.info(
              'Successfully downloaded and extracted zip file to $localPath',
              tag: 'PUBLIC_DRIVE');
          return true;
        } else {
          LoggerService.instance.error('Failed to extract downloaded zip file',
              tag: 'PUBLIC_DRIVE');
          return false;
        }
      }

      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Public Google Drive download failed', e, stack,
          tag: 'PUBLIC_DRIVE');
      return false;
    }
  }

  @override
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    // For public files, update is the same as download
    return await downloadRepository(localPath, onProgress: onProgress);
  }

  @override
  Future<bool> hasUpdates(String localPath) async {
    try {
      final appFileId = _getAppFileId();
      if (appFileId == null) return false;

      // Check remote file info
      final remoteInfo = await _getPublicFileInfo(appFileId);
      if (remoteInfo == null) return false;

      // Check local file info
      final localFile = File('$localPath/downloaded_app.zip');
      if (!await localFile.exists()) {
        return true; // No local file = needs update
      }

      final localStat = await localFile.stat();
      final remoteModified = remoteInfo['lastModified'] as String?;

      if (remoteModified != null) {
        final remoteDate = HttpDate.parse(remoteModified);
        return remoteDate.isAfter(localStat.modified);
      }

      // If we can't determine modification time, assume no update needed
      return false;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error checking for updates', e, stack,
          tag: 'PUBLIC_DRIVE');
      return false;
    }
  }

  /// Get the file ID for the app from configuration
  /// You'll need to configure this with your actual Google Drive file ID
  String? _getAppFileId() {
    // For now, we'll use the folder_id field to store the file ID
    // In a real implementation, you might want to add a separate field
    print('[DEBUG] Getting app file ID from config...');
    print('[DEBUG] Config folder_id: "${_config.folderId}"');
    print('[DEBUG] Config folder_id isEmpty: ${_config.folderId.isEmpty}');
    final result = _config.folderId.isNotEmpty ? _config.folderId : null;
    print('[DEBUG] Returning file ID: $result');
    return result;
  }

  @override
  String get sourceDescription => 'Public Google Drive File';

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
      final appFileId = _getAppFileId();
      if (appFileId == null) return null;

      final fileInfo = await _getPublicFileInfo(appFileId);
      return fileInfo?['lastModified'] as String?;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> getRemoteVersion() async {
    // For public files, remote version is the same as latest version
    // We don't need local path for remote version, so pass empty string
    return await getLatestVersion('');
  }
}
