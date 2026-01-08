import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SensorData {
  final double temperature;
  final double humidity;
  final double waterLevel;
  final DateTime timestamp;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.waterLevel,
    required this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      waterLevel: (json['waterLevel'] ?? 0).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class EquipmentStatus {
  final bool fanOn;
  final bool foggerOn;
  final bool sprinklerOn;
  final bool motorOn;
  final bool lightOn;
  final bool feederOn;
  final bool autoMode;

  EquipmentStatus({
    required this.fanOn,
    required this.foggerOn,
    required this.sprinklerOn,
    required this.motorOn,
    required this.lightOn,
    required this.feederOn,
    required this.autoMode,
  });

  factory EquipmentStatus.fromJson(Map<String, dynamic> json) {
    return EquipmentStatus(
      fanOn: json['fanOn'] ?? false,
      foggerOn: json['foggerOn'] ?? false,
      sprinklerOn: json['sprinklerOn'] ?? false,
      motorOn: json['motorOn'] ?? false,
      lightOn: json['lightOn'] ?? false,
      feederOn: json['feederOn'] ?? false,
      autoMode: json['autoMode'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fanOn': fanOn,
      'foggerOn': foggerOn,
      'sprinklerOn': sprinklerOn,
      'motorOn': motorOn,
      'lightOn': lightOn,
      'feederOn': feederOn,
      'autoMode': autoMode,
    };
  }
}

class User {
  final String email;
  final String role;

  User({required this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
    );
  }
}

class EquipmentUptime {
  final int fan;
  final int fogger;
  final int sprinkler;
  final int motor;

  EquipmentUptime({
    required this.fan,
    required this.fogger,
    required this.sprinkler,
    required this.motor,
  });

  factory EquipmentUptime.fromJson(Map<String, dynamic> json) {
    return EquipmentUptime(
      fan: (json['fan'] ?? 0).toInt(),
      fogger: (json['fogger'] ?? 0).toInt(),
      sprinkler: (json['sprinkler'] ?? 0).toInt(),
      motor: (json['motor'] ?? 0).toInt(),
    );
  }
}

class DashboardStats {
  final String date;
  final double avgTemperature;
  final double avgHumidity;
  final double waterUsage;
  final double feedUsage;
  final EquipmentUptime equipmentUptime;

  DashboardStats({
    required this.date,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.waterUsage,
    required this.feedUsage,
    required this.equipmentUptime,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      date: json['date'] ?? '',
      avgTemperature: (json['avgTemperature'] ?? 0).toDouble(),
      avgHumidity: (json['avgHumidity'] ?? 0).toDouble(),
      waterUsage: (json['waterUsage'] ?? 0).toDouble(),
      feedUsage: (json['feedUsage'] ?? 0).toDouble(),
      equipmentUptime: EquipmentUptime.fromJson(json['equipmentUptime'] ?? {}),
    );
  }
}

class Alert {
  final int id;
  final String message;
  final String severity;
  final DateTime timestamp;
  final bool resolved;

  Alert({
    required this.id,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.resolved,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] ?? 0,
      message: json['message'] ?? '',
      severity: json['severity'] ?? 'info',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      resolved: json['resolved'] ?? false,
    );
  }
}

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  ));

  static String? _token;
  static User? _currentUser;

  static User? get currentUser => _currentUser;

  static Future<void> _saveSession(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_email', user.email);
    await prefs.setString('user_role', user.role);
  }

  static Future<bool> checkSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      final email = prefs.getString('user_email');
      final role = prefs.getString('user_role');

      if (_token != null && email != null) {
        _currentUser = User(email: email, role: role ?? 'user');
        _dio.options.headers['Authorization'] = 'Bearer $_token';
        return true;
      }
    } catch (e) {
      print('❌ Session check error: $e');
    }
    return false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    _token = null;
    _currentUser = null;
    _dio.options.headers.remove('Authorization');
  }

  static Future<bool> login(String email, String password) async {
    try {
      final response = await _dio.post(ApiConfig.login, data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        _token = response.data['token'];
        if (response.data['user'] != null) {
          _currentUser = User.fromJson(response.data['user']);
          await _saveSession(_token!, _currentUser!);
        }
        _dio.options.headers['Authorization'] = 'Bearer $_token';
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Login error: $e');
      return false;
    }
  }

  static Future<List<User>> getAllUsers() async {
    try {
      final response = await _dio.get(ApiConfig.users);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Get Users error: $e');
      return [];
    }
  }

  static Future<bool> updateUser(String email, {required String role}) async {
    try {
      final response = await _dio.put('${ApiConfig.users}/$email', data: {
        'role': role,
      });
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Update User error: $e');
      return false;
    }
  }

  static Future<bool> deleteUser(String email) async {
    try {
      final response = await _dio.delete('${ApiConfig.users}/$email');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Delete User error: $e');
      return false;
    }
  }

  static Future<List<Alert>> getAlerts() async {
    try {
      final response = await _dio.get(ApiConfig.alerts);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => Alert.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Get Alerts error: $e');
      return [];
    }
  }

  static Future<List<DashboardStats>> getStats() async {
    try {
      final response = await _dio.get(ApiConfig.stats);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => DashboardStats.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('❌ Get Stats error: $e');
      return [];
    }
  }

  static Future<SensorData?> getLatestSensorData() async {
    try {
      final url = ApiConfig.sensors;
      print('🌐 Fetching sensor data from: ${ApiConfig.baseUrl}$url');
      
      final response = await _dio.get(url);

      print('✅ Response received: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = response.data;
        print('📊 Data: $data');
        return SensorData.fromJson(data);
      } else {
        print('❌ Failed to load sensor data: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('❌ DioError: ${e.type} - ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout) {
        print('   Connection timeout - server not reachable');
      } else if (e.type == DioExceptionType.receiveTimeout) {
        print('   Receive timeout - server too slow');
      } else if (e.type == DioExceptionType.connectionError) {
        print('   Connection error - ${e.error}');
      }
      return null;
    } catch (e) {
      print('❌ Error fetching sensor data: $e');
      return null;
    }
  }

  static Future<EquipmentStatus?> getLatestEquipmentStatus() async {
    try {
      final response = await _dio.get(ApiConfig.equipment);

      if (response.statusCode == 200) {
        return EquipmentStatus.fromJson(response.data);
      } else {
        print('Failed to load equipment status: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      print('Error fetching equipment status: ${e.type} - ${e.message}');
      return null;
    } catch (e) {
      print('Error fetching equipment status: $e');
      return null;
    }
  }

  static Future<bool> updateEquipmentStatus(EquipmentStatus status) async {
    try {
      final data = status.toJson();
      print('📤 POST update to: ${ApiConfig.baseUrl}${ApiConfig.equipmentUpdate}');
      print('📤 Request body: $data');
      
      final response = await _dio.post(
        ApiConfig.equipmentUpdate,
        data: data,
      );

      print('✅ Update response: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('❌ Failed to update equipment status: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      print('❌ DioError during update: ${e.type} - ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error updating equipment status: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getSensorHistory({String range = '24h'}) async {
    try {
      final response = await _dio.get(
        '${ApiConfig.sensorHistory}?range=$range',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        print('Failed to load sensor history: ${response.statusCode}');
        return [];
      }
    } on DioException catch (e) {
      print('Error fetching sensor history: ${e.type} - ${e.message}');
      return [];
    } catch (e) {
      print('Error fetching sensor history: $e');
      return [];
    }
  }
}
  