import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:launcher/services/config_service.dart';
import 'package:launcher/services/git_service.dart';
import 'package:launcher/services/process_service.dart';
import 'package:launcher/services/connectivity_service.dart';
import 'package:launcher/services/version_service.dart';
import 'package:launcher/services/logger_service.dart';
import 'package:launcher/models/app_config.dart';

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
  String? _executablePath;
  String? _updateProgress;
  double _updateProgressValue = 0.0;
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
      await _checkForUpdates();
      _startPeriodicChecks();
      
      LoggerService.instance.info('App initialization completed successfully', tag: 'APP');
    } catch (e, stackTrace) {
      LoggerService.instance.logException('App initialization failed', e, stackTrace, tag: 'APP');
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
      final isCloned = await GitService.instance.isRepositoryInitialized(
        config.localFolder,
      );
      setState(() {
        _isRepositoryCloned = isCloned;
      });
      LoggerService.instance.info('Repository status: ${isCloned ? 'Cloned' : 'Not cloned'}', tag: 'APP');
      
      // Log background image path for debugging
      LoggerService.instance.info('Background image path: ${config.backgroundImage}', tag: 'APP');
    }
  }

  Future<void> _findExecutable() async {
    final config = ConfigService.instance.config;
    if (config != null) {
      final exePath = await ProcessService.instance.findExecutable(
        config.localFolder,
        config.exeFilePattern,
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
      final hasUpdates = await GitService.instance.hasUpdates(
        config.githubRepo.url,
        config.localFolder,
        config.githubRepo.branch,
      );

      setState(() {
        _isUpdateAvailable = hasUpdates;
        _isCheckingUpdate = false;
      });
    } catch (e) {
      setState(() {
        _isCheckingUpdate = false;
      });
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

      final success = await GitService.instance.cloneRepository(
        config.githubRepo.url,
        config.localFolder,
        config.githubRepo.branch,
        onProgress: (progress) {
          setState(() {
            _updateProgress = progress;
            _updateProgressValue = 0.7;
          });
        },
      );

      if (success) {
        setState(() {
          _updateProgress = 'Finalizing installation...';
          _updateProgressValue = 0.9;
        });

        // Update repository status
        await _checkRepositoryStatus();
        await _findExecutable();
        await _checkForUpdates();

        setState(() {
          _updateProgress = 'Installation completed!';
          _updateProgressValue = 1.0;
        });

        // Reset progress after a delay
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
    } catch (e, stackTrace) {
      LoggerService.instance.logException('Installation failed', e, stackTrace, tag: 'INSTALL');
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
      final isInitialized = await GitService.instance.isRepositoryInitialized(
        config.localFolder,
      );

      setState(() {
        _updateProgress = isInitialized ? 'Pulling latest changes...' : 'Cloning repository...';
        _updateProgressValue = 0.3;
      });

      if (isInitialized) {
        await GitService.instance.pullRepository(
          config.localFolder,
          onProgress: (progress) {
            setState(() {
              _updateProgress = progress;
              _updateProgressValue = 0.7;
            });
          },
        );
      } else {
        await GitService.instance.cloneRepository(
          config.githubRepo.url,
          config.localFolder,
          config.githubRepo.branch,
          onProgress: (progress) {
            setState(() {
              _updateProgress = progress;
              _updateProgressValue = 0.7;
            });
          },
        );
      }

      setState(() {
        _updateProgress = 'Finalizing update...';
        _updateProgressValue = 0.9;
      });

      await _findExecutable();
      await _checkForUpdates();

      setState(() {
        _updateProgress = 'Update completed!';
        _updateProgressValue = 1.0;
      });

      // Reset progress after a delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _updateProgress = null;
            _updateProgressValue = 0.0;
          });
        }
      });

    } catch (e, stackTrace) {
      LoggerService.instance.logException('Update failed', e, stackTrace, tag: 'UPDATE');
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
    if (_executablePath == null) return;

    final isRunning = await ProcessService.instance.isProcessRunning(_executablePath!);
    if (isRunning) {
      setState(() {
        _isProcessRunning = true;
      });
      return;
    }

    await ProcessService.instance.launchExecutable(_executablePath!);
  }

  void _startPeriodicChecks() {
    final config = ConfigService.instance.config;
    if (config != null) {
      _updateTimer = Timer.periodic(
        Duration(milliseconds: config.updateCheckInterval),
        (_) => _checkForUpdates(),
      );
    }

    _processCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProcessStatus(),
    );
  }

  Future<void> _checkProcessStatus() async {
    if (_executablePath == null) return;

    final isRunning = await ProcessService.instance.isProcessRunning(_executablePath!);
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
          image: DecorationImage(
            image: AssetImage(config?.backgroundImage ?? 'assets/images/bg.jpg'),
            fit: BoxFit.cover,
            onError: (exception, stackTrace) {
              LoggerService.instance.error('Failed to load background image: ${config?.backgroundImage}', tag: 'UI', error: exception, stackTrace: stackTrace);
            },
          ),
        ),
        child: Stack(
          children: [
            // Main content
            Positioned(
              bottom: 40,
              right: 40,
              child: _buildMainButtons(),
            ),
            // Status indicator
            Positioned(
              top: 40,
              right: 40,
              child: _buildStatusIndicator(),
            ),
            // Version display
            Positioned(
              top: 40,
              left: 40,
              child: _buildVersionDisplay(),
            ),
            // Progress indicator (when updating or installing)
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
      // Show only Install button if repository is not cloned
      return _buildInstallButton();
    } else {
      // Show Update and Open buttons if repository exists
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isUpdating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            const Icon(
              Icons.download,
              size: 20,
            ),
          const SizedBox(width: 8),
          Text(
            _isUpdating ? 'Installing...' : 'Install',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateButton() {
    final config = ConfigService.instance.config;
    final isDisabled = _isProcessRunning || !_isOnline;
    
    String buttonText = 'Check for Update';
    if (_isUpdateAvailable) {
      buttonText = 'Update Available';
    } else if (_isCheckingUpdate) {
      buttonText = 'Checking...';
    } else if (_isUpdating) {
      buttonText = 'Updating...';
    }

    return ElevatedButton(
      onPressed: isDisabled ? null : () {
        if (_isUpdateAvailable) {
          _performUpdate();
        } else {
          _checkForUpdates();
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _isUpdateAvailable ? Colors.orange : Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isCheckingUpdate || _isUpdating)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(
              _isUpdateAvailable ? Icons.system_update : Icons.refresh,
              size: 20,
            ),
          const SizedBox(width: 8),
          Text(
            buttonText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenButton() {
    final isDisabled = _executablePath == null || _isProcessRunning;
    
    return ElevatedButton(
      onPressed: isDisabled ? null : _openExecutable,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isProcessRunning ? Icons.play_circle_filled : Icons.play_arrow,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _isProcessRunning ? 'Running' : 'Open',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
            Icons.info_outline,
            color: Colors.blue,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            VersionService.instance.getVersionDisplayText(),
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
          LinearProgressIndicator(
            value: _updateProgressValue,
            backgroundColor: Colors.grey[600],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}
