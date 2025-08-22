/// Abstract base class for storage services
/// Defines the interface that all storage implementations must follow
abstract class StorageService {
  /// Downloads/clones the repository to the specified local path
  /// Returns true if successful, false otherwise
  /// [onProgress] callback provides progress updates with message and optional percentage (0.0-1.0)
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress});

  /// Updates the local repository with the latest changes
  /// Returns true if successful, false otherwise
  /// [onProgress] callback provides progress updates with message and optional percentage (0.0-1.0)
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress});

  /// Checks if updates are available by comparing local and remote versions
  /// Returns true if updates are available, false otherwise
  Future<bool> hasUpdates(String localPath);

  /// Checks if the repository is already initialized/downloaded locally
  /// Returns true if initialized, false otherwise
  Future<bool> isRepositoryInitialized(String localPath);

  /// Gets the latest version identifier (commit hash, file hash, etc.)
  /// Returns null if unable to retrieve
  Future<String?> getLatestVersion(String localPath);

  /// Gets the remote version identifier for comparison
  /// Returns null if unable to retrieve
  Future<String?> getRemoteVersion();

  /// Gets a human-readable description of the storage source
  String get sourceDescription;
}
