# Backend Setup for Mobile App Integration

## Overview
This backend API serves both the web dashboard and mobile Flutter app for Poultry Automation system.

## Prerequisites
- Node.js (v16 or higher)
- PostgreSQL (v12 or higher)
- Python 3.x (for camera streaming)

## Installation

1. **Install Dependencies**
   ```bash
   cd backend
   npm install
   ```

2. **Configure Database**
   - Open `.env` file and update PostgreSQL credentials:
   ```env
   DB_USER=postgres
   DB_PASSWORD=your_password
   DB_HOST=127.0.0.1
   DB_PORT=5433
   DB_NAME=poultry-automation
   PORT=8080
   ```

3. **Start PostgreSQL**
   - Ensure PostgreSQL is running on the configured port
   - The app will automatically create tables on first run

## Running the Backend

### For Development (with auto-reload)
```bash
npm run dev
```

### For Production
```bash
npm start
```

The server will start on port 8080 (or the PORT specified in .env)

## API Endpoints

### Sensor Data
- **GET** `/api/sensors/latest` - Get latest temperature, humidity, and water level
- **POST** `/api/sensors/update` - Update sensor data (for IoT devices)
- **GET** `/api/sensors/history?range=24h` - Get historical sensor data

### Equipment Control
- **GET** `/api/equipment/latest` - Get current equipment status
- **POST** `/api/equipment/update` - Update equipment status (fan, fogger, sprinkler, etc.)

### Statistics
- **GET** `/api/stats/latest` - Get daily statistics

### Alerts
- **GET** `/api/alerts/latest` - Get recent alerts

### Authentication
- **POST** `/api/auth/login` - User login
- **POST** `/api/auth/register` - User registration

## Mobile App Configuration

### For Android Emulator
The Flutter app is configured to use `10.0.2.2:8080` which maps to `localhost:8080` on your development machine.

### For Physical Android Device
You need to update the API base URL in the Flutter app:

1. Open `lib/config/api_config.dart` in the Flutter project
2. Find your computer's local IP address:
   - **Windows**: Run `ipconfig` in Command Prompt, look for IPv4 Address
   - **Mac/Linux**: Run `ifconfig` or `ip addr`
3. Update the baseUrl:
   ```dart
   static const String baseUrl = 'http://YOUR_LOCAL_IP:8080/api';
   // Example: 'http://192.168.1.100:8080/api'
   ```

### CORS Configuration
The backend is already configured to accept requests from any origin (`origin: '*'`), which allows both web and mobile apps to connect. This is set in `index.js`:

```javascript
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  exposedHeaders: ['Content-Type']
}));
```

## Network Requirements

### Firewall Settings
Make sure port 8080 is accessible on your network:

**Windows Firewall:**
```powershell
New-NetFirewallRule -DisplayName "Node API" -Direction Inbound -LocalPort 8080 -Protocol TCP -Action Allow
```

### Testing Connectivity

From your mobile device's browser, navigate to:
```
http://YOUR_LOCAL_IP:8080
```

You should see: "Server is up and running."

## Data Ingestion

The backend automatically generates random sensor data every 5 minutes for testing purposes. This is configured in `index.js`:

- Device ID 1: Temperature (20-35°C)
- Device ID 2: Humidity (40-80%)
- Device ID 3: Water Level (10-100%)

To disable auto-ingestion, comment out the `startIngestion()` call in `index.js`.

## Default User Accounts

Two default accounts are created on first run:

**Admin Account:**
- Email: admin@gmail.com
- Password: admin123
- Role: admin

**User Account:**
- Email: user@gmail.com
- Password: user123
- Role: user

## Camera Streaming

The backend includes Python-based IP camera streaming. Configure in `.env`:

```env
CAMERA_IP=192.168.0.100
CAMERA_PORT=554
CAMERA_USERNAME=your_username
CAMERA_PASSWORD=your_password
CAMERA_STREAM_PATH=/stream1
```

## Troubleshooting

### Mobile app can't connect
1. Verify backend is running: `npm start`
2. Check your local IP address is correct in Flutter app
3. Ensure both devices are on the same network
4. Check firewall settings
5. Test the API endpoint in browser from mobile device

### Database connection errors
1. Verify PostgreSQL is running
2. Check credentials in `.env` file
3. Ensure database `poultry-automation` exists

### CORS errors
- The backend is configured with permissive CORS (`origin: '*'`)
- If you still see CORS errors, ensure the Flutter app is using http (not https) for local development

## Production Deployment

For production deployment:

1. **Update CORS settings** in `index.js` to specific origins:
   ```javascript
   app.use(cors({
     origin: ['https://yourwebsite.com', 'https://yourmobileapp.com'],
     // ... other settings
   }));
   ```

2. **Use environment variables** for sensitive data
3. **Enable HTTPS** with SSL certificates
4. **Set secure JWT_SECRET** in `.env`
5. **Configure proper database backups**
6. **Use process manager** like PM2:
   ```bash
   npm install -g pm2
   pm2 start index.js --name poultry-api
   pm2 save
   pm2 startup
   ```

## API Response Examples

### GET /api/sensors/latest
```json
{
  "temperature": 24.53,
  "humidity": 41.67,
  "waterLevel": 18.37,
  "timestamp": "2026-01-08T10:30:00.000Z"
}
```

### GET /api/equipment/latest
```json
{
  "id": 1,
  "fanOn": true,
  "foggerOn": false,
  "sprinklerOn": true,
  "motorOn": true,
  "lightOn": false,
  "feederOn": false,
  "updatedAt": "2026-01-08T10:30:00.000Z"
}
```

### POST /api/equipment/update
**Request:**
```json
{
  "fanOn": true,
  "foggerOn": true,
  "sprinklerOn": false,
  "motorOn": true,
  "lightOn": false,
  "feederOn": false
}
```

**Response:**
```json
{
  "id": 2,
  "fanOn": true,
  "foggerOn": true,
  "sprinklerOn": false,
  "motorOn": true,
  "lightOn": false,
  "feederOn": false,
  "updatedAt": "2026-01-08T10:31:00.000Z"
}
```

## Support

For issues or questions, check the logs:
- Server logs show in the terminal where you ran `npm start`
- Flutter app logs show in the console where you ran `flutter run`
