import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error, critical }

class LoggerService {
  static final LoggerService instance = LoggerService._internal();
  factory LoggerService() => instance;
  LoggerService._internal();

  static const String _tag = '[LAUNCHER]';

  void log(String message, {LogLevel level = LogLevel.info, String? tag, Object? error, StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase();
    final tagStr = tag != null ? '[$tag]' : '';
    
    final logMessage = '$_tag$tagStr [$levelStr] $timestamp: $message';
    
    // Console output
    if (kDebugMode) {
      switch (level) {
        case LogLevel.debug:
          developer.log(logMessage, name: 'DEBUG');
          break;
        case LogLevel.info:
          developer.log(logMessage, name: 'INFO');
          break;
        case LogLevel.warning:
          developer.log(logMessage, name: 'WARNING');
          break;
        case LogLevel.error:
          developer.log(logMessage, name: 'ERROR');
          break;
        case LogLevel.critical:
          developer.log(logMessage, name: 'CRITICAL');
          break;
      }
    }
    
    // Print to console for immediate visibility
    print(logMessage);
    
    // Log errors with stack trace
    if (error != null) {
      print('$_tag$tagStr [$levelStr] Error details: $error');
      if (stackTrace != null) {
        print('$_tag$tagStr [$levelStr] Stack trace:');
        print(stackTrace);
      }
    }
  }

  void debug(String message, {String? tag}) => log(message, level: LogLevel.debug, tag: tag);
  void info(String message, {String? tag}) => log(message, level: LogLevel.info, tag: tag);
  void warning(String message, {String? tag}) => log(message, level: LogLevel.warning, tag: tag);
  void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) => 
      log(message, level: LogLevel.error, tag: tag, error: error, stackTrace: stackTrace);
  void critical(String message, {String? tag, Object? error, StackTrace? stackTrace}) => 
      log(message, level: LogLevel.critical, tag: tag, error: error, stackTrace: stackTrace);

  void logException(String message, Object error, StackTrace stackTrace, {String? tag}) {
    log(message, level: LogLevel.error, tag: tag, error: error, stackTrace: stackTrace);
  }

  void logGitOperation(String operation, {String? details, Object? error, StackTrace? stackTrace}) {
    if (error != null) {
      log('Git operation failed: $operation', level: LogLevel.error, tag: 'GIT', error: error, stackTrace: stackTrace);
    } else {
      log('Git operation: $operation${details != null ? ' - $details' : ''}', level: LogLevel.info, tag: 'GIT');
    }
  }

  void logProcessOperation(String operation, {String? details, Object? error, StackTrace? stackTrace}) {
    if (error != null) {
      log('Process operation failed: $operation', level: LogLevel.error, tag: 'PROCESS', error: error, stackTrace: stackTrace);
    } else {
      log('Process operation: $operation${details != null ? ' - $details' : ''}', level: LogLevel.info, tag: 'PROCESS');
    }
  }

  void logConnectivityCheck(bool isConnected, {String? details}) {
    log('Connectivity check: ${isConnected ? 'Online' : 'Offline'}${details != null ? ' - $details' : ''}', level: LogLevel.info, tag: 'NETWORK');
  }
}
