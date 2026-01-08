import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';
import 'api_service.dart';

class SocketService {
  late IO.Socket socket;
  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  final List<Function(SensorData)> _sensorListeners = [];
  final List<Function(EquipmentStatus)> _equipmentListeners = [];
  bool _isInitialized = false;

  void addSensorListener(Function(SensorData) listener) {
    _sensorListeners.add(listener);
  }

  void addEquipmentListener(Function(EquipmentStatus) listener) {
    _equipmentListeners.add(listener);
  }

  void removeSensorListener(Function(SensorData) listener) {
    _sensorListeners.remove(listener);
  }

  void removeEquipmentListener(Function(EquipmentStatus) listener) {
    _equipmentListeners.remove(listener);
  }

  void initSocket({
    Function(SensorData)? onSensorUpdate,
    Function(EquipmentStatus)? onEquipmentUpdate,
  }) {
    if (onSensorUpdate != null && !_sensorListeners.contains(onSensorUpdate)) {
      _sensorListeners.add(onSensorUpdate);
    }
    if (onEquipmentUpdate != null && !_equipmentListeners.contains(onEquipmentUpdate)) {
      _equipmentListeners.add(onEquipmentUpdate);
    }

    if (_isInitialized) return;
    _isInitialized = true;

    // Determine socket URL from baseUrl (strip /api)
    String socketUrl = ApiConfig.baseUrl.replaceFirst('/api', '');
    
    print('🔌 Connecting to WebSocket at: $socketUrl');

    socket = IO.io(socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());

    socket.connect();

    socket.onConnect((_) {
      print('✅ Connected to WebSocket');
    });

    socket.on('sensorUpdate', (data) {
      print('📊 Received sensorUpdate: $data');
      final sensorData = SensorData.fromJson(data);
      for (var listener in _sensorListeners) {
        listener(sensorData);
      }
    });

    socket.on('equipmentUpdate', (data) {
      print('⚙️ Received equipmentUpdate: $data');
      final equipmentStatus = EquipmentStatus.fromJson(data);
      for (var listener in _equipmentListeners) {
        listener(equipmentStatus);
      }
    });

    socket.onDisconnect((_) => print('❌ Disconnected from WebSocket'));
    socket.onConnectError((err) => print('⚠️ Connection error: $err'));
  }

  void dispose() {
    socket.dispose();
  }
}
