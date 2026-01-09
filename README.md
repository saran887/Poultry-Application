# Poultry Automation System

A comprehensive IoT-based smart poultry farm management system with real-time monitoring, automated equipment control, and instant mobile notifications.

## 🚀 Features

### Mobile Application (Flutter)
- **Real-time Monitoring Dashboard**
  - Live temperature, humidity, and water level tracking
  - Visual charts and gauges for sensor data
  - Equipment status indicators with color-coded states

- **Instant Push Notifications**
  - Real-time alerts for equipment state changes
  - Optimized for zero-delay notification delivery
  - Hourly status reports with complete farm overview
  - Background service for 24/7 monitoring

- **Equipment Control**
  - Manual control for all farm equipment
  - Fan, Fogger, Sprinkler control
  - Water Motor, Lighting, Feeder automation
  - Real-time feedback on equipment state changes

- **Statistics & Analytics**
  - Historical data visualization with FL Chart
  - Daily, weekly, and monthly trends
  - Temperature and humidity pattern analysis

### Backend (Node.js)
- **WebSocket Communication**
  - Real-time bidirectional data streaming
  - Socket.io for instant equipment updates
  - Minimal latency for critical alerts

- **RESTful API**
  - Sensor data endpoints
  - Equipment control APIs
  - User authentication with JWT
  - Historical statistics retrieval

- **Database (MySQL)**
  - Sensor data logging
  - Equipment status tracking
  - Alert history management
  - Daily statistics aggregation

- **IP Camera Integration**
  - Live video streaming capability
  - Camera status monitoring

## 📱 Tech Stack

### Frontend
- **Framework:** Flutter 3.x
- **Language:** Dart
- **State Management:** Provider pattern
- **Real-time Communication:** Socket.io Client
- **Charts:** FL Chart
- **Notifications:** Flutter Local Notifications
- **Background Service:** Flutter Background Service

### Backend
- **Runtime:** Node.js
- **Framework:** Express.js
- **Database:** MySQL with Sequelize ORM
- **Real-time:** Socket.io
- **Authentication:** JWT (JSON Web Tokens)
- **API Testing:** Custom test utilities

## 🛠️ Installation & Setup

### Prerequisites
- Node.js (v14 or higher)
- Flutter SDK (v3.x)
- MySQL Server
- Android Studio / VS Code
- Android device or emulator

### Backend Setup

```bash
# Navigate to backend directory
cd backend

# Install dependencies
npm install

# Configure database
# Update config/database.js with your MySQL credentials

# Start the server
node index.js
```

The backend server will start on `http://localhost:3000`

### Frontend Setup

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
flutter pub get

# Update API configuration
# Edit lib/config/api_config.dart with your backend IP address

# Run the application
flutter run
```

## 📡 API Endpoints

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/register` - User registration

### Sensors
- `GET /api/sensors/latest` - Get latest sensor readings
- `GET /api/sensors/history` - Get historical sensor data

### Equipment
- `GET /api/equipment/status` - Get current equipment status
- `POST /api/equipment/control` - Control equipment (fan, fogger, etc.)

### Statistics
- `GET /api/stats/daily` - Get daily statistics
- `GET /api/stats/overview` - Get farm overview

### Alerts
- `GET /api/alerts` - Get alert history
- `POST /api/alerts` - Create new alert

## 🔔 Notification System

The application features an advanced notification system with:

- **Instant Notifications:** Zero-delay alerts when equipment state changes
- **Background Service:** Continuous monitoring even when app is closed
- **Persistent Notification:** Live status bar showing current farm conditions
- **Hourly Reports:** Automatic status updates every hour
- **Smart Throttling:** Optimized to prevent notification spam while ensuring critical alerts

## 🎨 UI/UX Features

- Modern glassmorphism design with gradient backgrounds
- Smooth animations and transitions
- Responsive layout for various screen sizes
- Dark mode support
- Intuitive navigation with bottom navigation bar
- Custom-designed gauges and charts
- Color-coded status indicators

## 📊 Monitoring Capabilities

### Sensor Monitoring
- **Temperature:** Real-time tracking with min/max thresholds
- **Humidity:** Percentage-based monitoring with visual indicators
- **Water Level:** Tank level monitoring with low-level alerts

### Equipment Status
- Fan (ON/OFF with automation status)
- Fogger (Manual/Auto control)
- Sprinkler (Scheduled operation)
- Water Motor (Auto tank refill)
- Lighting (Time-based control)
- Feeder (Automated feeding cycles)

## 🔒 Security

- JWT-based authentication
- Secure API endpoints
- Environment-based configuration
- Input validation and sanitization

## 📱 Supported Platforms

- Android (Primary)
- iOS (Compatible)
- Windows (Development/Testing)

## 🧪 Testing

```bash
# Backend API testing
cd backend
node test_api.js

# Frontend widget testing
cd frontend
flutter test
```

## 📝 Project Structure

```
poultry-APP/
├── backend/
│   ├── config/          # Database configuration
│   ├── controllers/     # API controllers
│   ├── models/          # Database models
│   ├── routes/          # API routes
│   └── index.js         # Main server file
├── frontend/
│   ├── lib/
│   │   ├── config/      # App configuration
│   │   ├── screens/     # UI screens
│   │   ├── services/    # API & Socket services
│   │   ├── widgets/     # Reusable widgets
│   │   └── main.dart    # App entry point
│   └── android/         # Android native code
└── README.md
```

## 🚀 Deployment

### Backend Deployment
- Deploy to cloud platforms (AWS, Azure, DigitalOcean)
- Configure environment variables
- Set up MySQL database
- Enable WebSocket connections

### Mobile App Deployment
- Build release APK: `flutter build apk --release`
- Build app bundle: `flutter build appbundle`
- Upload to Google Play Store

## 🤝 Contributing

Contributions are welcome! Please follow these steps:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 👥 Authors

- **Development Team:** CubeAI Solutions
- **Mobile App:** Flutter Development Team
- **Backend:** Node.js Development Team

## 📞 Support

For support and queries:
- GitHub Issues: Report bugs and request features
- Email: support@cubeaisolutions.com

## 🎯 Future Enhancements

- [ ] AI-based predictive analytics
- [ ] Multi-farm management
- [ ] Voice control integration
- [ ] Advanced reporting and insights
- [ ] Cloud backup and sync
- [ ] Weather integration
- [ ] Automated emergency protocols

## 📊 Version History

### v1.0.0 (Current)
- Initial release
- Real-time monitoring
- Equipment control
- Push notifications
- Statistics dashboard
- Background service implementation

---

**Made with ❤️ for Smart Farming**
