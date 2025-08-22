import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/git_service.dart';
import 'package:launcher/services/storage_service.dart';

/// GitHub implementation of StorageService
/// Uses Git commands to manage repository downloads and updates
class GitHubStorageService extends StorageService {
  final GitHubRepo _config;
  final GitService _gitService = GitService.instance;

  GitHubStorageService(this._config);

  @override
  Future<bool> downloadRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    return await _gitService.cloneRepository(
      _config.url,
      localPath,
      _config.branch,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> updateRepository(String localPath,
      {Function(String, double?)? onProgress}) async {
    return await _gitService.pullRepository(
      localPath,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> hasUpdates(String localPath) async {
    return await _gitService.hasUpdates(
      _config.url,
      localPath,
      _config.branch,
    );
  }

  @override
  Future<bool> isRepositoryInitialized(String localPath) async {
    return await _gitService.isRepositoryInitialized(localPath);
  }

  @override
  Future<String?> getLatestVersion(String localPath) async {
    return await _gitService.getLatestCommitHash(localPath);
  }

  @override
  Future<String?> getRemoteVersion() async {
    return await _gitService.getRemoteCommitHash(_config.url, _config.branch);
  }

  @override
  String get sourceDescription => 'GitHub Repository (${_config.url})';
}
