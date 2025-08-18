# Launcher App

A modern Windows launcher application built with Flutter that automatically manages GitHub repositories and launches executable files.

## Features

- 🚀 **Automatic Repository Management**: Clones and updates GitHub repositories automatically
- 🔄 **Smart Update Detection**: Checks for updates and notifies when new versions are available
- 🎯 **Executable Launcher**: Finds and launches the first .exe file in the repository
- 🌐 **Connectivity Awareness**: Handles offline scenarios gracefully
- 🎨 **Modern UI**: Beautiful, responsive interface with customizable background
- ⚡ **Real-time Monitoring**: Continuously monitors running processes
- 🔧 **Configurable**: Easy-to-modify JSON configuration

## Requirements

- Windows 10/11
- Flutter SDK 3.10.0 or higher
- Git installed and accessible from command line
- Visual Studio 2019 or higher (for Windows build)

## Installation

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd launcher
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure the app**
   Edit `assets/config/app_settings.json` with your settings:
   ```json
   {
     "app_name": "My Launcher App",
     "github_repo": {
       "url": "https://github.com/username/repository-name",
       "branch": "main"
     },
     "local_folder": "C:\\Users\\User\\Documents\\GitHub\\repository-name",
     "background_image": "assets/images/background.jpg",
     "update_check_interval": 300000,
     "exe_file_pattern": "*.exe"
   }
   ```

4. **Add background image**
   Place your background image in `assets/images/` folder

5. **Build for Windows**
   ```bash
   flutter build windows
   ```

## Configuration

### App Settings (`assets/config/app_settings.json`)

| Setting | Description | Default |
|---------|-------------|---------|
| `app_name` | Name of the launcher app | "Launcher App" |
| `github_repo.url` | GitHub repository URL | Required |
| `github_repo.branch` | Branch to track | "main" |
| `local_folder` | Local folder path for repository | Required |
| `background_image` | Path to background image | "assets/images/bg.jpg" |
| `update_check_interval` | Update check interval in milliseconds | 300000 (5 minutes) |
| `exe_file_pattern` | Pattern to find executable files | "*.exe" |

## Usage

### Launching the App
1. Run the built executable
2. The app will automatically check for updates
3. Use the two main buttons:
   - **Update/Check Update**: Manages repository updates
   - **Open**: Launches the executable file

### Button States

#### Update Button
- **"Check for Update"**: No updates available, click to manually check
- **"Update Available"**: Updates found, click to download
- **"Checking..."**: Currently checking for updates
- **"Updating..."**: Currently downloading updates
- **Disabled**: When executable is running or offline

#### Open Button
- **"Open"**: Executable found, click to launch
- **"Running"**: Executable is currently running
- **Disabled**: When no executable found or already running

### Status Indicators
- **Online/Offline**: Shows connectivity status
- **Process Monitoring**: Automatically detects running executables

## Architecture

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── app_config.dart      # Configuration models
├── screens/
│   └── launcher_screen.dart # Main UI screen
└── services/
    ├── config_service.dart      # Configuration management
    ├── git_service.dart         # Git operations
    ├── process_service.dart     # Process management
    └── connectivity_service.dart # Network connectivity
```

## Services

### ConfigService
- Loads and manages app configuration
- Provides fallback defaults
- Singleton pattern for global access

### GitService
- Repository cloning and updating
- Update detection via commit hashes
- Branch management

### ProcessService
- Executable file discovery
- Process monitoring
- Application launching

### ConnectivityService
- Internet connectivity detection
- GitHub reachability testing
- Network status monitoring

## Building and Deployment

### Development
```bash
flutter run -d windows
```

### Release Build
```bash
flutter build windows --release
```

### Distribution
The built executable will be in `build/windows/runner/Release/`

## Troubleshooting

### Common Issues

1. **Git not found**
   - Ensure Git is installed and in PATH
   - Restart terminal after Git installation

2. **Permission denied**
   - Run as administrator if accessing protected folders
   - Check folder permissions

3. **Background image not loading**
   - Verify image path in config
   - Ensure image format is supported (JPG, PNG)

4. **Executable not found**
   - Check local folder path in config
   - Ensure repository contains .exe files

### Logs
Check console output for detailed error messages during development.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Search existing issues
3. Create a new issue with detailed information

---

**Note**: This launcher app is designed for Windows only and requires Git to be installed on the system for repository operations.
