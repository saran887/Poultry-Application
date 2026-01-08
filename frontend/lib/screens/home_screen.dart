import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../widgets/common_widgets.dart';
import '../widgets/custom_painters.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../config/api_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  // Equipment states
  bool fanOn = false;
  bool foggerOn = false;
  bool sprinklerOn = false;
  bool motorOn = false;
  bool lightOn = false;
  bool feederOn = false;
  bool autoMode = true;
  
  // Sensor data
  double temperature = 0.0;
  double humidity = 0.0;
  double waterLevel = 0.0;
  
  // UI state
  bool isLoading = true;
  bool isUpdating = false;
  String? errorMessage;
  
  late AnimationController _waveController;
  final SocketService _socketService = SocketService();

  bool get isAdmin => ApiService.currentUser?.role == 'admin';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    // Initial data fetch
    _fetchAllData();
    
    // Set up Real-time updates via Socket.io
    _socketService.initSocket(
      onSensorUpdate: (data) {
        if (mounted) {
          setState(() {
            temperature = data.temperature;
            humidity = data.humidity;
            waterLevel = data.waterLevel;
            isLoading = false;
          });
        }
      },
      onEquipmentUpdate: (status) {
        if (mounted) {
          setState(() {
            fanOn = status.fanOn;
            foggerOn = status.foggerOn;
            sprinklerOn = status.sprinklerOn;
            motorOn = status.motorOn;
            lightOn = status.lightOn;
            feederOn = status.feederOn;
            autoMode = status.autoMode;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _socketService.dispose();
    super.dispose();
  }
  
  Future<void> _fetchAllData() async {
    try {
      // Fetch sensor data
      final sensorData = await ApiService.getLatestSensorData();
      if (sensorData != null) {
        if (mounted) {
          setState(() {
            temperature = sensorData.temperature;
            humidity = sensorData.humidity;
            waterLevel = sensorData.waterLevel;
            isLoading = false;
            errorMessage = null;
          });
        }
      }
      
      // Fetch equipment status
      final equipmentStatus = await ApiService.getLatestEquipmentStatus();
      if (equipmentStatus != null) {
        if (mounted) {
          setState(() {
            fanOn = equipmentStatus.fanOn;
            foggerOn = equipmentStatus.foggerOn;
            sprinklerOn = equipmentStatus.sprinklerOn;
            motorOn = equipmentStatus.motorOn;
            lightOn = equipmentStatus.lightOn;
            feederOn = equipmentStatus.feederOn;
            autoMode = equipmentStatus.autoMode;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to connect to server';
        });
      }
      print('Error fetching data: $e');
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
    setState(() {
      isUpdating = true;
      switch (equipment) {
        case 'fan':
          fanOn = newState;
          break;
        case 'fogger':
          foggerOn = newState;
          break;
        case 'sprinkler':
          sprinklerOn = newState;
          break;
        case 'motor':
          motorOn = newState;
          break;
        case 'light':
          lightOn = newState;
          break;
        case 'feeder':
          feederOn = newState;
          break;
        case 'auto':
          autoMode = newState;
          break;
      }
    });
    
    try {
      // Send update to backend
      final status = EquipmentStatus(
        fanOn: fanOn,
        foggerOn: foggerOn,
        sprinklerOn: sprinklerOn,
        motorOn: motorOn,
        lightOn: lightOn,
        feederOn: feederOn,
        autoMode: autoMode,
      );
      
      print('📤 Sending update: $equipment -> $newState');
      final success = await ApiService.updateEquipmentStatus(status);
      
      if (!success) {
        throw Exception('Failed to update');
      }
      print('✅ Update confirmed by server');
    } catch (e) {
      print('❌ Update failed: $e');
      // Revert on failure
      if (mounted) {
        setState(() {
          switch (equipment) {
            case 'fan':
              fanOn = !newState;
              break;
            case 'fogger':
              foggerOn = !newState;
              break;
            case 'sprinkler':
              sprinklerOn = !newState;
              break;
            case 'motor':
              motorOn = !newState;
              break;
            case 'light':
              lightOn = !newState;
              break;
            case 'feeder':
              feederOn = !newState;
              break;
            case 'auto':
              autoMode = !newState;
              break;
          }
        });
        
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
          ? 'Switch to AUTO mode? Manual controls will be hidden.' 
          : 'Enable MANUAL control? You can override all equipment.';
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
      builder: (context) => Dialog(
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
                        'Live Feed',
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
                  child: Image.network(
                    streamUrl,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF4AB08B),
                          strokeWidth: 2,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off, color: Colors.grey, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Connection Failed',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          
          // Manual Control Toggle Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF262626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: !autoMode ? const Color(0xFFF59E0B).withOpacity(0.5) : const Color(0xFF404040),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  !autoMode ? Icons.settings : Icons.settings_outlined,
                  color: !autoMode ? const Color(0xFFF59E0B) : const Color(0xFF737373),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !autoMode ? 'Manual Control: ON' : 'Manual Control: OFF',
                        style: const TextStyle(
                          color: Color(0xFFF2F2F2),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        !autoMode 
                          ? 'Manual overrides enabled' 
                          : 'Automation mode active (Controls hidden)',
                        style: TextStyle(
                          color: isAdmin ? const Color(0xFF737373) : const Color(0xFF555555),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: !autoMode,
                  onChanged: isAdmin ? (value) => _toggleEquipment('auto', !value) : null,
                  activeColor: const Color(0xFFF59E0B),
                  activeTrackColor: const Color(0xFFF59E0B).withOpacity(0.3),
                ),
              ],
            ),
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
          
          if (autoMode)
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

          // Control Cards Grid (Fan, Fogger, Sprinkler)
          _buildControlsGrid(),
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
    Color gaugeColor = const Color(0xFF4AB08B); // Default Green
    if (temperature > 40) {
      gaugeColor = const Color(0xFFD84040); // Red
    } else if (temperature > 32) {
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
                    value: temperature,
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
                          temperature.toStringAsFixed(2),
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
            'Updated ${DateFormat('HH:mm:ss a').format(DateTime.now())}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumidityGauge() {
    Color gaugeColor = const Color(0xFF4AB08B); // Default Green
    if (humidity > 80) {
      gaugeColor = const Color(0xFFD84040); // Red
    } else if (humidity > 70) {
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
                    value: humidity,
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
                          humidity.toStringAsFixed(2),
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
            'Updated ${DateFormat('HH:mm:ss a').format(DateTime.now())}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterTankCard() {
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
              GestureDetector(
                onTap: (isAdmin && !autoMode) ? () => _toggleEquipment('motor', !motorOn) : null,
                child: StatusChip(
                  label: motorOn ? 'Motor ON' : 'Motor OFF',
                  color: motorOn ? const Color(0xFF4AB08B) : const Color(0xFF737373),
                  icon: motorOn ? Icons.check_circle : Icons.cancel,
                  isPulsing: motorOn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(MediaQuery.of(context).size.width * 0.50, 250),
                      painter: WaterTankPainter(
                        percentage: waterLevel,
                        wavePhase: _waveController.value * 2 * 3.14159,
                      ),
                    ),
                    Text(
                      '${waterLevel.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        color: Color(0xFFF2F2F2),
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
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
  }

  Widget _buildControlsGrid() {
    bool canToggle = isAdmin && !autoMode;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        ControlCard(
          title: 'Fan',
          icon: Icons.air,
          isOn: fanOn,
          onToggle: canToggle ? () => _toggleEquipment('fan', !fanOn) : null,
        ),
        ControlCard(
          title: 'Fogger',
          icon: Icons.cloud_outlined,
          isOn: foggerOn,
          onToggle: canToggle ? () => _toggleEquipment('fogger', !foggerOn) : null,
        ),
        ControlCard(
          title: 'Sprinkler',
          icon: Icons.water,
          isOn: sprinklerOn,
          onToggle: canToggle ? () => _toggleEquipment('sprinkler', !sprinklerOn) : null,
        ),
      ],
    );
  }

  Widget _buildLightStatusCard() {
    bool canToggle = isAdmin && !autoMode;
    return DashboardCard(
      child: InkWell(
        onTap: canToggle ? () => _toggleEquipment('light', !lightOn) : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightOn ? const Color(0xFF4AB08B).withOpacity(0.1) : const Color(0xFF1f2933),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  lightOn ? Icons.lightbulb : Icons.lightbulb_outline,
                  color: lightOn ? const Color(0xFF4AB08B) : const Color(0xFF9ca3af),
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
                      !autoMode 
                        ? (lightOn ? 'Status: Active • Tap to turn OFF' : 'Status: Inactive • Tap to turn ON')
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
                label: lightOn ? 'ON' : 'OFF',
                color: lightOn ? const Color(0xFF4AB08B) : Colors.grey[600]!,
                icon: lightOn ? Icons.check_circle : Icons.power_settings_new,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeederControlCard() {
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
                    backgroundColor: feederOn ? const Color(0xFF4AB08B) : const Color(0xFF1f2933),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: feederOn ? const Color(0xFF4AB08B) : const Color(0xFF374151),
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
                    backgroundColor: !feederOn ? const Color(0xFF4AB08B) : const Color(0xFF1f2933),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: !feederOn ? const Color(0xFF4AB08B) : const Color(0xFF374151),
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
  }

  Widget _buildCameraFeedCard() {
    // Extract IP using Uri.host for perfect server alignment
    final Uri serverUri = Uri.parse(ApiConfig.baseUrl);
    String ip = serverUri.host;
    
    // Safety check for empty host or localhost
    if (ip.isEmpty || ip == 'localhost') {
      ip = '10.0.2.2'; // Standard Flutter-to-Host IP
    }
    
    final String streamUrl = 'http://$ip:5000/video_feed';

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
