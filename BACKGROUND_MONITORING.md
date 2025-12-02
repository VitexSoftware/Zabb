# Zabb Background Monitoring Implementation

This document describes the background monitoring system implemented for the Zabb Android app to continuously monitor Zabbix alerts.

## Features Implemented

### 1. Persistent Background Service
- **Service**: `flutter_foreground_task` with 15-second polling interval
- **Configuration**: 
  - `allowWakeLock: true` - Prevents device from sleeping during monitoring
  - `autoRunOnBoot: true` - Automatically starts monitoring after device reboot
  - `foregroundServiceType: dataSync` - Proper service classification for Android
- **Location**: `lib/background/zabbix_foreground_task.dart`

### 2. Zabbix Polling Service
- **Service**: `ZabbixPollingService` extracts and reuses existing API logic
- **Features**:
  - Connection state tracking
  - Alert severity classification (0-5 levels)
  - New alert detection (prevents duplicate notifications)
  - Authentication management with token caching
- **Location**: `lib/services/zabbix_polling_service.dart`

### 3. Notification System
- **Service**: `NotificationService` handles full-screen alerts with sound
- **Features**:
  - High priority notifications for critical alerts (severity 4-5)
  - Full-screen intent for critical alerts (wakes up locked device)
  - Custom notification channels for different alert types
  - Background service status notifications
  - Sound and vibration enabled
- **Location**: `lib/services/notification_service.dart`

### 4. Android Permissions
The following permissions were added to `AndroidManifest.xml`:
- `FOREGROUND_SERVICE` - Background service execution
- `WAKE_LOCK` - Prevent device sleep during monitoring
- `USE_FULL_SCREEN_INTENT` - Full-screen alerts on locked device
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` - Bypass Android battery optimization
- `RECEIVE_BOOT_COMPLETED` - Auto-start after device reboot

### 5. Battery Optimization Exemption
- Automatically requests battery optimization exemption during first login
- Ensures consistent background monitoring even in Doze mode
- Users can manually grant this permission via Android settings

## Implementation Details

### Background Task Handler
The `ZabbixTaskHandler` class implements the core background logic:
- Polls Zabbix API every 15 seconds
- Maintains service status notification
- Detects new alerts and sends notifications
- Handles connection errors gracefully
- Updates main app isolate with status information

### Auto-Start System
- Background monitoring starts automatically after successful login
- Service is stopped when user logs out
- Service persists across app restarts and device reboots

### Alert Detection Logic
- Tracks previously seen alert event IDs
- Only notifies for new, unacknowledged alerts
- Critical alerts (severity 4-5) trigger full-screen notifications
- Regular alerts use high-priority notifications

## Usage

### Starting Monitoring
Background monitoring starts automatically when:
1. User successfully logs in via auto-login
2. User manually logs in using the login button

### Stopping Monitoring
Background monitoring stops when:
1. User logs out from the app
2. User manually stops it (if implementation is added to UI)

### Alert Behavior
When active problems are detected:
- Critical alerts: Full-screen notification with sound (wakes device)
- Regular alerts: High-priority notification with sound
- Service notification shows current problem count
- Connection errors are displayed in service notification

## Build Requirements

### Android Configuration
- **Minimum SDK**: API 23 (Android 6.0) - Required by flutter_foreground_task
- **Target SDK**: Latest available
- **Compile SDK**: 35 - Required by notification plugins

### Dependencies Added
```yaml
flutter_foreground_task: ^6.0.0
flutter_local_notifications: ^17.0.0
```

## Testing

### To test the implementation:
1. Configure Zabbix server settings in the app
2. Log in with valid credentials
3. Verify "Background monitoring started" message appears
4. Check Android notification panel for "Zabbix Monitor Active" persistent notification
5. Lock the device and wait for active alerts to test notification behavior

### Battery Optimization Testing
1. Go to Android Settings > Apps > Zabb > Battery
2. Verify "Not optimized" status (should be set automatically)
3. Test monitoring during Doze mode by leaving device idle for extended periods

## File Structure

```
lib/
├── background/
│   └── zabbix_foreground_task.dart     # Background task handler
├── services/
│   ├── notification_service.dart       # Notification management
│   └── zabbix_polling_service.dart     # Zabbix API polling logic
└── main.dart                          # Modified for background service initialization

android/
├── app/
│   ├── build.gradle                   # Updated SDK versions
│   └── src/main/
│       ├── AndroidManifest.xml        # Added permissions and service config
│       └── res/raw/
│           └── readme.txt            # Sound file placeholder
```

## Known Limitations

1. **Sound Files**: Custom alert sounds need to be manually added to `android/app/src/main/res/raw/`
2. **iOS Support**: Current implementation is Android-focused
3. **Network Reliability**: Poor network connections may cause polling interruptions
4. **Battery Usage**: Continuous background monitoring will impact battery life

## Future Enhancements

1. Add custom sound file management in app UI
2. Implement configurable polling intervals
3. Add alert acknowledgment from notifications
4. iOS foreground service implementation
5. Network connectivity awareness and retry logic
6. Battery usage optimization options