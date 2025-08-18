class AppConfig {
  final String appName;
  final GitHubRepo githubRepo;
  final String localFolder;
  final String backgroundImage; // empty means no background image
  final int updateCheckInterval;
  final String exeFileName; // exact executable name to launch
  final String appIcon; // optional .ico path for Windows build assets

  AppConfig({
    required this.appName,
    required this.githubRepo,
    required this.localFolder,
    required this.backgroundImage,
    required this.updateCheckInterval,
    required this.exeFileName,
    required this.appIcon,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['app_name'] as String,
      githubRepo: GitHubRepo.fromJson(json['github_repo'] as Map<String, dynamic>),
      localFolder: json['local_folder'] as String,
      backgroundImage: (json['background_image'] as String?) ?? '',
      updateCheckInterval: json['update_check_interval'] as int,
      exeFileName: json['exe_file_name'] as String,
      appIcon: (json['app_icon'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_name': appName,
      'github_repo': githubRepo.toJson(),
      'local_folder': localFolder,
      'background_image': backgroundImage,
      'update_check_interval': updateCheckInterval,
      'exe_file_name': exeFileName,
      'app_icon': appIcon,
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
      url: json['url'] as String,
      branch: json['branch'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'branch': branch,
    };
  }
}
