class AppConfig {
  final String appName;
  final StorageConfig storage;
  final String localFolder;
  final String backgroundImage; // empty means no background image
  final int updateCheckInterval;
  final String exeFileName; // exact executable name to launch
  final String appIcon; // optional .ico path for Windows build assets

  AppConfig({
    required this.appName,
    required this.storage,
    required this.localFolder,
    required this.backgroundImage,
    required this.updateCheckInterval,
    required this.exeFileName,
    required this.appIcon,
  });

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['app_name'] as String,
      storage: StorageConfig.fromJson(json['storage'] as Map<String, dynamic>),
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
      'storage': storage.toJson(),
      'local_folder': localFolder,
      'background_image': backgroundImage,
      'update_check_interval': updateCheckInterval,
      'exe_file_name': exeFileName,
      'app_icon': appIcon,
    };
  }

  // Legacy support for existing code
  GitHubRepo get githubRepo => storage.github;
}

enum StorageType {
  github,
  googleDrive,
  oneDrive,
  dropbox,
  mega,
}

extension StorageTypeExtension on StorageType {
  String get value {
    switch (this) {
      case StorageType.github:
        return 'github';
      case StorageType.googleDrive:
        return 'google_drive';
      case StorageType.oneDrive:
        return 'onedrive';
      case StorageType.dropbox:
        return 'dropbox';
      case StorageType.mega:
        return 'mega';
    }
  }

  static StorageType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'github':
        return StorageType.github;
      case 'google_drive':
        return StorageType.googleDrive;
      case 'onedrive':
        return StorageType.oneDrive;
      case 'dropbox':
        return StorageType.dropbox;
      case 'mega':
        return StorageType.mega;
      default:
        throw ArgumentError('Unknown storage type: $value');
    }
  }
}

class StorageConfig {
  final StorageType type;
  final GitHubRepo github;
  final GoogleDriveConfig googleDrive;
  final OneDriveConfig oneDrive;
  final DropboxConfig dropbox;
  final MegaConfig mega;

  StorageConfig({
    required this.type,
    required this.github,
    required this.googleDrive,
    required this.oneDrive,
    required this.dropbox,
    required this.mega,
  });

  factory StorageConfig.fromJson(Map<String, dynamic> json) {
    return StorageConfig(
      type: StorageTypeExtension.fromString(json['type'] as String),
      github: GitHubRepo.fromJson(json['github'] as Map<String, dynamic>),
      googleDrive: GoogleDriveConfig.fromJson(
          json['google_drive'] as Map<String, dynamic>),
      oneDrive:
          OneDriveConfig.fromJson(json['onedrive'] as Map<String, dynamic>),
      dropbox: DropboxConfig.fromJson(json['dropbox'] as Map<String, dynamic>),
      mega: MegaConfig.fromJson(json['mega'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'github': github.toJson(),
      'google_drive': googleDrive.toJson(),
      'onedrive': oneDrive.toJson(),
      'dropbox': dropbox.toJson(),
      'mega': mega.toJson(),
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

class GoogleDriveConfig {
  final String clientId;
  final String folderId;
  final String credentialsPath;

  GoogleDriveConfig({
    required this.clientId,
    required this.folderId,
    required this.credentialsPath,
  });

  factory GoogleDriveConfig.fromJson(Map<String, dynamic> json) {
    return GoogleDriveConfig(
      clientId: json['client_id'] as String? ?? '',
      folderId: json['folder_id'] as String? ?? '',
      credentialsPath: json['credentials_path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'folder_id': folderId,
      'credentials_path': credentialsPath,
    };
  }
}

class OneDriveConfig {
  final String clientId;
  final String folderPath;
  final String credentialsPath;

  OneDriveConfig({
    required this.clientId,
    required this.folderPath,
    required this.credentialsPath,
  });

  factory OneDriveConfig.fromJson(Map<String, dynamic> json) {
    return OneDriveConfig(
      clientId: json['client_id'] as String? ?? '',
      folderPath: json['folder_path'] as String? ?? '',
      credentialsPath: json['credentials_path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'folder_path': folderPath,
      'credentials_path': credentialsPath,
    };
  }
}

class DropboxConfig {
  final String appKey;
  final String folderPath;
  final String credentialsPath;

  DropboxConfig({
    required this.appKey,
    required this.folderPath,
    required this.credentialsPath,
  });

  factory DropboxConfig.fromJson(Map<String, dynamic> json) {
    return DropboxConfig(
      appKey: json['app_key'] as String? ?? '',
      folderPath: json['folder_path'] as String? ?? '',
      credentialsPath: json['credentials_path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'app_key': appKey,
      'folder_path': folderPath,
      'credentials_path': credentialsPath,
    };
  }
}

class MegaConfig {
  final String email;
  final String password;
  final String folderPath;
  final String credentialsPath;

  MegaConfig({
    required this.email,
    required this.password,
    required this.folderPath,
    required this.credentialsPath,
  });

  factory MegaConfig.fromJson(Map<String, dynamic> json) {
    return MegaConfig(
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
      folderPath: json['folder_path'] as String? ?? '',
      credentialsPath: json['credentials_path'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'folder_path': folderPath,
      'credentials_path': credentialsPath,
    };
  }
}
