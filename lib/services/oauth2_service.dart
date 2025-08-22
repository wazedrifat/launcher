import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:launcher/models/app_config.dart';
import 'package:launcher/services/credential_storage_service.dart';
import 'package:launcher/services/logger_service.dart';

/// OAuth2 authentication service for cloud storage providers
/// Handles OAuth2 flows for Google Drive, OneDrive, and Dropbox
class OAuth2Service {
  static final OAuth2Service instance = OAuth2Service._internal();
  factory OAuth2Service() => instance;
  OAuth2Service._internal();

  /// Google Drive OAuth2 configuration
  static const String _googleAuthUrl =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _googleTokenUrl = 'https://oauth2.googleapis.com/token';
  static const String _googleScopes =
      'https://www.googleapis.com/auth/drive.file';

  /// OneDrive OAuth2 configuration
  static const String _microsoftAuthUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/authorize';
  static const String _microsoftTokenUrl =
      'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  static const String _microsoftScopes = 'Files.ReadWrite offline_access';

  /// Dropbox OAuth2 configuration
  static const String _dropboxAuthUrl =
      'https://www.dropbox.com/oauth2/authorize';
  static const String _dropboxTokenUrl =
      'https://api.dropboxapi.com/oauth2/token';

  /// Local redirect URI for OAuth2 callback
  static const String _redirectUri = 'http://localhost:8080/auth/callback';

  /// Authenticate with Google Drive
  Future<bool> authenticateGoogleDrive(
      String clientId, String clientSecret) async {
    try {
      LoggerService.instance
          .info('Starting Google Drive OAuth2 authentication', tag: 'OAUTH2');

      // Step 1: Generate authorization URL
      final authUrl = _buildGoogleAuthUrl(clientId);

      // Step 2: Start local server for callback
      final server = await _startCallbackServer();

      // Step 3: Open browser for user authentication
      await _openBrowser(authUrl);

      // Step 4: Wait for callback with authorization code
      final authCode = await _waitForCallback(server);

      if (authCode == null) {
        LoggerService.instance.error(
            'Failed to get authorization code from Google',
            tag: 'OAUTH2');
        return false;
      }

      // Step 5: Exchange authorization code for tokens
      final tokens =
          await _exchangeGoogleCodeForTokens(clientId, clientSecret, authCode);

      if (tokens == null) {
        LoggerService.instance
            .error('Failed to exchange code for Google tokens', tag: 'OAUTH2');
        return false;
      }

      // Step 6: Save tokens to secure storage
      await CredentialStorageService.instance.saveOAuth2Credentials(
        StorageType.googleDrive,
        tokens['access_token'] as String,
        tokens['refresh_token'] as String?,
        tokens['expires_in'] as int,
        additionalData: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'scope': _googleScopes,
        },
      );

      LoggerService.instance
          .info('Google Drive authentication successful', tag: 'OAUTH2');
      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Google Drive OAuth2 failed', e, stack, tag: 'OAUTH2');
      return false;
    }
  }

  /// Authenticate with OneDrive
  Future<bool> authenticateOneDrive(String clientId) async {
    try {
      LoggerService.instance
          .info('Starting OneDrive OAuth2 authentication', tag: 'OAUTH2');

      // Step 1: Generate authorization URL
      final authUrl = _buildMicrosoftAuthUrl(clientId);

      // Step 2: Start local server for callback
      final server = await _startCallbackServer();

      // Step 3: Open browser for user authentication
      await _openBrowser(authUrl);

      // Step 4: Wait for callback with authorization code
      final authCode = await _waitForCallback(server);

      if (authCode == null) {
        LoggerService.instance.error(
            'Failed to get authorization code from Microsoft',
            tag: 'OAUTH2');
        return false;
      }

      // Step 5: Exchange authorization code for tokens
      final tokens = await _exchangeMicrosoftCodeForTokens(clientId, authCode);

      if (tokens == null) {
        LoggerService.instance.error(
            'Failed to exchange code for Microsoft tokens',
            tag: 'OAUTH2');
        return false;
      }

      // Step 6: Save tokens to secure storage
      await CredentialStorageService.instance.saveOAuth2Credentials(
        StorageType.oneDrive,
        tokens['access_token'] as String,
        tokens['refresh_token'] as String?,
        tokens['expires_in'] as int,
        additionalData: {
          'client_id': clientId,
          'scope': _microsoftScopes,
          'tenant_id': 'common',
        },
      );

      LoggerService.instance
          .info('OneDrive authentication successful', tag: 'OAUTH2');
      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('OneDrive OAuth2 failed', e, stack, tag: 'OAUTH2');
      return false;
    }
  }

  /// Authenticate with Dropbox
  Future<bool> authenticateDropbox(String appKey, String appSecret) async {
    try {
      LoggerService.instance
          .info('Starting Dropbox OAuth2 authentication', tag: 'OAUTH2');

      // Step 1: Generate authorization URL
      final authUrl = _buildDropboxAuthUrl(appKey);

      // Step 2: Start local server for callback
      final server = await _startCallbackServer();

      // Step 3: Open browser for user authentication
      await _openBrowser(authUrl);

      // Step 4: Wait for callback with authorization code
      final authCode = await _waitForCallback(server);

      if (authCode == null) {
        LoggerService.instance.error(
            'Failed to get authorization code from Dropbox',
            tag: 'OAUTH2');
        return false;
      }

      // Step 5: Exchange authorization code for tokens
      final tokens =
          await _exchangeDropboxCodeForTokens(appKey, appSecret, authCode);

      if (tokens == null) {
        LoggerService.instance
            .error('Failed to exchange code for Dropbox tokens', tag: 'OAUTH2');
        return false;
      }

      // Step 6: Save tokens to secure storage
      await CredentialStorageService.instance.saveCredentials(
        StorageType.dropbox,
        {
          'access_token': tokens['access_token'],
          'token_type': tokens['token_type'] ?? 'bearer',
          'app_key': appKey,
          'scope': tokens['scope'] ??
              'files.metadata.read files.content.read files.content.write',
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      LoggerService.instance
          .info('Dropbox authentication successful', tag: 'OAUTH2');
      return true;
    } catch (e, stack) {
      LoggerService.instance
          .logException('Dropbox OAuth2 failed', e, stack, tag: 'OAUTH2');
      return false;
    }
  }

  /// Refresh Google Drive access token
  Future<bool> refreshGoogleDriveToken(Map<String, dynamic> credentials) async {
    try {
      final refreshToken = credentials['refresh_token'] as String?;
      final clientId = credentials['client_id'] as String?;
      final clientSecret = credentials['client_secret'] as String?;

      if (refreshToken == null || clientId == null || clientSecret == null) {
        LoggerService.instance.error(
            'Missing refresh token or client credentials for Google Drive',
            tag: 'OAUTH2');
        return false;
      }

      final response = await http.post(
        Uri.parse(_googleTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final tokens = json.decode(response.body) as Map<String, dynamic>;

        // Update stored credentials with new access token
        await CredentialStorageService.instance.updateCredentials(
          StorageType.googleDrive,
          {
            'access_token': tokens['access_token'],
            'expires_in': tokens['expires_in'],
            'expires_at': DateTime.now()
                .add(Duration(seconds: tokens['expires_in'] as int))
                .toIso8601String(),
          },
        );

        LoggerService.instance
            .info('Google Drive token refreshed successfully', tag: 'OAUTH2');
        return true;
      } else {
        LoggerService.instance.error(
            'Failed to refresh Google Drive token: ${response.statusCode}',
            tag: 'OAUTH2');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Google Drive token refresh failed', e, stack,
          tag: 'OAUTH2');
      return false;
    }
  }

  /// Refresh OneDrive access token
  Future<bool> refreshOneDriveToken(Map<String, dynamic> credentials) async {
    try {
      final refreshToken = credentials['refresh_token'] as String?;
      final clientId = credentials['client_id'] as String?;

      if (refreshToken == null || clientId == null) {
        LoggerService.instance.error(
            'Missing refresh token or client ID for OneDrive',
            tag: 'OAUTH2');
        return false;
      }

      final response = await http.post(
        Uri.parse(_microsoftTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
          'scope': _microsoftScopes,
        },
      );

      if (response.statusCode == 200) {
        final tokens = json.decode(response.body) as Map<String, dynamic>;

        // Update stored credentials with new access token
        await CredentialStorageService.instance.updateCredentials(
          StorageType.oneDrive,
          {
            'access_token': tokens['access_token'],
            'refresh_token': tokens[
                'refresh_token'], // Microsoft may issue new refresh token
            'expires_in': tokens['expires_in'],
            'expires_at': DateTime.now()
                .add(Duration(seconds: tokens['expires_in'] as int))
                .toIso8601String(),
          },
        );

        LoggerService.instance
            .info('OneDrive token refreshed successfully', tag: 'OAUTH2');
        return true;
      } else {
        LoggerService.instance.error(
            'Failed to refresh OneDrive token: ${response.statusCode}',
            tag: 'OAUTH2');
        return false;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'OneDrive token refresh failed', e, stack,
          tag: 'OAUTH2');
      return false;
    }
  }

  /// Build Google OAuth2 authorization URL
  String _buildGoogleAuthUrl(String clientId) {
    final params = {
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'scope': _googleScopes,
      'response_type': 'code',
      'access_type': 'offline',
      'prompt': 'consent',
    };

    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_googleAuthUrl?$query';
  }

  /// Build Microsoft OAuth2 authorization URL
  String _buildMicrosoftAuthUrl(String clientId) {
    final params = {
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'scope': _microsoftScopes,
      'response_type': 'code',
      'response_mode': 'query',
    };

    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_microsoftAuthUrl?$query';
  }

  /// Build Dropbox OAuth2 authorization URL
  String _buildDropboxAuthUrl(String appKey) {
    final params = {
      'client_id': appKey,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
    };

    final query = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return '$_dropboxAuthUrl?$query';
  }

  /// Start local HTTP server for OAuth2 callback
  Future<HttpServer> _startCallbackServer() async {
    return await HttpServer.bind('localhost', 8080);
  }

  /// Open browser with authorization URL
  Future<void> _openBrowser(String url) async {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', url]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    }
  }

  /// Wait for OAuth2 callback with authorization code
  Future<String?> _waitForCallback(HttpServer server) async {
    try {
      await for (final request in server) {
        final uri = request.uri;

        if (uri.path == '/auth/callback') {
          final code = uri.queryParameters['code'];
          final error = uri.queryParameters['error'];

          // Send response to browser
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.html
            ..write(code != null
                ? '<html><body><h1>Authentication Successful!</h1><p>You can close this window.</p></body></html>'
                : '<html><body><h1>Authentication Failed!</h1><p>Error: $error</p></body></html>');
          await request.response.close();

          await server.close();
          return code;
        }
      }
    } catch (e) {
      await server.close();
      LoggerService.instance
          .error('Error waiting for OAuth2 callback: $e', tag: 'OAUTH2');
    }

    return null;
  }

  /// Exchange Google authorization code for tokens
  Future<Map<String, dynamic>?> _exchangeGoogleCodeForTokens(
      String clientId, String clientSecret, String code) async {
    try {
      final response = await http.post(
        Uri.parse(_googleTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        LoggerService.instance.error(
            'Google token exchange failed: ${response.statusCode} ${response.body}',
            tag: 'OAUTH2');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance
          .logException('Google token exchange error', e, stack, tag: 'OAUTH2');
      return null;
    }
  }

  /// Exchange Microsoft authorization code for tokens
  Future<Map<String, dynamic>?> _exchangeMicrosoftCodeForTokens(
      String clientId, String code) async {
    try {
      final response = await http.post(
        Uri.parse(_microsoftTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'client_id': clientId,
          'scope': _microsoftScopes,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        LoggerService.instance.error(
            'Microsoft token exchange failed: ${response.statusCode} ${response.body}',
            tag: 'OAUTH2');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Microsoft token exchange error', e, stack,
          tag: 'OAUTH2');
      return null;
    }
  }

  /// Exchange Dropbox authorization code for tokens
  Future<Map<String, dynamic>?> _exchangeDropboxCodeForTokens(
      String appKey, String appSecret, String code) async {
    try {
      final response = await http.post(
        Uri.parse(_dropboxTokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': _redirectUri,
          'client_id': appKey,
          'client_secret': appSecret,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        LoggerService.instance.error(
            'Dropbox token exchange failed: ${response.statusCode} ${response.body}',
            tag: 'OAUTH2');
        return null;
      }
    } catch (e, stack) {
      LoggerService.instance.logException(
          'Dropbox token exchange error', e, stack,
          tag: 'OAUTH2');
      return null;
    }
  }
}
