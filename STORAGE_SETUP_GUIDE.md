# Storage Setup Guide

A comprehensive guide for configuring all supported storage providers in your launcher app.

## 📋 Table of Contents

- [Currently Supported Storage Providers](#currently-supported)
- [GitHub Setup](#github-setup)
- [Google Drive Setup](#google-drive-setup)
- [OneDrive Setup](#onedrive-setup)
- [Dropbox Setup](#dropbox-setup)
- [MEGA Setup](#mega-setup)
- [Other Free Storage Options](#other-free-options)
- [Configuration Examples](#configuration-examples)
- [File Size & Storage Limits](#storage-limits)
- [Troubleshooting](#troubleshooting)

## 🎯 Currently Supported Storage Providers {#currently-supported}

| Provider | Free Storage | Max File Size | API Support | Large Files (2-3GB) |
|----------|--------------|---------------|-------------|---------------------|
| ✅ **GitHub** | Unlimited* | 100MB (LFS: 2GB) | ✅ Git API | ✅ (with LFS) |
| ✅ **Google Drive** | 15GB | 750GB | ✅ Drive API v3 | ✅ |
| ✅ **OneDrive** | 5GB | 250GB | ✅ Graph API | ✅ |
| ✅ **Dropbox** | 2GB | No limit | ✅ API v2 | ✅ |
| ✅ **MEGA** | 20GB | No limit | ✅ MEGA API | ✅ |

*GitHub: Free for public repos, paid for private repos

---

## 🐙 GitHub Setup {#github-setup}

### Requirements
- GitHub account (free)
- Public repository (for free hosting)
- Git LFS for files > 100MB

### Step 1: Create Repository
1. Go to [GitHub](https://github.com)
2. Click **"New repository"**
3. Set repository name (e.g., `my-app-releases`)
4. Choose **Public** (for free hosting)
5. Initialize with README
6. Click **"Create repository"**

### Step 2: Enable Git LFS (for large files)
```bash
# In your repository
git lfs install
git lfs track "*.zip"
git lfs track "*.exe"
git add .gitattributes
git commit -m "Add LFS tracking"
```

### Step 3: Upload Your App Files
```bash
# Clone repository
git clone https://github.com/yourusername/my-app-releases.git
cd my-app-releases

# Add your app files
cp /path/to/your/app.zip .
git add app.zip
git commit -m "Add app release"
git push origin main
```

### Step 4: Configure App Settings
```json
{
  "storage": {
    "type": "github",
    "github": {
      "url": "https://github.com/yourusername/my-app-releases",
      "branch": "main"
    }
  }
}
```

---

## 🔵 Google Drive Setup {#google-drive-setup}

### Requirements
- Google account (free)
- Google Cloud Console project
- Drive API enabled

### Step 1: Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click **"New Project"**
3. Enter project name
4. Click **"Create"**

### Step 2: Enable Drive API
1. In your project, go to **"APIs & Services" > "Library"**
2. Search for **"Google Drive API"**
3. Click on it and press **"Enable"**

### Step 3: Create Credentials
1. Go to **"APIs & Services" > "Credentials"**
2. Click **"Create Credentials" > "OAuth 2.0 Client IDs"**
3. Configure consent screen if prompted
4. Choose **"Desktop Application"**
5. Set name and create
6. Download the JSON file

### Step 4: Create Drive Folder
1. Open [Google Drive](https://drive.google.com)
2. Create a new folder (e.g., "My App Releases")
3. Right-click folder → **"Share"**
4. Copy the folder ID from URL: `https://drive.google.com/drive/folders/FOLDER_ID_HERE`

### Step 5: Upload App Files
1. Upload your `app.zip` to the created folder
2. Ensure folder has proper sharing permissions

### Step 6: Authentication
**🎉 No manual credential files needed!** The app handles authentication automatically:

1. **First Launch**: App detects missing Google Drive credentials
2. **OAuth2 Flow**: Browser opens for Google login
3. **User Consent**: You authorize the app to access Google Drive
4. **Auto-Save**: Credentials are securely stored by the app
5. **Done**: Future launches authenticate automatically

### Step 6: Configure App Settings
```json
{
  "storage": {
    "type": "google_drive",
    "google_drive": {
      "client_id": "your_client_id.apps.googleusercontent.com",
      "folder_id": "your_folder_id_from_step_4",
      "credentials_path": "assets/credentials/google_drive_credentials.json"
    }
  }
}
```

---

## Ⓜ️ OneDrive Setup {#onedrive-setup}

### Requirements
- Microsoft account (free)
- Azure app registration
- OneDrive personal account

### Step 1: Create Azure App Registration
1. Go to [Azure Portal](https://portal.azure.com/)
2. Navigate to **"Azure Active Directory" > "App registrations"**
3. Click **"New registration"**
4. Set application name
5. Choose **"Accounts in any organizational directory and personal Microsoft accounts"**
6. Set Redirect URI: `http://localhost:8080/callback`
7. Click **"Register"**
8. Copy the **Application (client) ID**

### Step 2: Configure API Permissions
1. In your app registration, go to **"API permissions"**
2. Click **"Add a permission"**
3. Choose **"Microsoft Graph"**
4. Select **"Delegated permissions"**
5. Add these permissions:
   - `Files.Read`
   - `Files.ReadWrite`
   - `User.Read`
6. Click **"Grant admin consent"**

### Step 3: Create OneDrive Folder
1. Open [OneDrive](https://onedrive.live.com)
2. Create folder structure: `/Apps/YourAppName/`
3. Upload your `app.zip` file to this folder

### Step 4: Get Access Token
Use Microsoft's OAuth2 flow to get access token. For testing, you can use [Graph Explorer](https://developer.microsoft.com/en-us/graph/graph-explorer).

### Step 5: Authentication
**🎉 No manual credential files needed!** The app handles authentication automatically:

1. **First Launch**: App detects missing OneDrive credentials
2. **OAuth2 Flow**: Browser opens for Microsoft login
3. **User Consent**: You authorize the app to access OneDrive
4. **Auto-Save**: Credentials are securely stored by the app
5. **Done**: Future launches authenticate automatically

### Step 6: Configure App Settings
```json
{
  "storage": {
    "type": "onedrive",
    "onedrive": {
      "client_id": "your_azure_app_client_id",
      "folder_path": "/Apps/YourAppName",
      "credentials_path": "assets/credentials/onedrive_credentials.json"
    }
  }
}
```

---

## 📦 Dropbox Setup {#dropbox-setup}

### Requirements
- Dropbox account (free)
- Dropbox app registration

### Step 1: Create Dropbox App
1. Go to [Dropbox App Console](https://www.dropbox.com/developers/apps)
2. Click **"Create app"**
3. Choose **"Scoped access"**
4. Choose **"App folder"** or **"Full Dropbox"**
5. Enter app name
6. Click **"Create app"**
7. Copy the **App key**

### Step 2: Configure App Permissions
1. In your app settings, go to **"Permissions"**
2. Enable these scopes:
   - `files.metadata.read`
   - `files.content.read`
   - `files.content.write`

### Step 3: Generate Access Token
1. In your app settings, scroll to **"OAuth 2"**
2. Click **"Generate access token"**
3. Copy the generated token

### Step 4: Create Dropbox Folder
1. Open [Dropbox](https://www.dropbox.com)
2. Create folder: `/Apps/YourAppName/` (if using App folder)
3. Upload your `app.zip` file

### Step 5: Authentication
**🎉 No manual credential files needed!** The app handles authentication automatically:

1. **First Launch**: App detects missing Dropbox credentials
2. **OAuth2 Flow**: Browser opens for Dropbox login
3. **User Consent**: You authorize the app to access Dropbox
4. **Auto-Save**: Credentials are securely stored by the app
5. **Done**: Future launches authenticate automatically

### Step 6: Configure App Settings
```json
{
  "storage": {
    "type": "dropbox",
    "dropbox": {
      "app_key": "your_dropbox_app_key",
      "folder_path": "/Apps/YourAppName"
    }
  }
}
```

---

## 🔥 MEGA Setup {#mega-setup}

### Requirements
- MEGA account (free)
- Email and password for authentication

### Step 1: Create MEGA Account
1. Go to [MEGA](https://mega.nz/)
2. Click **"Create Account"**
3. Enter email and password
4. Verify your email address
5. Note down your login credentials

### Step 2: Create Folder Structure
1. Login to [MEGA Web Interface](https://mega.nz/fm)
2. Create folder: **"Apps"**
3. Inside Apps, create: **"YourAppName"**
4. Upload your `app.zip` file to this folder

### Step 3: Configure App Settings
```json
{
  "storage": {
    "type": "mega",
    "mega": {
      "email": "your_mega_email@example.com",
      "password": "your_mega_password",
      "folder_path": "/Apps/YourAppName"
    }
  }
}
```

### Step 4: Where to Find MEGA Information

| Setting | Where to Find It | Example |
|---------|------------------|---------|
| **email** | Your MEGA account email | `user@example.com` |
| **password** | Your MEGA account password | `your_secure_password` |
| **folder_path** | Path in your MEGA cloud storage | `/Apps/YourAppName` |
| **credentials_path** | Local file for session storage | `assets/credentials/mega_credentials.json` |

### Step 5: MEGA Account Creation Details
1. **Go to MEGA**: Visit [https://mega.nz/](https://mega.nz/)
2. **Click "Create Account"**: In the top right corner
3. **Choose Plan**: Select "Free" for 20GB storage
4. **Enter Details**:
   - Email address (this becomes your `email` setting)
   - Password (this becomes your `password` setting)
   - Confirm password
5. **Verify Email**: Check your email for verification link
6. **Login**: Your account is ready to use

### Step 6: Benefits of MEGA
- ✅ **20GB Free Storage** (largest free tier)
- ✅ **No File Size Limits**
- ✅ **End-to-End Encryption**
- ✅ **Good API Performance**
- ✅ **Privacy Focused**

### Step 7: Security Notes
- MEGA uses client-side encryption
- Your password is never sent to servers in plain text
- Keep your credentials secure
- Consider using app-specific passwords

### Step 8: Authentication
**🎉 No manual credential files needed!** The app handles authentication automatically:

1. **First Launch**: App uses your configured email/password
2. **MEGA Login**: App authenticates with MEGA API directly
3. **Session Management**: Creates encrypted session automatically
4. **Auto-Renewal**: Sessions refresh every hour automatically
5. **Done**: Secure credential storage with automatic management

---

## 🔐 Automatic Credential Management {#credentials-management}

### ✨ **Zero-Configuration Security**
The launcher app handles ALL credential management automatically:

- **🚫 No Manual Files**: No need to create or manage credential files
- **🔒 Secure Storage**: Uses Flutter's `flutter_secure_storage` for encrypted credential storage
- **🔄 Auto-Refresh**: OAuth2 tokens automatically refresh before expiration
- **🛡️ OS-Level Security**: Leverages platform keychains (Windows Credential Manager, macOS Keychain, Linux Secret Service)

### 🎯 **First-Time Authentication Flow**

#### **Google Drive / OneDrive / Dropbox (OAuth2)**
```
1. Configure app_settings.json with client_id and folder info
2. Launch app → Detects missing credentials
3. OAuth2 browser window opens automatically
4. User logs in and grants permissions
5. App receives tokens and stores them securely
6. Future launches: Automatic authentication
```

#### **MEGA (Email/Password)**
```
1. Configure app_settings.json with email, password, folder
2. Launch app → Uses credentials to authenticate with MEGA API
3. App creates secure session and stores encrypted
4. Sessions auto-refresh every hour
5. Future launches: Seamless authentication
```

### 🔒 **Security Architecture**

#### **Storage Location**
- **Windows**: Windows Credential Manager (`CredWrite`/`CredRead`)
- **macOS**: Keychain Services (`SecItemAdd`/`SecItemCopyMatching`)
- **Linux**: Secret Service API (GNOME Keyring, KWallet)
- **Android**: Android Keystore with AES encryption
- **iOS**: iOS Keychain with hardware security

#### **Encryption Details**
- All credentials encrypted at rest using platform-native encryption
- No plaintext credential storage
- Automatic cleanup when switching storage providers
- Secure key derivation using platform cryptographic APIs

#### **Token Management**
```
Google Drive:   OAuth2 → Auto-refresh every 55 min
OneDrive:       OAuth2 → Auto-refresh every 55 min  
Dropbox:        OAuth2 → Long-lived tokens with validation
MEGA:           Session → Auto-refresh every 55 min
```

### 🛠️ **Troubleshooting**

#### **Authentication Issues**
```bash
# Clear all stored credentials (if needed)
flutter clean
# Or implement "Logout" button in app to call:
# CredentialStorageService.instance.clearAllCredentials()
```

#### **Token Refresh Problems**
- App automatically handles refresh failures by triggering re-authentication
- Users will see OAuth2 flow again if refresh tokens are invalid
- No manual intervention required

---

## 🌟 Other Free Storage Options {#other-free-options}

### For Large Files (2-3GB Support)

| Provider | Free Storage | Max File Size | API Available | Ease of Setup |
|----------|--------------|---------------|---------------|---------------|
| **pCloud** | 10GB | No limit | ✅ | Easy |
| **Koofr** | 10GB | No limit | ✅ | Easy |
| **Yandex.Disk** | 10GB | No limit | ✅ | Medium |
| **Box** | 10GB | 250MB* | ✅ | Easy |
| **MediaFire** | 10GB | 4GB | ✅ | Easy |
| **Backblaze B2** | 10GB | 5TB | ✅ | Advanced |

*Box: 250MB for free accounts, larger files require paid plan

### Recommended for Your Use Case

1. **pCloud** - 10GB with lifetime free account option
3. **Koofr** - 10GB with good API and European privacy laws
4. **Yandex.Disk** - 10GB with robust API from Russian tech giant

### Implementation Priority
If you want to add more providers:
1. **pCloud** (10GB free) - User-friendly
3. **Koofr** (10GB free) - Privacy-focused

---

## 📁 Configuration Examples {#configuration-examples}

### Complete app_settings.json Example
```json
{
  "app_name": "My Awesome App Launcher",
  "storage": {
    "type": "google_drive",
    "github": {
      "url": "https://github.com/username/app-releases",
      "branch": "main"
    },
    "google_drive": {
      "client_id": "123456789.apps.googleusercontent.com",
      "folder_id": "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms",
      "credentials_path": "assets/credentials/google_drive_credentials.json"
    },
    "onedrive": {
      "client_id": "12345678-1234-1234-1234-123456789012",
      "folder_path": "/Apps/MyAwesomeApp",
      "credentials_path": "assets/credentials/onedrive_credentials.json"
    },
    "dropbox": {
      "app_key": "abcdefghijklmnop",
      "folder_path": "/Apps/MyAwesomeApp",
      "credentials_path": "assets/credentials/dropbox_credentials.json"
    }
  },
  "local_folder": "C:\\Program Files\\MyAwesomeApp",
  "background_image": "assets/images/bg.jpg",
  "update_check_interval": 300000,
  "exe_file_name": "MyAwesomeApp.exe",
  "app_icon": "assets/icons/app.ico"
}
```

### Switching Between Providers
Simply change the `type` field:
```json
{
  "storage": {
    "type": "dropbox"  // github | google_drive | onedrive | dropbox
  }
}
```

---

## 📊 File Size & Storage Limits {#storage-limits}

### Large File Handling (2-3GB)

| Provider | Strategy | Notes |
|----------|----------|-------|
| **GitHub** | Use Git LFS | Best for version control |
| **Google Drive** | Direct upload | 750GB max file size |
| **OneDrive** | Direct upload | 250GB max file size |
| **Dropbox** | Direct upload | No file size limit |
| **MEGA** | Direct upload | No file size limit, 20GB storage |

### Recommended File Structure
```
📁 YourApp/
├── 📄 app.zip          (Main application archive)
├── 📄 version.txt      (Version information)
├── 📄 changelog.md     (Update history)
└── 📁 assets/          (Additional resources)
```

---

## 🔧 Troubleshooting {#troubleshooting}

### Common Issues

#### Authentication Errors
- **Problem**: "Authentication failed"
- **Solution**: Check credentials file exists and contains valid tokens
- **Check**: Verify file paths in configuration

#### File Not Found
- **Problem**: "No app files found"
- **Solution**: Ensure `app.zip` exists in configured folder/repository
- **Check**: Verify folder paths and permissions

#### Large File Upload Issues
- **GitHub**: Use Git LFS for files > 100MB
- **Google Drive**: Check file size limits (750GB max)
- **OneDrive**: Check file size limits (250GB max)
- **Dropbox**: Should handle any file size

#### Quota Exceeded
- **Problem**: "Storage quota exceeded"
- **Solutions**: 
  - Clean up old files
  - Switch to provider with more storage
  - Upgrade to paid plan

### Debug Mode
Enable debug logging in your app to see detailed error messages:
```json
{
  "debug_mode": true,
  "log_level": "verbose"
}
```

### Support Resources
- **GitHub**: [GitHub API Documentation](https://docs.github.com/en/rest)
- **Google Drive**: [Drive API Documentation](https://developers.google.com/drive/api)
- **OneDrive**: [Graph API Documentation](https://docs.microsoft.com/en-us/graph/api/resources/onedrive)
- **Dropbox**: [Dropbox API Documentation](https://www.dropbox.com/developers/documentation)

---

## 🚀 Next Steps

1. Choose your preferred storage provider based on your needs
2. Follow the setup guide for your chosen provider
3. Test with a small file first
4. Upload your full application
5. Configure the launcher with your settings
6. Test the update mechanism

### Quick Start Recommendations

- **For Beginners**: Start with **Dropbox** (easiest setup)
- **For Developers**: Use **GitHub** (version control benefits)
- **For Large Files**: Use **MEGA** (20GB free) or **Google Drive**
- **For Privacy**: Use **OneDrive** or **Koofr**

---

*Last updated: December 2024*
