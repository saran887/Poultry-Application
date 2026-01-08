# Flutter Mobile App - Backend Integration Guide

## Overview
The Poultry Automation Flutter mobile app now integrates with the Node.js backend API to fetch real-time sensor data and control equipment remotely.

## Features Implemented

### ✅ Real-time Data Fetching
- Temperature monitoring (updates every 5 seconds)
- Humidity monitoring (updates every 5 seconds)
- Water level monitoring with animated tank display
- Equipment status (Fan, Fogger, Sprinkler, Motor)

### ✅ Equipment Control
- Toggle Fan on/off
- Toggle Fogger on/off
- Toggle Sprinkler on/off
- Changes sync immediately with backend
- Automatic revert on connection failure

### ✅ UI Enhancements
- Loading indicator in header during data fetch
- Error messages for connection issues
- Optimistic UI updates for better user experience
- Real-time timestamp updates

## Configuration

### Step 1: Backend Setup

1. **Start the backend server** (see [backend/MOBILE_SETUP.md](../backend/MOBILE_SETUP.md))
   ```bash
   cd backend
   npm start
   ```

2. **Verify backend is running**
   - Open browser and navigate to `http://localhost:8080`
   - You should see: "Server is up and running."

### Step 2: Configure API Endpoint

#### For Android Emulator (Default)
No changes needed! The app uses `10.0.2.2:8080` by default, which maps to your computer's `localhost:8080`.

#### For Physical Android Device

1. **Find your computer's local IP address:**

   **Windows:**
   ```powershell
   ipconfig
   ```
   Look for "IPv4 Address" (e.g., 192.168.1.100)

   **Mac/Linux:**
   ```bash
   ifconfig
   # or
   ip addr show
   ```

2. **Update the API configuration:**
   
   Open [lib/config/api_config.dart](lib/config/api_config.dart) and change:
   
   ```dart
   // Change from:
   static const String baseUrl = 'http://10.0.2.2:8080/api';
   
   // To your local IP:
   static const String baseUrl = 'http://192.168.1.100:8080/api';
   ```

3. **Ensure both devices are on the same WiFi network**

### Step 3: Test the Connection

1. **From your mobile device browser**, navigate to:
   ```
   http://YOUR_LOCAL_IP:8080
   ```
   
   If you see "Server is up and running.", the connection is working!

2. **Test the API endpoint**:
   ```
   http://YOUR_LOCAL_IP:8080/api/sensors/latest
   ```
   
   You should see JSON data with temperature, humidity, and water level.

## Running the App

### Basic Run
```bash
flutter run
```

### Run on Specific Device
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

### Hot Reload
After the app is running, press `r` in the terminal to hot reload changes.

## API Service Architecture

### File Structure
```
lib/
├── config/
│   └── api_config.dart          # API endpoints and configuration
├── services/
│   └── api_service.dart         # API communication layer
└── screens/
    └── home_screen.dart         # UI with API integration
```

### API Configuration (`lib/config/api_config.dart`)
- Centralized API endpoint configuration
- Easy switching between emulator and physical device
- Timeout settings (10 seconds default)

### API Service (`lib/services/api_service.dart`)
Provides three main methods:

1. **`getLatestSensorData()`**
   - Fetches current temperature, humidity, water level
   - Returns `SensorData` object or `null` on error

2. **`getLatestEquipmentStatus()`**
   - Fetches current equipment states
   - Returns `EquipmentStatus` object or `null` on error

3. **`updateEquipmentStatus(status)`**
   - Sends equipment control commands to backend
   - Returns `true` on success, `false` on failure

### Data Models

**SensorData:**
```dart
class SensorData {
  final double temperature;
  final double humidity;
  final double waterLevel;
  final DateTime timestamp;
}
```

**EquipmentStatus:**
```dart
class EquipmentStatus {
  final bool fanOn;
  final bool foggerOn;
  final bool sprinklerOn;
  final bool motorOn;
  final bool lightOn;
  final bool feederOn;
}
```

## How It Works

### Data Flow

1. **App Startup:**
   - `initState()` called
   - Initial data fetch via `_fetchAllData()`
   - Timer starts (5-second intervals)

2. **Periodic Updates:**
   - Every 5 seconds, `_fetchAllData()` is called
   - Sensor data fetched from `/api/sensors/latest`
   - Equipment status fetched from `/api/equipment/latest`
   - UI updates via `setState()`

3. **User Interaction:**
   - User toggles equipment (Fan/Fogger/Sprinkler)
   - UI updates immediately (optimistic update)
   - API call sent to `/api/equipment/update`
   - On failure, UI reverts to previous state
   - Error message shown via SnackBar

### Error Handling

The app handles several error scenarios:

1. **Network Timeout** (10 seconds)
   - Shows error message: "Failed to connect to server"
   - Keeps displaying last known values

2. **Backend Unavailable**
   - Shows connection error in UI
   - Loading indicator disappears
   - User can still interact with UI

3. **Equipment Update Failure**
   - Reverts UI to previous state
   - Shows red SnackBar with error message

## Troubleshooting

### App shows "Failed to connect to server"

**Check 1: Backend is running**
```bash
cd backend
npm start
```

**Check 2: Correct IP address**
- Verify the IP in `lib/config/api_config.dart` matches your computer's IP
- Ensure you're using the correct network interface (WiFi, not VPN)

**Check 3: Network connectivity**
- Both devices must be on same WiFi network
- Test API endpoint in mobile browser first

**Check 4: Firewall**
- Ensure port 8080 is allowed through firewall
- Windows: `New-NetFirewallRule -DisplayName "Node API" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow`

### Data not updating

**Check 1: Timer is running**
- The timer should refresh data every 5 seconds
- Check console logs for "Error fetching data" messages

**Check 2: Backend data ingestion**
- Backend generates new data every 5 minutes
- Check backend console for "[Ingestion] Data inserted" messages

### Equipment toggle not working

**Check 1: API response**
- Look for error messages in Flutter console
- Check network tab for 200/201 response codes

**Check 2: Backend database**
- Ensure PostgreSQL is running
- Check backend logs for errors

## Performance Optimization

### Current Settings
- **Refresh Interval:** 5 seconds
- **API Timeout:** 10 seconds
- **Optimistic UI Updates:** Enabled

### Adjusting Refresh Rate

To change the data refresh interval, edit `lib/screens/home_screen.dart`:

```dart
// Change from 5 seconds to desired interval
_dataRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
  _fetchAllData();
});
```

**Recommended intervals:**
- Real-time monitoring: 2-5 seconds
- Normal operation: 5-10 seconds
- Battery saving: 15-30 seconds

## Security Considerations

### Development (Current Setup)
- HTTP protocol (not encrypted)
- No authentication required
- CORS allows all origins (`*`)

### Production Recommendations

1. **Use HTTPS**
   - Deploy backend with SSL certificate
   - Update `baseUrl` to use `https://`

2. **Implement Authentication**
   - Add JWT token to API requests
   - Store token securely (flutter_secure_storage)
   - Add login screen

3. **Restrict CORS**
   - Update backend to allow only specific origins
   - See backend/MOBILE_SETUP.md for details

## Next Steps

### Planned Features
- [ ] User authentication and login screen
- [ ] Historical data charts (Reports screen)
- [ ] Push notifications for alerts
- [ ] Camera feed integration
- [ ] Offline mode with local cache
- [ ] Settings screen for API configuration

### Adding More API Endpoints

To add new functionality:

1. **Add endpoint to backend** (`backend/routes/`)
2. **Update API config** (`lib/config/api_config.dart`)
3. **Add method to API service** (`lib/services/api_service.dart`)
4. **Update UI** (`lib/screens/*.dart`)

Example:
```dart
// lib/config/api_config.dart
static const String alerts = '/alerts/latest';

// lib/services/api_service.dart
static Future<List<Alert>> getLatestAlerts() async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}${ApiConfig.alerts}'),
  );
  // ... parse and return
}
```

## Testing

### Manual Testing Checklist
- [ ] App launches without errors
- [ ] Temperature gauge shows data from backend
- [ ] Humidity gauge shows data from backend
- [ ] Water tank shows data from backend
- [ ] Motor status reflects backend state
- [ ] Fan toggle works and syncs
- [ ] Fogger toggle works and syncs
- [ ] Sprinkler toggle works and syncs
- [ ] Loading indicator appears during fetch
- [ ] Error message shows when backend is offline
- [ ] Data refreshes every 5 seconds

### Console Logs

The app prints helpful debug information:

```
✅ Successful sensor fetch (no output - silent success)
❌ Error fetching sensor data: [error details]
❌ Failed to load sensor data: [status code]

✅ Successful equipment fetch (no output)
❌ Error fetching equipment status: [error details]

✅ Equipment update successful (no output)
❌ Failed to update equipment status: [status code]
```

## Support

For issues or questions:

1. Check this guide and backend/MOBILE_SETUP.md
2. Verify all prerequisites are met
3. Test API endpoints in browser first
4. Check Flutter console for error messages
5. Check backend console for API errors

## Code Examples

### Fetching Sensor Data
```dart
final sensorData = await ApiService.getLatestSensorData();
if (sensorData != null) {
  print('Temperature: ${sensorData.temperature}°C');
  print('Humidity: ${sensorData.humidity}%');
  print('Water: ${sensorData.waterLevel}%');
}
```

### Updating Equipment
```dart
final status = EquipmentStatus(
  fanOn: true,
  foggerOn: false,
  sprinklerOn: true,
  motorOn: true,
  lightOn: false,
  feederOn: false,
);

final success = await ApiService.updateEquipmentStatus(status);
if (success) {
  print('Equipment updated successfully');
}
```

---

**Last Updated:** January 8, 2026
**Flutter Version:** 3.0+
**Backend Version:** 1.0.0
