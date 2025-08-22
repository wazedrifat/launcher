import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/dropbox_storage_service.dart';
import 'package:launcher/services/github_storage_service.dart';
import 'package:launcher/services/google_drive_storage_service.dart';
import 'package:launcher/services/mega_storage_service.dart';
import 'package:launcher/services/onedrive_storage_service.dart';
import 'package:launcher/services/storage_service.dart';

/// Factory class for creating storage service instances
/// Implements the Factory Pattern to instantiate the correct storage service
/// based on the configuration
class StorageServiceFactory {
  /// Private constructor to prevent instantiation
  StorageServiceFactory._();

  /// Creates and returns the appropriate storage service based on the storage configuration
  ///
  /// [storageConfig] - The storage configuration containing type and settings
  ///
  /// Returns the appropriate StorageService implementation
  /// Throws [ArgumentError] if the storage type is not supported
  static StorageService createStorageService(StorageConfig storageConfig) {
    switch (storageConfig.type) {
      case StorageType.github:
        return GitHubStorageService(storageConfig.github);

      case StorageType.googleDrive:
        return GoogleDriveStorageService(storageConfig.googleDrive);

      case StorageType.oneDrive:
        return OneDriveStorageService(storageConfig.oneDrive);

      case StorageType.dropbox:
        return DropboxStorageService(storageConfig.dropbox);

      case StorageType.mega:
        return MegaStorageService(storageConfig.mega);
    }
  }

  /// Gets a list of all supported storage types
  static List<StorageType> get supportedTypes => [
        StorageType.github,
        StorageType.googleDrive,
        StorageType.oneDrive,
        StorageType.dropbox,
        StorageType.mega,
      ];

  /// Gets a human-readable name for a storage type
  static String getStorageTypeName(StorageType type) {
    switch (type) {
      case StorageType.github:
        return 'GitHub Repository';
      case StorageType.googleDrive:
        return 'Google Drive';
      case StorageType.oneDrive:
        return 'OneDrive';
      case StorageType.dropbox:
        return 'Dropbox';
      case StorageType.mega:
        return 'MEGA';
    }
  }

  /// Validates if the storage configuration is valid for the given type
  ///
  /// [storageConfig] - The storage configuration to validate
  ///
  /// Returns true if the configuration is valid, false otherwise
  static bool isConfigurationValid(StorageConfig storageConfig) {
    switch (storageConfig.type) {
      case StorageType.github:
        return storageConfig.github.url.isNotEmpty &&
            storageConfig.github.branch.isNotEmpty;

      case StorageType.googleDrive:
        return storageConfig.googleDrive.clientId.isNotEmpty &&
            storageConfig.googleDrive.folderId.isNotEmpty;

      case StorageType.oneDrive:
        return storageConfig.oneDrive.clientId.isNotEmpty &&
            storageConfig.oneDrive.folderPath.isNotEmpty;

      case StorageType.dropbox:
        return storageConfig.dropbox.appKey.isNotEmpty &&
            storageConfig.dropbox.folderPath.isNotEmpty;

      case StorageType.mega:
        return storageConfig.mega.email.isNotEmpty &&
            storageConfig.mega.password.isNotEmpty &&
            storageConfig.mega.folderPath.isNotEmpty;
    }
  }

  /// Gets a description of what is required for a storage type configuration
  ///
  /// [type] - The storage type to get requirements for
  ///
  /// Returns a string describing the configuration requirements
  static String getConfigurationRequirements(StorageType type) {
    switch (type) {
      case StorageType.github:
        return 'Requires: Repository URL and branch name';

      case StorageType.googleDrive:
        return 'Requires: Google Drive client ID and folder ID (credentials handled automatically)';

      case StorageType.oneDrive:
        return 'Requires: OneDrive client ID and folder path (credentials handled automatically)';

      case StorageType.dropbox:
        return 'Requires: Dropbox App Key and folder path (credentials handled automatically)';

      case StorageType.mega:
        return 'Requires: MEGA email, password, and folder path (credentials handled automatically)';
    }
  }
}
