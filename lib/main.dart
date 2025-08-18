import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:launcher/screens/launcher_screen.dart';
import 'package:launcher/services/config_service.dart';
import 'package:launcher/services/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  LoggerService.instance.info('Starting Launcher App...', tag: 'MAIN');
  
  try {
    // Initialize window manager for Windows
    await windowManager.ensureInitialized();
    LoggerService.instance.info('Window manager initialized', tag: 'MAIN');
    
    // Load app configuration early so we can set the title
    await ConfigService.instance.loadConfig();
    LoggerService.instance.info('App configuration loaded', tag: 'MAIN');

    final String appTitle = ConfigService.instance.config?.appName ?? 'Launcher App';

    // Set window properties
    WindowOptions windowOptions = const WindowOptions(
      size: Size(800, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      minimumSize: Size(600, 400),
    );
    
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setTitle(appTitle);
      LoggerService.instance.info('Window displayed and focused', tag: 'MAIN');
    });
    
    runApp(const LauncherApp());
    LoggerService.instance.info('App started successfully', tag: 'MAIN');
  } catch (e, stackTrace) {
    LoggerService.instance.logException('Failed to start app', e, stackTrace, tag: 'MAIN');
    rethrow;
  }
}

class LauncherApp extends StatelessWidget {
  const LauncherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: ConfigService.instance.config?.appName ?? 'Launcher App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const LauncherScreen(),
    );
  }
}
