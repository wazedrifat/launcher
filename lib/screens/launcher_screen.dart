import 'dart:async';

import 'package:flutter/material.dart';
import 'package:launcher/services/config_service.dart';
import 'package:launcher/services/connectivity_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/services/process_service.dart';
import 'package:launcher/services/storage_service.dart';
import 'package:launcher/services/storage_service_factory.dart';
import 'package:launcher/services/version_service.dart';

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
  String? _executablePath;
  String? _updateProgress;
  double _updateProgressValue = 0.0;
  String? _latestTag; // local tag only
  Timer? _updateTimer;
  Timer? _processCheckTimer;
  StorageService? _storageService;

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
      await _initializeStorageService();
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

  Future<void> _initializeStorageService() async {
    try {
      final config = ConfigService.instance.config;
      if (config != null) {
        _storageService =
            StorageServiceFactory.createStorageService(config.storage);
        LoggerService.instance.info(
            'Storage service initialized: ${_storageService?.sourceDescription}',
            tag: 'APP');
      }
    } catch (e, stackTrace) {
      LoggerService.instance.logException(
          'Storage service initialization failed', e, stackTrace,
          tag: 'APP');
      print('[STORAGE][ERROR] $e');
      print('[STORAGE][STACK] $stackTrace');
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
    if (config != null && _storageService != null) {
      final isCloned = await _storageService!.isRepositoryInitialized(
        config.localFolder,
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
      final tag =
          await VersionService.instance.getLocalLatestTag(config.localFolder);
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
      final exePath = await ProcessService.instance.findExecutable(
        config.localFolder,
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
    if (config == null || _storageService == null) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final hasUpdates = await _storageService!.hasUpdates(
        config.localFolder,
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
    if (config == null || _storageService == null) return;

    setState(() {
      _isUpdating = true;
      _updateProgress = 'Starting installation...';
      _updateProgressValue = 0.0;
    });

    try {
      setState(() {
        _updateProgress = 'Downloading repository...';
        _updateProgressValue = 0.3;
      });

      final success = await _storageService!.downloadRepository(
        config.localFolder,
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
    if (config == null || _storageService == null) return;

    setState(() {
      _isUpdating = true;
      _updateProgress = 'Starting update...';
      _updateProgressValue = 0.0;
    });

    try {
      final isInitialized = await _storageService!.isRepositoryInitialized(
        config.localFolder,
      );

      setState(() {
        _updateProgress = isInitialized
            ? 'Updating from source...'
            : 'Downloading from source...';
        _updateProgressValue = 0.3;
      });

      bool success;
      if (isInitialized) {
        success = await _storageService!.updateRepository(
          config.localFolder,
          onProgress: (progress, percent) {
            setState(() {
              _updateProgress = progress;
              _updateProgressValue = percent ?? _updateProgressValue;
            });
          },
        );
      } else {
        success = await _storageService!.downloadRepository(
          config.localFolder,
          onProgress: (progress, percent) {
            setState(() {
              _updateProgress = progress;
              _updateProgressValue = percent ?? _updateProgressValue;
            });
          },
        );
      }

      if (!success) {
        throw Exception('Storage operation failed.');
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
              child: _buildStatusIndicator(),
            ),
            Positioned(
              top: 40,
              left: 40,
              child: _buildVersionDisplay(),
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
    final bool disabled =
        _executablePath == null || _isProcessRunning || _isLaunching;

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
        _isProcessRunning ? 'Running' : (_isLaunching ? 'Opening...' : 'Open'),
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
