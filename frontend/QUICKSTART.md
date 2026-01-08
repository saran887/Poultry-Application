# Quick Start Guide

## Running the App

1. **Install Flutter dependencies**
   ```powershell
   flutter pub get
   ```

2. **Check Flutter setup**
   ```powershell
   flutter doctor
   ```

3. **Run on connected device/emulator**
   ```powershell
   flutter run
   ```

4. **Run on specific device**
   ```powershell
   # List devices
   flutter devices
   
   # Run on specific device
   flutter run -d <device-id>
   ```

## Build Commands

### Android
```powershell
# Debug APK
flutter build apk

# Release APK
flutter build apk --release

# App Bundle (for Play Store)
flutter build appbundle
```

### iOS
```powershell
# Debug build
flutter build ios

# Release build
flutter build ios --release
```

## Troubleshooting

### If you get dependency errors:
```powershell
flutter clean
flutter pub get
```

### If you get Gradle errors (Android):
```powershell
cd android
./gradlew clean
cd ..
flutter run
```

### To run with verbose logging:
```powershell
flutter run -v
```

## Hot Reload
While the app is running:
- Press `r` to hot reload
- Press `R` to hot restart
- Press `q` to quit

## Development Tips

1. **Enable DevTools**
   ```powershell
   flutter pub global activate devtools
   flutter pub global run devtools
   ```

2. **Check for updates**
   ```powershell
   flutter upgrade
   ```

3. **Format code**
   ```powershell
   flutter format .
   ```

4. **Analyze code**
   ```powershell
   flutter analyze
   ```

## Project Status
✅ Home Screen - Complete  
✅ Reports Screen - Complete  
✅ Users Screen - Complete  
✅ Custom Painters - Complete  
✅ Reusable Widgets - Complete  
✅ Navigation - Complete  
✅ Theme System - Complete  

## Next Steps
- Test on physical device
- Add backend integration
- Implement real-time data updates
- Add authentication
