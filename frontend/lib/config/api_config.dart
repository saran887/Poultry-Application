class ApiConfig {
  // Update this IP address to match your backend server
  // For Android Emulator: use 10.0.2.2
  // For physical device on same network: use your computer's local IP
  // Example: 192.168.1.100, 192.168.0.105, etc.
  
  // Current configuration: Using your local network IP
  static const String baseUrl = 'http://192.168.0.104:3000/api';
  
  // Alternative: For Android Emulator use this instead
  // static const String baseUrl = 'http://10.0.2.2:3000/api';
  
  // Endpoints
  static const String sensors = '/sensors/latest';
  static const String sensorHistory = '/sensors/history';
  static const String equipment = '/equipment/latest';
  static const String equipmentUpdate = '/equipment/update';
  static const String stats = '/stats';
  static const String alerts = '/alerts/latest';
  static const String login = '/auth/login';
  static const String users = '/auth/users';
  static const String cameraStream = '/camera/video_feed';
  
  // Timeout configuration
  static const Duration timeout = Duration(seconds: 10);
}
