import 'dart:io';

import 'package:launcher/services/logger_service.dart';
import 'package:path/path.dart' as path;

/// Service for handling archive extraction (ZIP files)
/// Handles downloading and extracting zip files from cloud storage
class ArchiveService {
  static final ArchiveService instance = ArchiveService._internal();
  factory ArchiveService() => instance;
  ArchiveService._internal();

  /// Extract a ZIP file to a destination directory
  ///
  /// [zipFilePath] - Path to the ZIP file to extract
  /// [destinationPath] - Path where the ZIP contents should be extracted
  /// [onProgress] - Optional callback for progress updates
  ///
  /// Returns true if extraction was successful, false otherwise
  Future<bool> extractZipFile(
    String zipFilePath,
    String destinationPath, {
    Function(String, double?)? onProgress,
  }) async {
    try {
      LoggerService.instance.info(
          'Starting ZIP extraction from $zipFilePath to $destinationPath',
          tag: 'ARCHIVE');

      onProgress?.call('Preparing extraction...', 0.1);

      // Ensure the ZIP file exists
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        LoggerService.instance
            .error('ZIP file not found: $zipFilePath', tag: 'ARCHIVE');
        return false;
      }

      // Create destination directory if it doesn't exist
      final destinationDir = Directory(destinationPath);
      if (!await destinationDir.exists()) {
        await destinationDir.create(recursive: true);
        LoggerService.instance.info(
            'Created destination directory: $destinationPath',
            tag: 'ARCHIVE');
      }

      onProgress?.call('Starting extraction...', 0.2);

      // Use platform-specific extraction method
      bool success;
      if (Platform.isWindows) {
        success =
            await _extractZipWindows(zipFilePath, destinationPath, onProgress);
      } else if (Platform.isMacOS || Platform.isLinux) {
        success =
            await _extractZipUnix(zipFilePath, destinationPath, onProgress);
      } else {
        LoggerService.instance
            .error('Unsupported platform for ZIP extraction', tag: 'ARCHIVE');
        return false;
      }

      if (success) {
        onProgress?.call('Extraction completed', 1.0);
        LoggerService.instance
            .info('ZIP extraction completed successfully', tag: 'ARCHIVE');
      } else {
        LoggerService.instance.error('ZIP extraction failed', tag: 'ARCHIVE');
      }

      return success;
    } catch (e, stack) {
      LoggerService.instance
          .logException('ZIP extraction error', e, stack, tag: 'ARCHIVE');
      onProgress?.call('Extraction failed: $e', null);
      return false;
    }
  }

  /// Extract ZIP file on Windows using PowerShell
  Future<bool> _extractZipWindows(
    String zipFilePath,
    String destinationPath,
    Function(String, double?)? onProgress,
  ) async {
    try {
      onProgress?.call('Using PowerShell extraction...', 0.3);

      // Use PowerShell Expand-Archive cmdlet
      final result = await Process.run(
        'powershell',
        [
          '-Command',
          'Expand-Archive -Path "$zipFilePath" -DestinationPath "$destinationPath" -Force'
        ],
        runInShell: true,
      );

      onProgress?.call('PowerShell extraction completed', 0.9);

      if (result.exitCode == 0) {
        LoggerService.instance
            .info('Windows ZIP extraction successful', tag: 'ARCHIVE');
        return true;
      } else {
        LoggerService.instance.error(
            'Windows ZIP extraction failed: ${result.stderr}',
            tag: 'ARCHIVE');

        // Fallback to alternative Windows method
        return await _extractZipWindowsFallback(
            zipFilePath, destinationPath, onProgress);
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Windows ZIP extraction error', e, stack,
          tag: 'ARCHIVE');

      // Fallback to alternative method
      return await _extractZipWindowsFallback(
          zipFilePath, destinationPath, onProgress);
    }
  }

  /// Fallback Windows extraction using tar (available in Windows 10+)
  Future<bool> _extractZipWindowsFallback(
    String zipFilePath,
    String destinationPath,
    Function(String, double?)? onProgress,
  ) async {
    try {
      onProgress?.call('Using Windows tar fallback...', 0.4);

      // Windows 10+ includes tar command
      final result = await Process.run(
        'tar',
        ['-xf', zipFilePath, '-C', destinationPath],
        runInShell: true,
      );

      onProgress?.call('Windows tar extraction completed', 0.9);

      if (result.exitCode == 0) {
        LoggerService.instance
            .info('Windows tar ZIP extraction successful', tag: 'ARCHIVE');
        return true;
      } else {
        LoggerService.instance.error(
            'Windows tar ZIP extraction failed: ${result.stderr}',
            tag: 'ARCHIVE');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Windows tar ZIP extraction error', e, stack,
          tag: 'ARCHIVE');
      return false;
    }
  }

  /// Extract ZIP file on Unix systems (macOS/Linux) using unzip
  Future<bool> _extractZipUnix(
    String zipFilePath,
    String destinationPath,
    Function(String, double?)? onProgress,
  ) async {
    try {
      onProgress?.call('Using unzip command...', 0.3);

      // Use unzip command
      final result = await Process.run(
        'unzip',
        ['-o', zipFilePath, '-d', destinationPath],
        runInShell: true,
      );

      onProgress?.call('Unzip completed', 0.9);

      if (result.exitCode == 0) {
        LoggerService.instance
            .info('Unix ZIP extraction successful', tag: 'ARCHIVE');
        return true;
      } else {
        LoggerService.instance.error(
            'Unix ZIP extraction failed: ${result.stderr}',
            tag: 'ARCHIVE');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('Unix ZIP extraction error', e, stack, tag: 'ARCHIVE');
      return false;
    }
  }

  /// Clean up temporary files
  Future<void> cleanupTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        LoggerService.instance
            .info('Cleaned up temporary file: $filePath', tag: 'ARCHIVE');
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Error cleaning up temporary file', e, stack,
          tag: 'ARCHIVE');
    }
  }

  /// Get temporary file path for downloads
  String getTempFilePath(String fileName) {
    final tempDir = Directory.systemTemp;
    return path.join(tempDir.path, 'launcher_temp_$fileName');
  }

  /// Validate ZIP file integrity
  Future<bool> isValidZipFile(String zipFilePath) async {
    try {
      final zipFile = File(zipFilePath);
      if (!await zipFile.exists()) {
        return false;
      }

      // Basic validation - check file size and extension
      final stat = await zipFile.stat();
      if (stat.size < 22) {
        // Minimum ZIP file size
        return false;
      }

      // Check ZIP file signature
      final bytes = await zipFile.openRead(0, 4).first;
      final signature = bytes.sublist(0, 4);

      // ZIP file signatures: PK (0x504B)
      return signature[0] == 0x50 && signature[1] == 0x4B;
    } catch (e, stack) {
      LoggerService.instance
          .logException('ZIP validation error', e, stack, tag: 'ARCHIVE');
      return false;
    }
  }

  /// Get extracted file count estimate for progress tracking
  Future<int> getEstimatedFileCount(String zipFilePath) async {
    try {
      if (Platform.isWindows) {
        // Use PowerShell to count files in ZIP
        final result = await Process.run(
          'powershell',
          [
            '-Command',
            '(Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::OpenRead("$zipFilePath").Entries.Count)'
          ],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          return int.tryParse(result.stdout.toString().trim()) ?? 0;
        }
      } else {
        // Use unzip -l to list files
        final result = await Process.run(
          'unzip',
          ['-l', zipFilePath],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          return lines
                  .where((line) =>
                      line.trim().isNotEmpty && !line.startsWith('Archive:'))
                  .length -
              2; // Subtract header/footer
        }
      }
    } catch (e) {
      LoggerService.instance.info(
          'Could not estimate file count for progress tracking',
          tag: 'ARCHIVE');
    }

    return 0; // Return 0 if estimation fails
  }
}
