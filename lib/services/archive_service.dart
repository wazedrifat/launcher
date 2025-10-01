import 'dart:io';

import 'package:archive/archive_io.dart';
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

      // Use Dart archive for consistent cross-platform extraction (streaming)
      final success = await _extractZipWithArchive(
          zipFilePath, destinationPath, onProgress);

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

  /// Extract ZIP using Dart archive package with streaming to disk
  Future<bool> _extractZipWithArchive(
    String zipFilePath,
    String destinationPath,
    Function(String, double?)? onProgress,
  ) async {
    try {
      onProgress?.call('Reading ZIP directory...', 0.3);

      // Stream the zip file and extract each entry without loading into memory
      final inputStream = InputFileStream(zipFilePath);
      final archive = ZipDecoder().decodeBuffer(inputStream);

      int processedEntries = 0;
      final totalEntries = archive.isEmpty ? 1 : archive.length;

      for (final file in archive) {
        final filename = file.name;
        final outPath = path.join(destinationPath, filename);

        if (file.isFile) {
          final outFile = File(outPath);
          await outFile.parent.create(recursive: true);
          final output = OutputFileStream(outPath);
          file.writeContent(output);
          await output.close();
        } else {
          await Directory(outPath).create(recursive: true);
        }

        processedEntries++;
        final progress = 0.35 + (processedEntries / totalEntries) * 0.6;
        onProgress?.call('Extracting $filename', progress);
      }

      await inputStream.close();

      onProgress?.call('Extraction completed', 1.0);
      LoggerService.instance
          .info('Dart archive extraction successful', tag: 'ARCHIVE');
      return true;
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Dart archive extraction error', e, stack,
          tag: 'ARCHIVE');
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
