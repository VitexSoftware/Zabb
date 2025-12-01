# Release Notes - Zabb v0.1.0

**Release Date:** December 1, 2025

## 🎉 Initial Release

Zabb is a Flutter-based mobile client for Zabbix monitoring that brings powerful server monitoring capabilities to your mobile device.

## ✨ Key Features

### 🔐 Authentication & Security
- Secure authentication with Zabbix server using JSON-RPC 2.0
- Auto-login functionality with saved credentials
- Bearer token authentication for API security

### 📊 Problems Dashboard
- Real-time problems monitoring with 30-second auto-refresh
- Visual countdown timer showing next refresh
- Sortable table with severity, start time, duration, problem name, and hostname
- Item count display showing filtered results

### 🔍 Advanced Filtering
- Filter problems by severity level (tap severity dots)
- Filter problems by hostname (tap hostname labels)
- Persistent filters that survive refresh cycles
- Toggle filters on/off with visual indicators

### 📱 Mobile-Optimized UI
- Responsive design optimized for mobile screens
- Clean, professional table layout with proper column alignment
- Intuitive navigation and touch-friendly controls
- Consistent black text for readability

### 🛠️ Problem Management
- Detailed problem view with comprehensive information
- Acknowledge problems directly from the mobile app
- Close problems with proper workflow
- View acknowledgment history and user information
- Display problem tags and metadata

### 🖥️ Host Integration
- Automatic host name resolution from trigger IDs
- Host-based filtering capabilities
- No more numeric IDs - see actual server names

## 🔧 Technical Specifications

### Framework & Dependencies
- **Flutter:** 3.24.4 stable
- **Dart:** 3.5.4
- **HTTP:** API communication with Zabbix servers
- **SharedPreferences:** Local configuration storage
- **Intl:** Date/time formatting
- **Flutter SVG:** Vector graphics support

### Platform Support
- ✅ **Android** - Mobile phones and tablets
- ✅ **Linux Desktop** - Full desktop experience
- ✅ **Web** - Browser-based access
- ⚠️ **iOS** - Framework ready (requires Apple Developer account)

### Zabbix Compatibility
- **Supported Versions:** Zabbix 6.0+
- **API Protocol:** JSON-RPC 2.0
- **Authentication:** Bearer token with automatic re-authentication
- **Tested Features:** Problems, Hosts, Triggers, Events, Acknowledgments

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point and login screen
├── api/
│   └── zabbix_api.dart      # Zabbix API client implementation
├── screens/
│   ├── problems_screen.dart  # Main problems dashboard
│   ├── welcome_screen.dart   # First-time setup screen
│   └── configure_server_screen.dart  # Server configuration
├── services/
│   └── auth_service.dart     # Authentication and data services
└── assets/
    ├── zabb.svg             # Application logo
    └── nymfette3-smile.png  # Character image
```

## 🚀 Getting Started

### Installation Requirements
1. Flutter SDK 3.2.0+
2. Dart 3.5.4+
3. Access to a Zabbix server with API enabled

### Quick Setup
1. Download the release package
2. Extract and run: `flutter pub get`
3. Launch: `flutter run`
4. Configure your Zabbix server connection
5. Start monitoring!

## 🔄 Auto-Refresh System
- **Interval:** 30 seconds
- **Visual Feedback:** Countdown timer in header
- **Filter Persistence:** Maintains selected filters across refreshes
- **Status Indicators:** Shows item count and refresh status

## 🎨 User Interface Highlights
- **Header:** Shows app logo, item count, countdown, settings, and logout
- **Severity Indicators:** Color-coded dots for problem severity levels
- **Clickable Columns:** Tap Start, Duration, or Name to view problem details
- **Filter Indicators:** Visual feedback for active severity/hostname filters
- **Responsive Tables:** Properly aligned columns that work on all screen sizes

## 🐛 Known Issues
- None reported in initial release
- All core functionality tested and working

## 📈 Future Roadmap
- Push notifications for new problems
- Dashboard widgets and graphs
- Maintenance period management
- Multi-server support
- Offline mode with sync
- Dark theme support

## 🤝 Contributing
We welcome contributions! Please see our GitHub repository for contribution guidelines.

## 📄 License
MIT License - see LICENSE file for details

---

**Download Links:**
- Source Code: Available on GitHub
- Linux Binary: `build/linux/x64/release/bundle/zabb`
- Documentation: README.md in repository

**System Requirements:**
- Linux: Ubuntu 18.04+ or equivalent
- Android: API level 21+ (Android 5.0+)
- Web: Modern browser with JavaScript enabled

**Support:**
- Issues: GitHub Issues tracker
- Documentation: Repository README
- API Reference: Zabbix API documentation

---

*Zabb v0.1.0 - Making Zabbix monitoring mobile and accessible.*