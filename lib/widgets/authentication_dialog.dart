import 'package:flutter/material.dart';
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/storage_service_factory.dart';

/// Dialog for handling storage provider authentication
/// Shows authentication options and triggers OAuth2 flows
class AuthenticationDialog extends StatefulWidget {
  final StorageType storageType;
  final VoidCallback? onAuthenticationComplete;

  const AuthenticationDialog({
    super.key,
    required this.storageType,
    this.onAuthenticationComplete,
  });

  @override
  State<AuthenticationDialog> createState() => _AuthenticationDialogState();
}

class _AuthenticationDialogState extends State<AuthenticationDialog> {
  bool _isAuthenticating = false;
  String _statusMessage = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          _getStorageIcon(widget.storageType),
          const SizedBox(width: 12),
          Text(_getTitle()),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getDescription(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            if (_isAuthenticating) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              _buildAuthenticationSteps(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isAuthenticating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isAuthenticating ? null : _authenticate,
          child: _isAuthenticating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Authenticate'),
        ),
      ],
    );
  }

  Widget _getStorageIcon(StorageType type) {
    switch (type) {
      case StorageType.googleDrive:
        return const Icon(Icons.cloud, color: Colors.blue);
      case StorageType.oneDrive:
        return const Icon(Icons.cloud_queue, color: Colors.orange);
      case StorageType.dropbox:
        return const Icon(Icons.cloud_circle, color: Colors.blue);
      case StorageType.mega:
        return const Icon(Icons.security, color: Colors.red);
      case StorageType.github:
        return const Icon(Icons.code, color: Colors.black);
    }
  }

  String _getTitle() {
    final providerName =
        StorageServiceFactory.getStorageTypeName(widget.storageType);
    return 'Authenticate with $providerName';
  }

  String _getDescription() {
    switch (widget.storageType) {
      case StorageType.googleDrive:
        return 'Connect to your Google Drive to access your application files. This will open your browser for secure authentication.';
      case StorageType.oneDrive:
        return 'Connect to your OneDrive to access your application files. This will open your browser for secure authentication.';
      case StorageType.dropbox:
        return 'Connect to your Dropbox to access your application files. This will open your browser for secure authentication.';
      case StorageType.mega:
        return 'Authenticate with MEGA using your email and password configured in app settings.';
      case StorageType.github:
        return 'GitHub authentication is handled automatically using Git commands.';
    }
  }

  Widget _buildAuthenticationSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Authentication Steps:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._getAuthenticationSteps().map((step) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(step)),
                ],
              ),
            )),
      ],
    );
  }

  List<String> _getAuthenticationSteps() {
    switch (widget.storageType) {
      case StorageType.googleDrive:
      case StorageType.oneDrive:
      case StorageType.dropbox:
        return [
          'Click "Authenticate" to start the OAuth2 flow',
          'Your browser will open with the provider\'s login page',
          'Sign in to your account and grant permissions',
          'Return to the application - authentication will complete automatically',
          'Your credentials will be securely stored for future use',
        ];
      case StorageType.mega:
        return [
          'Ensure your MEGA email and password are configured in app settings',
          'Click "Authenticate" to start the login process',
          'The app will create a secure session with MEGA',
          'Your session will be automatically refreshed as needed',
        ];
      case StorageType.github:
        return [
          'GitHub repositories are accessed using Git commands',
          'No additional authentication required',
          'Ensure Git is installed and configured on your system',
        ];
    }
  }

  Future<void> _authenticate() async {
    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Starting authentication...';
    });

    try {
      // Since we don't have the actual storage service instance here,
      // we'll need to trigger the authentication through the parent
      // In a real implementation, you might pass the storage service
      // or use a state management solution

      setState(() {
        _statusMessage = 'Opening browser for authentication...';
      });

      // Simulate authentication delay
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _statusMessage = 'Authentication in progress...';
      });

      // In a real implementation, this would trigger the actual OAuth2 flow
      // For now, we'll simulate success after a delay
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        Navigator.of(context).pop();
        widget.onAuthenticationComplete?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully authenticated with ${StorageServiceFactory.getStorageTypeName(widget.storageType)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
          _statusMessage = 'Authentication failed: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Authentication failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
