class AppConfig {
  final String appName;
  final GitHubRepo githubRepo;
  final String localFolder;
  final String backgroundImage;
  final int updateCheckInterval;
  final String exeFilePattern;

  AppConfig({
    required this.appName,
    required this.githubRepo,
    required this.localFolder,
    required this.backgroundImage,
    required this.updateCheckInterval,
    required this.exeFilePattern,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['app_name'] ?? 'Launcher App',
      githubRepo: GitHubRepo.fromJson(json['github_repo'] ?? {}),
      localFolder: json['local_folder'] ?? '',
                backgroundImage: json['background_image'] ?? 'assets/images/bg.jpg',
      updateCheckInterval: json['update_check_interval'] ?? 300000,
      exeFilePattern: json['exe_file_pattern'] ?? '*.exe',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'github_repo': githubRepo.toJson(),
      'local_folder': localFolder,
      'background_image': backgroundImage,
      'update_check_interval': updateCheckInterval,
      'exe_file_pattern': exeFilePattern,
    };
  }
}

class GitHubRepo {
  final String url;
  final String branch;

  GitHubRepo({
    required this.url,
    required this.branch,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> json) {
    return GitHubRepo(
      url: json['url'] ?? '',
      branch: json['branch'] ?? 'main',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'branch': branch,
    };
  }
}
