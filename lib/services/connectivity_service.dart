import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:launcher/services/logger_service.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();
  factory ConnectivityService() => instance;
  ConnectivityService._internal();

  Future<bool> isConnected() async {
    try {
      LoggerService.instance.logConnectivityCheck(false, details: 'Checking connectivity...');
      
      final connectivityResults = await Connectivity().checkConnectivity();
      // connectivity_plus 7.0.0+ returns List<ConnectivityResult>
      final connectivityResult = connectivityResults.isNotEmpty ? connectivityResults.first : ConnectivityResult.none;
      if (connectivityResult == ConnectivityResult.none) {
        LoggerService.instance.logConnectivityCheck(false, details: 'No network interface available');
        return false;
      }
      
      // Additional check to ensure actual internet connectivity
      final result = await InternetAddress.lookup('google.com');
      final isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      LoggerService.instance.logConnectivityCheck(isConnected, details: 'Connectivity result: $connectivityResult');
      return isConnected;
    } catch (e) {
      LoggerService.instance.logConnectivityCheck(false, details: 'Error: $e');
      return false;
    }
  }

  Future<bool> canReachGitHub() async {
    try {
      final result = await InternetAddress.lookup('github.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Stream<ConnectivityResult> get connectivityStream {
    // connectivity_plus 7.0.0+ returns Stream<List<ConnectivityResult>>
    // Transform it to Stream<ConnectivityResult> for backward compatibility
    return Connectivity().onConnectivityChanged.map((results) => 
      results.isNotEmpty ? results.first : ConnectivityResult.none
    );
  }
}
