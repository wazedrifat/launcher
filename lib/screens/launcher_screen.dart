import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launcher/services/config_service.dart';
import 'package:launcher/services/git_service.dart';
import 'package:launcher/services/process_service.dart';
import 'package:launcher/services/connectivity_service.dart';
import 'package:launcher/services/version_service.dart';
import 'package:launcher/services/logger_service.dart';

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({super.key});

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  bool _isUpdateAvailable = false;
  bool _isCheckingUpdate = false;
  bool _isUpdating = false;
  bool _isProcessRunning = false;
  bool _isOnline = false;
  bool _isRepositoryCloned = false;
  bool _isLaunching = false; // opening exe loader
  bool _isClearingStorage = false;
  String? _executablePath;
  String? _updateProgress;
  double _updateProgressValue = 0.0;
  String? _latestTag; // local tag only
  Timer? _updateTimer;
  Timer? _processCheckTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _processCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    LoggerService.instance.info('Initializing launcher app...', tag: 'APP');

    try {
      await _checkConnectivity();
      await _checkRepositoryStatus();
      await _findExecutable();
      await _refreshLocalVersion();
      await _checkForUpdates();
      _startPeriodicChecks();

      LoggerService.instance
          .info('App initialization completed successfully', tag: 'APP');
    } catch (e, stackTrace) {
      LoggerService.instance
          .logException('App initialization failed', e, stackTrace, tag: 'APP');
      print('[APP][ERROR] $e');
      print('[APP][STACK] $stackTrace');
    }
  }

  Future<void> _checkConnectivity() async {
    final isConnected = await ConnectivityService.instance.isConnected();
    setState(() {
      _isOnline = isConnected;
    });
  }

  Future<void> _checkRepositoryStatus() async {
    final config = ConfigService.instance.config;
    if (config != null) {
      final localFolderPath = await config.getLocalFolderPath();
      final isCloned = await GitService.instance.isRepositoryInitialized(
        localFolderPath,
      );
      setState(() {
        _isRepositoryCloned = isCloned;
      });
      LoggerService.instance.info(
          'Repository status: ${isCloned ? 'Cloned' : 'Not cloned'}',
          tag: 'APP');
      LoggerService.instance
          .info('Background image path: ${config.backgroundImage}', tag: 'APP');
    }
  }

  Future<void> _refreshLocalVersion() async {
    try {
      final config = ConfigService.instance.config;
      if (config == null || !_isRepositoryCloned) {
        setState(() {
          _latestTag = null;
        });
        return;
      }
      final localFolderPath = await config.getLocalFolderPath();
      final tag =
          await VersionService.instance.getLocalLatestTag(localFolderPath);
      setState(() {
        _latestTag = tag;
      });
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Failed to read local version tag', e, stack,
          tag: 'VERSION');
      print('[VERSION][ERROR] $e');
      print('[VERSION][STACK] $stack');
    }
  }

  Future<void> _findExecutable() async {
    final config = ConfigService.instance.config;
    if (config != null) {
      final localFolderPath = await config.getLocalFolderPath();
      final exePath = await ProcessService.instance.findExecutable(
        localFolderPath,
        config.exeFileName,
      );
      setState(() {
        _executablePath = exePath;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (!_isOnline) return;

    final config = ConfigService.instance.config;
    if (config == null) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final localFolderPath = await config.getLocalFolderPath();
      final hasUpdates = await GitService.instance.hasUpdates(
        config.githubRepo.url,
        localFolderPath,
        config.githubRepo.branch,
      );

      setState(() {
        _isUpdateAvailable = hasUpdates;
        _isCheckingUpdate = false;
      });
    } catch (e, stack) {
      setState(() {
        _isCheckingUpdate = false;
      });
      LoggerService.instance
          .logException('Update check failed', e, stack, tag: 'UPDATE');
      print('[UPDATE][ERROR] $e');
      print('[UPDATE][STACK] $stack');
    }
  }

  Future<void> _performInstall() async {
    if (!_isOnline) return;

    final config = ConfigService.instance.config;
    if (config == null) return;

    setState(() {
      _isUpdating = true;
      _updateProgress = 'Starting installation...';
      _updateProgressValue = 0.0;
    });

    try {
      setState(() {
        _updateProgress = 'Cloning repository...';
        _updateProgressValue = 0.3;
      });

      final localFolderPath = await config.getLocalFolderPath();
      final success = await GitService.instance.cloneRepository(
        config.githubRepo.url,
        localFolderPath,
        config.githubRepo.branch,
        onProgress: (progress, percent) {
          setState(() {
            _updateProgress = progress;
            _updateProgressValue =
                percent ?? _updateProgressValue; // keep last when null
          });
        },
      );

      if (success) {
        setState(() {
          _updateProgress = 'Finalizing installation...';
          _updateProgressValue = 0.9;
        });

        await _checkRepositoryStatus();
        await _findExecutable();
        await _refreshLocalVersion();
        await _checkForUpdates();

        setState(() {
          _updateProgress = 'Installation completed!';
          _updateProgressValue = 1.0;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _updateProgress = null;
              _updateProgressValue = 0.0;
            });
          }
        });
      } else {
        setState(() {
          _updateProgress = 'Installation failed';
          _updateProgressValue = 0.0;
        });
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('Installation failed', e, stack, tag: 'INSTALL');
      print('[INSTALL][ERROR] $e');
      print('[INSTALL][STACK] $stack');
      setState(() {
        _updateProgress = 'Installation failed: $e';
        _updateProgressValue = 0.0;
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _performUpdate() async {
    if (!_isOnline) return;

    final config = ConfigService.instance.config;
    if (config == null) return;

    setState(() {
      _isUpdating = true;
      _updateProgress = 'Starting update...';
      _updateProgressValue = 0.0;
    });

    try {
      final localFolderPath = await config.getLocalFolderPath();
      final isInitialized = await GitService.instance.isRepositoryInitialized(
        localFolderPath,
      );

      setState(() {
        _updateProgress = isInitialized
            ? 'Pulling latest changes...'
            : 'Cloning repository...';
        _updateProgressValue = 0.3;
      });

      bool success;
      if (isInitialized) {
        success = await GitService.instance.pullRepository(
          localFolderPath,
          onProgress: (progress, percent) {
            setState(() {
              _updateProgress = progress;
              _updateProgressValue = percent ?? _updateProgressValue;
            });
          },
        );
      } else {
        success = await GitService.instance.cloneRepository(
          config.githubRepo.url,
          localFolderPath,
          config.githubRepo.branch,
          onProgress: (progress, percent) {
            setState(() {
              _updateProgress = progress;
              _updateProgressValue = percent ?? _updateProgressValue;
            });
          },
        );
      }

      if (!success) {
        throw Exception('Git operation failed.');
      }

      setState(() {
        _updateProgress = 'Finalizing update...';
        _updateProgressValue = 0.9;
      });

      await _findExecutable();
      await _refreshLocalVersion();
      await _checkForUpdates();

      setState(() {
        _updateProgress = 'Update completed!';
        _updateProgressValue = 1.0;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _updateProgress = null;
            _updateProgressValue = 0.0;
          });
        }
      });
    } catch (e, stack) {
      LoggerService.instance
          .logException('Update failed', e, stack, tag: 'UPDATE');
      print('[UPDATE][ERROR] $e');
      print('[UPDATE][STACK] $stack');
      setState(() {
        _updateProgress = 'Update failed: $e';
        _updateProgressValue = 0.0;
      });
    } finally {
      setState(() {
        _isUpdating = false;
      });
    }
  }

  Future<void> _openExecutable() async {
    if (_executablePath == null || _isLaunching) return;

    setState(() {
      _isLaunching = true;
    });

    try {
      final isRunning =
          await ProcessService.instance.isProcessRunning(_executablePath!);
      if (isRunning) {
        setState(() {
          _isProcessRunning = true;
        });
        return;
      }

      final launched =
          await ProcessService.instance.launchExecutable(_executablePath!);
      // Give the process a moment to appear in tasklist
      await Future.delayed(const Duration(milliseconds: 400));
      final nowRunning =
          await ProcessService.instance.isProcessRunning(_executablePath!);
      setState(() {
        _isProcessRunning = launched && nowRunning;
      });
    } catch (e, stack) {
      LoggerService.instance
          .logException('Failed to open executable', e, stack, tag: 'PROCESS');
    } finally {
      if (mounted) {
        setState(() {
          _isLaunching = false;
        });
      }
    }
  }

  void _startPeriodicChecks() {
    final config = ConfigService.instance.config;
    if (config != null) {
      _updateTimer = Timer.periodic(
        Duration(milliseconds: config.updateCheckInterval),
        (_) async {
          await _checkConnectivity();
          if (_isOnline) {
            await _checkForUpdates();
          }
        },
      );
    }

    _processCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProcessStatus(),
    );
  }

  Future<void> _checkProcessStatus() async {
    if (_executablePath == null) return;

    final isRunning =
        await ProcessService.instance.isProcessRunning(_executablePath!);
    setState(() {
      _isProcessRunning = isRunning;
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ConfigService.instance.config;
    final expiredMessage = config?.expiredMessage;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: (config != null && (config.backgroundImage).isNotEmpty)
              ? DecorationImage(
                  image: AssetImage(config.backgroundImage),
                  fit: BoxFit.cover,
                  onError: (exception, stackTrace) {
                    LoggerService.instance.error(
                        'Failed to load background image: ${config.backgroundImage}',
                        tag: 'UI',
                        error: exception,
                        stackTrace: stackTrace);
                  },
                )
              : null,
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 40,
              right: 40,
              child: _buildMainButtons(),
            ),
            Positioned(
              top: 40,
              right: 40,
              child: _buildStatusAndSettings(),
            ),
            Positioned(
              top: 40,
              left: 40,
              child: _buildVersionDisplay(),
            ),
            if (expiredMessage != null)
              Positioned(
                top: 120,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _buildExpirationWarningBanner(expiredMessage),
                ),
              ),
            if (_isUpdating && _updateProgress != null)
              Positioned(
                bottom: 120,
                right: 40,
                left: 40,
                child: _buildProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButtons() {
    if (!_isRepositoryCloned) {
      return _buildInstallButton();
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUpdateButton(),
          const SizedBox(width: 20),
          _buildOpenButton(),
        ],
      );
    }
  }

  Widget _buildInstallButton() {
    final isDisabled = !_isOnline;

    return ElevatedButton(
      onPressed: isDisabled ? null : _performInstall,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(200, 60),
        elevation: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUpdating)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(
              Icons.download,
              size: 22,
            ),
          const SizedBox(width: 10),
          Text(
            _isUpdating ? 'Installing...' : 'Install',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    final isDisabled = _isProcessRunning || !_isOnline || _isLaunching;

    // Colors and icon based on state
    final isUpdate = _isUpdateAvailable;
    final Color bgColor = isUpdate ? Colors.orange : Colors.blue;
    final String labelText = _isUpdating
        ? 'Updating...'
        : _isCheckingUpdate
            ? 'Checking...'
            : isUpdate
                ? 'Update Available'
                : 'Check for Update';

    return ElevatedButton.icon(
      onPressed: isDisabled
          ? null
          : () {
              if (_isUpdateAvailable) {
                _performUpdate();
              } else {
                _checkForUpdates();
              }
            },
      icon: (_isUpdating || _isCheckingUpdate)
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.update),
      label: Text(
        labelText,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(200, 60),
      ),
    );
  }

  Widget _buildOpenButton() {
    final config = ConfigService.instance.config;
    final isExpired = config?.isExpired ?? false;
    final bool disabled = isExpired ||
        _executablePath == null ||
        _isProcessRunning ||
        _isLaunching;

    return ElevatedButton.icon(
      onPressed: disabled
          ? null
          : () async {
              await _openExecutable();
              await _checkProcessStatus();
            },
      icon: _isLaunching
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Icon(Icons.play_arrow),
      label: Text(
        isExpired
            ? 'Expired'
            : _isProcessRunning
                ? 'Running'
                : (_isLaunching ? 'Opening...' : 'Open'),
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        minimumSize: const Size(200, 60),
      ),
    );
  }

  Widget _buildStatusAndSettings() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIndicator(),
        const SizedBox(width: 12),
        _buildSettingsButton(),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isOnline ? Icons.wifi : Icons.wifi_off,
            color: _isOnline ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: _isClearingStorage ? null : _showSettingsDialog,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isClearingStorage ? Colors.orangeAccent : Colors.white24,
            width: 1,
          ),
        ),
        child: _isClearingStorage
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(
                Icons.settings,
                color: Colors.white,
                size: 18,
              ),
      ),
    );
  }

  Widget _buildExpirationWarningBanner(String message) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white54, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await _clearLocalFolder();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearLocalFolder() async {
    final config = ConfigService.instance.config;
    if (config == null) {
      return;
    }

    setState(() {
      _isClearingStorage = true;
    });

    try {
      final localFolderPath = await config.getLocalFolderPath();
      final directory = Directory(localFolderPath);

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }

      await directory.create(recursive: true);

      await _checkRepositoryStatus();
      await _findExecutable();
      await _refreshLocalVersion();

      setState(() {
        _isProcessRunning = false;
        _executablePath = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local folder cleared.')),
        );
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Failed to clear local folder', e, stack,
          tag: 'STORAGE');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear local folder: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingStorage = false;
        });
      }
    }
  }

  Widget _buildVersionDisplay() {
    final text = _latestTag != null ? 'v$_latestTag' : 'v-';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline,
            color: Colors.blue,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final bool isDeterminate =
        _updateProgressValue > 0.0 && _updateProgressValue <= 1.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _updateProgress ?? 'Processing...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          isDeterminate
              ? LinearProgressIndicator(
                  value: _updateProgressValue,
                  backgroundColor: Colors.grey[600],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 8,
                )
              : const LinearProgressIndicator(
                  backgroundColor: Color(0xFF757575),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  minHeight: 8,
                ),
        ],
      ),
    );
  }
}
