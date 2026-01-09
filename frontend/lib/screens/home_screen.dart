import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:intl/intl.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:async';
import '../widgets/common_widgets.dart';
import '../widgets/custom_painters.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../config/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Use ValueNotifiers for performance-critical data
  // This prevents the entire giant widget tree from rebuilding on every update
  final ValueNotifier<double> tempNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> humNotifier = ValueNotifier(0.0);
  final ValueNotifier<double> waterNotifier = ValueNotifier(0.0);
  
  // Equipment state notifiers for instant UI response
  final ValueNotifier<bool> fanNotifier = ValueNotifier(false);
  final ValueNotifier<bool> foggerNotifier = ValueNotifier(false);
  final ValueNotifier<bool> sprinklerNotifier = ValueNotifier(false);
  final ValueNotifier<bool> motorNotifier = ValueNotifier(false);
  final ValueNotifier<bool> lightNotifier = ValueNotifier(false);
  final ValueNotifier<bool> feederNotifier = ValueNotifier(false);
  final ValueNotifier<bool> autoModeNotifier = ValueNotifier(true);

  // Equipment states (kept for logic, but UI will use Notifiers)
  bool get fanOn => fanNotifier.value;
  set fanOn(bool val) => fanNotifier.value = val;
  
  bool get foggerOn => foggerNotifier.value;
  set foggerOn(bool val) => foggerNotifier.value = val;
  
  bool get sprinklerOn => sprinklerNotifier.value;
  set sprinklerOn(bool val) => sprinklerNotifier.value = val;
  
  bool get motorOn => motorNotifier.value;
  set motorOn(bool val) => motorNotifier.value = val;
  
  bool get lightOn => lightNotifier.value;
  set lightOn(bool val) => lightNotifier.value = val;
  
  bool get feederOn => feederNotifier.value;
  set feederOn(bool val) => feederNotifier.value = val;
  
  bool get autoMode => autoModeNotifier.value;
  set autoMode(bool val) => autoModeNotifier.value = val;

  bool _isRefilling = false;
  
  // Sensor data
  double temperature = 0.0;
  double humidity = 0.0;
  double waterLevel = 0.0;
  DateTime? lastSensorUpdate; // Tracking when we last got real data
  
  // UI state
  bool isLoading = true;
  bool isUpdating = false;
  String? errorMessage;
  
  late AnimationController _waveController;
  final SocketService _socketService = SocketService();
  EquipmentStatus? _lastNotificationStatus;

  bool get isAdmin => ApiService.currentUser?.role == 'admin';

  @override
  void initState() {
    super.initState();
    // Keep screen on while app is open
    WakelockPlus.enable();
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // 1. Set up Real-time updates via Socket.io first
    _socketService.initSocket(
      onSensorUpdate: (data) {
        // High-speed update: Only update the values we need
        tempNotifier.value = data.temperature;
        humNotifier.value = data.humidity;
        waterNotifier.value = data.waterLevel;
        
        if (mounted) {
          setState(() {
            temperature = data.temperature;
            humidity = data.humidity;
            waterLevel = data.waterLevel;
            lastSensorUpdate = DateTime.now();
            isLoading = false;
            errorMessage = null; 
          });
          
          // Automation logic has been moved to Backend for maximum speed and 24/7 reliability.
          // The mobile app now strictly reflects the live system state.
        }
      },
      onEquipmentUpdate: (status) {
        if (mounted) {
          // Update ValueNotifiers immediately without full setState
          fanNotifier.value = status.fanOn;
          foggerNotifier.value = status.foggerOn;
          sprinklerNotifier.value = status.sprinklerOn;
          motorNotifier.value = status.motorOn;
          lightNotifier.value = status.lightOn;
          feederNotifier.value = status.feederOn;
          autoModeNotifier.value = status.autoMode;
          _isRefilling = status.motorOn;

          // Check for changes and notify
          if (_lastNotificationStatus != null) {
            final now = DateTime.now().millisecondsSinceEpoch;
            final String sensorSummary = 'Temp: ${temperature.toStringAsFixed(1)}°C | Hum: ${humidity.toStringAsFixed(0)}% | Water: ${waterLevel.toStringAsFixed(0)}%';
            
            print('🔔 Checking for notifications... (Fan: ${status.fanOn}, Last: ${_lastNotificationStatus!.fanOn})');

            if (status.fanOn && !_lastNotificationStatus!.fanOn) {
              print('📢 Triggering Fan Notification');
              NotificationService().showNotification(
                id: now % 10000,
                title: 'Automation: Fan Activated',
                body: 'Cooling system started.\n$sensorSummary',
              );
            }
            if (status.foggerOn && !_lastNotificationStatus!.foggerOn) {
              print('📢 Triggering Fogger Notification');
              NotificationService().showNotification(
                id: (now + 1) % 10000,
                title: 'Automation: Fogger Activated',
                body: 'Fogging system started.\n$sensorSummary',
              );
            }
            if (status.sprinklerOn && !_lastNotificationStatus!.sprinklerOn) {
              print('📢 Triggering Sprinkler Notification');
              NotificationService().showNotification(
                id: (now + 2) % 10000,
                title: 'Automation: Sprinkler Activated',
                body: 'Sprinkler system started.\n$sensorSummary',
              );
            }
            if (status.motorOn && !_lastNotificationStatus!.motorOn) {
              print('📢 Triggering Motor Notification');
              NotificationService().showNotification(
                id: (now + 3) % 10000,
                title: 'Water System: Motor Activated',
                body: 'Tank replenishment started.\n$sensorSummary',
              );
            }
            if (status.lightOn != _lastNotificationStatus!.lightOn) {
              print('📢 Triggering Light Notification');
              NotificationService().showNotification(
                id: (now + 4) % 10000,
                title: status.lightOn ? 'Lighting: ON' : 'Lighting: OFF',
                body: status.lightOn ? 'Farm lights activated.\n$sensorSummary' : 'Farm lights deactivated.\n$sensorSummary',
              );
            }
            if (status.feederOn != _lastNotificationStatus!.feederOn) {
              print('📢 Triggering Feeder Notification');
              NotificationService().showNotification(
                id: (now + 5) % 10000,
                title: status.feederOn ? 'Feeder: ON' : 'Feeder: OFF',
                body: status.feederOn ? 'Feeding system started.\n$sensorSummary' : 'Feeding system stopped.\n$sensorSummary',
              );
            }
          }
          
          _lastNotificationStatus = status;

          setState(() {
            isLoading = false;
            errorMessage = null;
          });
        }
      },
    );

    // 2. Initial data fetch as fallback/secondary
    _fetchAllData();

    // 3. Set up a 5-second background refresh timer (resiliency)
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        // If there's an error, or if we're just doing a periodic check
        _fetchAllData();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable(); // Allow screen to turn off when leaving
    _waveController.dispose();
    _socketService.dispose();
    tempNotifier.dispose();
    humNotifier.dispose();
    waterNotifier.dispose();
    fanNotifier.dispose();
    foggerNotifier.dispose();
    sprinklerNotifier.dispose();
    motorNotifier.dispose();
    lightNotifier.dispose();
    feederNotifier.dispose();
    autoModeNotifier.dispose();
    super.dispose();
  }
  
  Future<void> _fetchAllData() async {
    try {
      print('🚀 Starting resilient data fetch...');
      
      // Fetch sensor data independently
      ApiService.getLatestSensorData().then((sensorData) {
        if (sensorData != null && mounted) {
          tempNotifier.value = sensorData.temperature;
          humNotifier.value = sensorData.humidity;
          waterNotifier.value = sensorData.waterLevel;
          
          setState(() {
            temperature = sensorData.temperature;
            humidity = sensorData.humidity;
            waterLevel = sensorData.waterLevel;
            lastSensorUpdate = DateTime.now();
            isLoading = false;
            errorMessage = null;
          });
        }
      }).catchError((e) => print('Sensor fetch failed: $e'));

      // Fetch equipment status independently
      ApiService.getLatestEquipmentStatus().then((status) {
        if (status != null && mounted) {
          // Initialize baseline for notifications to avoid spamming on start
          _lastNotificationStatus ??= status;
          
          setState(() {
            fanOn = status.fanOn;
            foggerOn = status.foggerOn;
            sprinklerOn = status.sprinklerOn;
            motorOn = status.motorOn;
            _isRefilling = status.motorOn;
            lightOn = status.lightOn;
            feederOn = status.feederOn;
            autoMode = status.autoMode;
            isLoading = false;
            errorMessage = null;
          });
        }
      }).catchError((e) => print('Equipment fetch failed: $e'));

    } catch (e) {
      print('Critical error in _fetchAllData: $e');
      if (mounted && isLoading) {
        setState(() {
          errorMessage = 'Connection issues. Reconnect automatic...';
          isLoading = false; 
        });
      }
    }
  }
  
  Future<void> _toggleEquipment(String equipment, bool newState) async {
    if (ApiService.currentUser?.role != 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Access Denied: Only administrators can control equipment.'),
          backgroundColor: Color(0xFFD84040),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (isUpdating) return;

    // Show confirmation dialog before any state change
    final confirmed = await _showConfirmationDialog(equipment, newState);
    if (confirmed != true) return;
    
    // Update local state immediately for better UX
    isUpdating = true;
    switch (equipment) {
      case 'fan':
        fanNotifier.value = newState;
        break;
      case 'fogger':
        foggerNotifier.value = newState;
        break;
      case 'sprinkler':
        sprinklerNotifier.value = newState;
        break;
      case 'motor':
        motorNotifier.value = newState;
        break;
      case 'light':
        lightNotifier.value = newState;
        break;
      case 'feeder':
        feederNotifier.value = newState;
        break;
      case 'auto':
        autoModeNotifier.value = newState;
        break;
    }
    
    try {
      // Send sudden update via WebSocket (Faster than HTTP)
      final Map<String, dynamic> updateData = {
        'fanOn': fanNotifier.value,
        'foggerOn': foggerNotifier.value,
        'sprinklerOn': sprinklerNotifier.value,
        'motorOn': motorNotifier.value,
        'lightOn': lightNotifier.value,
        'feederOn': feederNotifier.value,
        'autoMode': autoModeNotifier.value,
      };
      
      print('⚡ Sudden Sync: Emitting $equipment toggle');
      SocketService().emitToggle(updateData);
    } catch (e) {
      print('❌ Sync failed: $e');
      // Revert on failure
      if (mounted) {
        switch (equipment) {
          case 'fan':
            fanOn = !newState;
            fanNotifier.value = fanOn;
            break;
          case 'fogger':
            foggerOn = !newState;
            foggerNotifier.value = foggerOn;
            break;
          case 'sprinkler':
            sprinklerOn = !newState;
            sprinklerNotifier.value = sprinklerOn;
            break;
          case 'motor':
            motorOn = !newState;
            motorNotifier.value = motorOn;
            break;
          case 'light':
            lightOn = !newState;
            lightNotifier.value = lightOn;
            break;
          case 'feeder':
            feederOn = !newState;
            feederNotifier.value = feederOn;
            break;
          case 'auto':
            autoMode = !newState;
            autoModeNotifier.value = autoMode;
            break;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $equipment. Please check your connection.'),
            backgroundColor: const Color(0xFFD84040),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isUpdating = false;
        });
      }
    }
  }

  Future<bool?> _showConfirmationDialog(String equipment, bool newState) {
    String action = newState ? "Turn ON" : "Turn OFF";
    if (equipment == "feeder") {
      action = newState ? "Move UP" : "Move DOWN";
    }
    
    String message = 'Are you sure you want to $action the ${equipment.toUpperCase()}?';
    if (equipment == "auto") {
      message = newState 
          ? 'Switch to Automatic System? The system will control devices based on sensors.' 
          : 'Switch to Manual Control? You will be able to manually override all equipment.';
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF262626),
        title: const Text(
          'Confirm Action',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFFD4D4D4)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF737373))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4AB08B),
              foregroundColor: Colors.white,
            ),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }

  void _showCameraDialog(String streamUrl) {
    showDialog(
      context: context,
      builder: (context) => const CameraWebSocketDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEE, MMM d, yyyy').format(DateTime.now()),
                      style: const TextStyle(
                        color: Color(0xFF737373),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Farm Overview',
                      style: TextStyle(
                        color: Color(0xFFF2F2F2),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Row(
                      children: [
                        if (lastSensorUpdate != null)
                          Text(
                            'Last data: ${DateFormat('HH:mm:ss').format(lastSensorUpdate!)}',
                            style: const TextStyle(color: Color(0xFF4AB08B), fontSize: 10),
                          ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            NotificationService().showNotification(
                              id: 0,
                              title: 'Test Notification',
                              body: 'If you see this, notifications are working!',
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4AB08B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF4AB08B).withOpacity(0.3)),
                            ),
                            child: const Text(
                              'TEST NOTIFY',
                              style: TextStyle(color: Color(0xFF4AB08B), fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4AB08B)),
                  ),
                ),
            ],
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD84040).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD84040), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Color(0xFFD84040), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Automation Toggle Row
          ValueListenableBuilder<bool>(
            valueListenable: autoModeNotifier,
            builder: (context, autoModeValue, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: autoModeValue ? const Color(0xFF4AB08B).withOpacity(0.5) : const Color(0xFF404040),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      autoModeValue ? Icons.auto_mode : Icons.touch_app_outlined,
                      color: autoModeValue ? const Color(0xFF4AB08B) : const Color(0xFF737373),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            autoModeValue ? 'Automatic System' : 'Manual Control',
                            style: const TextStyle(
                              color: Color(0xFFF2F2F2),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            autoModeValue 
                              ? 'Sensors controlling all equipment' 
                              : 'Manual overrides active (Safety ON)',
                            style: TextStyle(
                              color: isAdmin ? const Color(0xFF737373) : const Color(0xFF555555),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: autoModeValue,
                      onChanged: isAdmin ? (value) => _toggleEquipment('auto', value) : null,
                      activeColor: const Color(0xFF4AB08B),
                      activeTrackColor: const Color(0xFF4AB08B).withOpacity(0.3),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Temperature and Humidity Gauges (Side by Side)
          Row(
            children: [
              Expanded(child: _buildTemperatureGauge()),
              const SizedBox(width: 12),
              Expanded(child: _buildHumidityGauge()),
            ],
          ),
          const SizedBox(height: 16),
          
          ValueListenableBuilder<bool>(
            valueListenable: autoModeNotifier,
            builder: (context, autoModeValue, _) {
              return Column(
                children: [
                  if (autoModeValue)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4AB08B).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF4AB08B).withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: const Color(0xFF4AB08B).withOpacity(0.4), size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Automation Mode Running',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Individual controls are view-only',
                                  style: TextStyle(color: Color(0xFF737373), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  _buildControlsGrid(),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Water Tank Card
          SizedBox(
            height: 400,
            child: _buildWaterTankCard(),
          ),
          
          const SizedBox(height: 16),
          // Light Status Card
          _buildLightStatusCard(),
          const SizedBox(height: 16),
          // Feeder Control Card
          _buildFeederControlCard(),

          const SizedBox(height: 16),
          // Camera Feed Card
          _buildCameraFeedCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTemperatureGauge() {
    return ValueListenableBuilder<double>(
      valueListenable: tempNotifier,
      builder: (context, currentTemp, _) {
        Color gaugeColor = const Color(0xFF4AB08B); // Default Green
        if (currentTemp > 40) {
          gaugeColor = const Color(0xFFD84040); // Red
        } else if (currentTemp > 32) {
          gaugeColor = const Color(0xFFFFC107); // Yellow
        }

        return DashboardCard(
          child: Column(
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: CircularGaugePainter(
                        value: currentTemp,
                        minValue: 0,
                        maxValue: 50,
                        activeColor: gaugeColor,
                        inactiveColor: const Color(0xFF3D3D3D),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTemp.toStringAsFixed(2),
                              style: TextStyle(
                                color: gaugeColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '°C',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'TEMPERATURE',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Optimal: 18–26°C',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Instant Sync Active',
                style: TextStyle(
                  color: const Color(0xFF4AB08B).withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHumidityGauge() {
    return ValueListenableBuilder<double>(
      valueListenable: humNotifier,
      builder: (context, currentHum, _) {
        Color gaugeColor = const Color(0xFF4AB08B); // Default Green
        if (currentHum > 80) {
          gaugeColor = const Color(0xFFD84040); // Red
        } else if (currentHum > 70) {
          gaugeColor = const Color(0xFFFFC107); // Yellow
        }

        return DashboardCard(
          child: Column(
            children: [
              SizedBox(
                height: 160,
                width: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(150, 150),
                      painter: CircularGaugePainter(
                        value: currentHum,
                        minValue: 0,
                        maxValue: 100,
                        activeColor: gaugeColor,
                        inactiveColor: const Color(0xFF3D3D3D),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentHum.toStringAsFixed(2),
                              style: TextStyle(
                                color: gaugeColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '%',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'HUMIDITY',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Optimal: 50–60%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Instant Sync Active',
                style: TextStyle(
                  color: const Color(0xFF4AB08B).withOpacity(0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaterTankCard() {
    return ValueListenableBuilder<double>(
      valueListenable: waterNotifier,
      builder: (context, currentWater, _) {
        return DashboardCard(
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.water_drop_outlined,
                    color: Color(0xFF4AB08B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Water Tank',
                    style: TextStyle(
                      color: Color(0xFFF2F2F2),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<bool>(
                    valueListenable: motorNotifier,
                    builder: (context, isOn, _) {
                      return GestureDetector(
                        onTap: (isAdmin && !autoMode) ? () => _toggleEquipment('motor', !isOn) : null,
                        child: StatusChip(
                          label: isOn ? 'Motor ON' : 'Motor OFF',
                          color: isOn ? const Color(0xFF4AB08B) : const Color(0xFF737373),
                          icon: isOn ? Icons.check_circle : Icons.cancel,
                          isPulsing: isOn,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(MediaQuery.of(context).size.width * 0.40, 200),
                        painter: WaterTankPainter(
                          percentage: currentWater,
                          wavePhase: _waveController.value * 2 * 3.14159,
                        ),
                      ),
                      Text(
                        '${currentWater.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Color(0xFFF2F2F2),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '184L / 1000L',
                style: TextStyle(
                  color: Color(0xFFF2F2F2),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '~45L/hour',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD84040).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Refill in 0 days',
                  style: TextStyle(
                    color: Color(0xFFD84040),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlsGrid() {
    return ValueListenableBuilder<bool>(
      valueListenable: autoModeNotifier,
      builder: (context, autoModeValue, _) {
        bool canToggle = isAdmin && !autoModeValue;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: fanNotifier,
              builder: (context, isOn, _) => ControlCard(
                title: 'Fan',
                icon: Icons.air,
                isOn: isOn,
                onToggle: canToggle ? () => _toggleEquipment('fan', !isOn) : null,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: foggerNotifier,
              builder: (context, isOn, _) => ControlCard(
                title: 'Fogger',
                icon: Icons.cloud_outlined,
                isOn: isOn,
                onToggle: canToggle ? () => _toggleEquipment('fogger', !isOn) : null,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: sprinklerNotifier,
              builder: (context, isOn, _) => ControlCard(
                title: 'Sprinkler',
                icon: Icons.water,
                isOn: isOn,
                onToggle: canToggle ? () => _toggleEquipment('sprinkler', !isOn) : null,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLightStatusCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: autoModeNotifier,
      builder: (context, autoModeValue, _) {
        bool canToggle = isAdmin && !autoModeValue;
        return ValueListenableBuilder<bool>(
          valueListenable: lightNotifier,
          builder: (context, isOn, _) {
            return DashboardCard(
              child: InkWell(
                onTap: canToggle ? () => _toggleEquipment('light', !isOn) : null,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isOn ? const Color(0xFF4AB08B).withOpacity(0.1) : const Color(0xFF1f2933),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                          color: isOn ? const Color(0xFF4AB08B) : const Color(0xFF9ca3af),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Light Control',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              !autoModeValue 
                                ? (isOn ? 'Status: Active • Tap to turn OFF' : 'Status: Inactive • Tap to turn ON')
                                : 'Status: Managed by Automation',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: isOn ? 'ON' : 'OFF',
                        color: isOn ? const Color(0xFF4AB08B) : Colors.grey[600]!,
                        icon: isOn ? Icons.check_circle : Icons.power_settings_new,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeederControlCard() {
    return ValueListenableBuilder<bool>(
      valueListenable: feederNotifier,
      builder: (context, feederValue, _) {
        return DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.dining_outlined,
                    color: Color(0xFF9ca3af),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Feeder Control',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isAdmin ? () => _toggleEquipment('feeder', true) : null,
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('UP'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: feederValue ? const Color(0xFF4AB08B) : const Color(0xFF1f2933),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: feederValue ? const Color(0xFF4AB08B) : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isAdmin ? () => _toggleEquipment('feeder', false) : null,
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('DOWN'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: !feederValue ? const Color(0xFF4AB08B) : const Color(0xFF1f2933),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: !feederValue ? const Color(0xFF4AB08B) : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Manual control for poultry feeder',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraFeedCard() {
    // Construct the stream URL using the central ApiConfig
    final String streamUrl = '${ApiConfig.baseUrl}${ApiConfig.cameraStream}';

    return DashboardCard(
      child: Column(
        children: [
          
       
          const SizedBox(height: 8),
          Text(
            'Click below to start the live stream',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showCameraDialog(streamUrl),
              icon: const Icon(Icons.videocam, size: 18),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF4AB08B),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: const Text('Start Live Feed'),
            ),
          ),
        ],
      ),
    );
  }
}

class CameraWebSocketDialog extends StatefulWidget {
  const CameraWebSocketDialog({super.key});

  @override
  State<CameraWebSocketDialog> createState() => _CameraWebSocketDialogState();
}

class _CameraWebSocketDialogState extends State<CameraWebSocketDialog> {
  String? _base64Frame;
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _socketService.addCameraListener(_onFrameReceived);
  }

  @override
  void dispose() {
    _socketService.removeCameraListener(_onFrameReceived);
    super.dispose();
  }

  void _onFrameReceived(String frame) {
    if (mounted) {
      setState(() {
        _base64Frame = frame;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1F1F1F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.videocam, color: Color(0xFF4AB08B), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Live Feed (WebSocket)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Flexible(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: Colors.black,
                  child: _base64Frame == null
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4AB08B),
                            strokeWidth: 2,
                          ),
                        )
                      : Image.memory(
                          base64Decode(_base64Frame!),
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
