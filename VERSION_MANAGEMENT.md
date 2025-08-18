# Version Management Guide

## Overview
The Launcher App uses a comprehensive version management system that integrates with GitHub tags for automatic version detection and comparison.

## Version Format
- **Format**: `vX.Y.Z` (e.g., `v1.0.0`, `v2.1.3`)
- **X**: Major version (breaking changes)
- **Y**: Minor version (new features, backward compatible)
- **Z**: Patch version (bug fixes, backward compatible)

## Version Sources

### 1. Local Version (Hardcoded)
- **Location**: `lib/services/version_service.dart`
- **Purpose**: Current app version
- **Update**: Manual update in code before release

```dart
static const String _currentVersion = '1.0.0';
static const String _buildNumber = '1';
```

### 2. GitHub Tags (Recommended)
- **Purpose**: Source of truth for latest available version
- **Update**: Create Git tags in your repository
- **Benefits**: 
  - Automatic version detection
  - Centralized version management
  - Easy rollback and release tracking

## Recommended Version Management Workflow

### 1. Semantic Versioning
Follow [Semantic Versioning 2.0.0](https://semver.org/) principles:
- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### 2. GitHub Tag Creation
```bash
# Create and push a new version tag
git tag v1.0.0
git push origin v1.0.0

# Create annotated tag (recommended)
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### 3. Release Process
1. **Update Code**: Make your changes
2. **Update Version**: Modify `version_service.dart`
3. **Create Tag**: `git tag vX.Y.Z`
4. **Push Tag**: `git push origin vX.Y.Z`
5. **Build App**: Use build scripts
6. **Distribute**: Share the built executable

## Alternative Version Management Strategies

### Option 1: Version File (version.txt)
```txt
1.0.0
```
**Pros**: Simple, easy to update
**Cons**: Manual file management, no Git integration

### Option 2: Package Version (pubspec.yaml)
```yaml
version: 1.0.0+1
```
**Pros**: Flutter standard, automatic build numbering
**Cons**: Requires rebuild for version changes

### Option 3: Environment Variables
```bash
export APP_VERSION=1.0.0
```
**Pros**: Flexible, CI/CD friendly
**Cons**: Platform dependent, deployment complexity

## Current Implementation

The app uses a hybrid approach:
1. **Local Version**: Hardcoded in `VersionService`
2. **GitHub Integration**: Fetches latest tags for comparison
3. **Automatic Detection**: Compares versions and shows update availability

## Version Comparison Logic

```dart
bool isUpdateAvailable(String currentVersion, String latestVersion) {
  // Parse versions (e.g., "1.0.0" -> [1, 0, 0])
  // Compare major.minor.patch components
  // Return true if newer version available
}
```

## Benefits of Current System

1. **Automatic Updates**: Detects new versions without manual intervention
2. **User Experience**: Shows update availability clearly
3. **Developer Friendly**: Simple tag-based workflow
4. **Flexible**: Can work offline with local version
5. **Professional**: Industry-standard versioning approach

## Best Practices

1. **Always Tag Releases**: Create Git tags for each release
2. **Use Semantic Versioning**: Follow MAJOR.MINOR.PATCH format
3. **Update Local Version**: Keep `version_service.dart` in sync
4. **Test Version Detection**: Verify GitHub integration works
5. **Document Changes**: Use meaningful commit messages and tag descriptions

## Troubleshooting

### Version Not Detected
- Check GitHub repository URL in config
- Verify tag format (should start with 'v')
- Ensure repository is public or has proper access

### Version Comparison Issues
- Verify version format (X.Y.Z)
- Check for leading 'v' in tags
- Ensure proper error handling in logs

### Build Number Management
- Increment build number for each release
- Use CI/CD to automate build numbering
- Consider using Git commit hash for unique builds

## Future Enhancements

1. **Auto-update**: Download and install new versions
2. **Changelog Integration**: Show what's new in updates
3. **Rollback Support**: Revert to previous versions
4. **Beta Channel**: Support for pre-release versions
5. **Version History**: Track all installed versions

---

**Note**: The current system prioritizes simplicity and reliability. For production use, consider implementing additional security measures and automated testing for version updates.
