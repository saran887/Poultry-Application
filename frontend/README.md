# Poultry Automation - Mobile Dashboard

A Flutter mobile application that replicates the Poultry Automation web dashboard UI with exact visual fidelity.

## Features

### Home Screen (Farm Overview)
- **Temperature & Humidity Gauges**: Circular arc gauges with real-time values
- **Water Tank Indicator**: Vertical tank visualization with percentage, volume, and refill estimates
- **Equipment Controls**: Toggle switches for Fan, Fogger, and Sprinkler
- **Light Status**: Current lighting status with timestamp
- **Feeder Control**: Manual UP/DOWN controls for poultry feeder
- **Camera Feed**: Quick access to live farm monitoring

### Reports Screen
- **Metrics Dashboard**: Average temperature, humidity, water usage, and equipment uptime
- **Interactive Charts**: Line charts for temperature/humidity trends, pie chart for system status
- **Alert Summary**: Real-time alerts for low water, humidity issues, etc.
- **Activity Timeline**: Historical log of system events

### Users Screen
- **User Statistics**: Total users, administrators, and regular users count
- **User Management**: List of all users with roles and actions
- **Add User Dialog**: Form to create new users with roles

## Design System

### Colors
- Background: `#0b0f0d` (near black)
- Card background: `#161a18`
- Primary green: `#22c55e`
- Muted text: `#9ca3af`
- Divider: `#1f2933`
- Critical red: `#dc2626`
- Warning yellow: `#f59e0b`

### Typography
- Font weights: Medium (500) / Semibold (600)
- Border radius: 14–16px
- Material 3 design system

## Project Structure

```
lib/
├── main.dart                    # App entry point and navigation
├── screens/
│   ├── home_screen.dart        # Farm overview with all sensors
│   ├── reports_screen.dart     # Analytics and reports
│   └── users_screen.dart       # User management
└── widgets/
    ├── custom_painters.dart    # Gauge and tank painters
    └── common_widgets.dart     # Reusable components
```

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0.0 or higher
- Dart SDK
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone or navigate to the project directory**
   ```bash
   cd d:\CubeAI\poultry-APP
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Dependencies
- `flutter`: SDK
- `fl_chart: ^0.65.0` - For charts and graphs
- `intl: ^0.18.1` - For date/time formatting

## Key Components

### Custom Painters
- **CircularGaugePainter**: Renders circular arc gauges for temperature/humidity
- **WaterTankPainter**: Draws vertical water tank with level indicator

### Reusable Widgets
- **DashboardCard**: Base card component with consistent styling
- **MetricCard**: Displays metrics with icon, value, and unit
- **ControlCard**: Toggle switch card for equipment control
- **StatusChip**: Colored badge for status indicators

## Data
Currently uses static/dummy data. No backend integration yet.

## Development Notes

- UI prioritizes visual accuracy over simplicity
- All colors, spacing, and typography match web dashboard exactly
- Layout adapted for vertical mobile scrolling
- Material 3 design system used throughout
- No state management library - uses simple setState for now

## Future Enhancements
- Backend API integration
- Real-time data updates
- Push notifications for alerts
- Camera feed integration
- Historical data storage
- User authentication
- Multi-language support

## Screenshots
Run the app to see the complete UI matching the web dashboard design.

---

**Version**: 1.0.0  
**Platform**: iOS & Android  
**Framework**: Flutter 3.0+
