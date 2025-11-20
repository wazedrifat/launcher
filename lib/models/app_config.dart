import 'dart:io';
import 'package:path_provider/path_provider.dart';

const Map<String, int> _monthLookup = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

class AppConfig {
  final String appName;
  final GitHubRepo githubRepo;
  final String localFolder; // folder name only, not full path
  final String backgroundImage; // empty means no background image
  final int updateCheckInterval;
  final String exeFileName; // exact executable name to launch
  final String appIcon; // optional .ico path for Windows build assets
  final String? expirationData; // raw expiration date string from Drive
  final String? expirationMessage; // expiration message from Drive

  AppConfig({
    required this.appName,
    required this.githubRepo,
    required this.localFolder,
    required this.backgroundImage,
    required this.updateCheckInterval,
    required this.exeFileName,
    required this.appIcon,
    this.expirationData,
    this.expirationMessage,
  });

  /// Checks if the expiration date is older than today (expired)
  bool get isExpired {
    if (expirationData == null || expirationData!.trim().isEmpty) {
      return false;
    }
    final expirationDate = parseExpirationDate(expirationData);
    if (expirationDate == null) {
      return false;
    }
    final now = DateTime.now().toUtc();
    // Check if expiration date is before today (expired)
    return expirationDate.isBefore(DateTime.utc(now.year, now.month, now.day));
  }

  /// Returns the expiration message if expired, null otherwise
  String? get expiredMessage => isExpired ? expirationMessage : null;

  /// Resolves the full path to the local folder under AppData
  /// Creates the directory if it doesn't exist
  Future<String> getLocalFolderPath() async {
    try {
      final appDataDir = await getApplicationSupportDirectory();
      final separator = Platform.pathSeparator;
      final fullPath = '${appDataDir.path}$separator$localFolder';

      // Ensure directory exists
      final dir = Directory(fullPath);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      return fullPath;
    } catch (e) {
      // Fallback: if path_provider fails, use local folder as-is (backward compatibility)
      return localFolder;
    }
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    return AppConfig(
      appName: json['app_name'] as String,
      githubRepo:
          GitHubRepo.fromJson(json['github_repo'] as Map<String, dynamic>),
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
      if (expirationData != null) 'expiration_data': expirationData,
      if (expirationMessage != null) 'expiration_message': expirationMessage,
    };
  }
}

/// Parses expiration date string in format "01-Jan-2027"
DateTime? parseExpirationDate(String? dateString) {
  if (dateString == null || dateString.trim().isEmpty) return null;

  final value = dateString.trim();

  // Try ISO format first
  final isoParsed = DateTime.tryParse(value);
  if (isoParsed != null) {
    return isoParsed.toUtc();
  }

  // Try "DD-MMM-YYYY" format (e.g., "01-Jan-2027")
  final match = RegExp(r'^(\d{1,2})-([A-Za-z]{3})-(\d{4})$').firstMatch(value);
  if (match != null) {
    final day = int.tryParse(match.group(1)!);
    final monthStr = match.group(2)!.toLowerCase();
    final month = _monthLookup[monthStr];
    final year = int.tryParse(match.group(3)!);

    if (day != null && month != null && year != null) {
      return DateTime.utc(year, month, day);
    }
  }

  return null;
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
