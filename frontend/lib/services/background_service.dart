import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'socket_service.dart';
import 'api_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  print('🚀 Background Service: onStart beginning');

  final socketService = SocketService();
  EquipmentStatus? lastStatus;
  
  // Live data trackers for the persistent notification
  double currentTemp = 0.0;
  double currentHum = 0.0;
  double currentWaterLevel = 0.0;
  String activeEquip = "System Online";

  // Initialize notification service in background process
  final notificationService = NotificationService();
  try {
    await notificationService.init();
    print('📦 Background Service: Notification Plugin initialized');
  } catch (e) {
    print('❌ Background Service: Specific Notification Init Error: $e');
  }

  // Helper to refresh the persistent notification with live data
  void updateLiveNotification() {
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "Poultry System: ${activeEquip}",
        content: "T: ${currentTemp.toStringAsFixed(1)}°C | H: ${currentHum.toStringAsFixed(0)}% | W: ${currentWaterLevel.toStringAsFixed(0)}%",
      );
    }
  }

  socketService.initSocket(
    onSensorUpdate: (data) {
      currentTemp = data.temperature;
      currentHum = data.humidity;
      currentWaterLevel = data.waterLevel;
      // Removed updateLiveNotification() to stop high-frequency status bar changes
    },
    onEquipmentUpdate: (status) {
      // Update the summary text for the persistent notification
      List<String> activeList = [];
      if (status.fanOn) activeList.add("Fan");
      if (status.foggerOn) activeList.add("Fogger");
      if (status.sprinklerOn) activeList.add("Sprinkler");
      if (status.motorOn) activeList.add("Motor");
      if (status.lightOn) activeList.add("Light");
      if (status.feederOn) activeList.add("Feeder");
      
      activeEquip = activeList.isEmpty ? "Monitoring Idle" : "Active: ${activeList.join(", ")}";
      updateLiveNotification();

      if (lastStatus != null) {
        final String sensorSummary = 'Temp: ${currentTemp.toStringAsFixed(1)}°C | Hum: ${currentHum.toStringAsFixed(0)}% | Water: ${currentWaterLevel.toStringAsFixed(0)}%';
        
        // Fire all notifications asynchronously without waiting
        if (status.fanOn != lastStatus!.fanOn) {
          notificationService.showNotification(
            id: 991,
            title: status.fanOn ? '⚡ Fan ON' : '⚪ Fan OFF',
            body: 'Cooling ${status.fanOn ? 'started' : 'stopped'} | $sensorSummary',
          );
        }
        if (status.foggerOn != lastStatus!.foggerOn) {
          notificationService.showNotification(
            id: 992,
            title: status.foggerOn ? '⚡ Fogger ON' : '⚪ Fogger OFF',
            body: 'Fogging ${status.foggerOn ? 'started' : 'stopped'} | $sensorSummary',
          );
        }
        if (status.sprinklerOn != lastStatus!.sprinklerOn) {
          notificationService.showNotification(
            id: 993,
            title: status.sprinklerOn ? '⚡ Sprinkler ON' : '⚪ Sprinkler OFF',
            body: 'Sprinkler ${status.sprinklerOn ? 'started' : 'stopped'} | $sensorSummary',
          );
        }
        if (status.motorOn != lastStatus!.motorOn) {
          notificationService.showNotification(
            id: 994,
            title: status.motorOn ? '⚡ Motor ON' : '⚪ Motor OFF',
            body: 'Water pump ${status.motorOn ? 'started' : 'stopped'} | $sensorSummary',
          );
        }
        if (status.lightOn != lastStatus!.lightOn) {
          notificationService.showNotification(
            id: 995,
            title: status.lightOn ? '💡 Light ON' : '⚪ Light OFF',
            body: 'Lighting ${status.lightOn ? 'activated' : 'deactivated'} | $sensorSummary',
          );
        }
        if (status.feederOn != lastStatus!.feederOn) {
          notificationService.showNotification(
            id: 996,
            title: status.feederOn ? '⚡ Feeder ON' : '⚪ Feeder OFF',
            body: 'Feeding ${status.feederOn ? 'started' : 'stopped'} | $sensorSummary',
          );
        }
      }
      lastStatus = status;
    },
  );

  // Send status report and refresh foreground info every 1 hour
  Timer.periodic(const Duration(hours: 1), (timer) {
    updateLiveNotification();
    notificationService.showNotification(
      id: 889,
      title: 'Hourly Status Report',
      body: 'Temp: ${currentTemp.toStringAsFixed(1)}°C | Hum: ${currentHum.toStringAsFixed(0)}% | Water Tank: ${currentWaterLevel.toStringAsFixed(0)}%',
    );
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

class AppBackgroundService {
  @pragma('vm:entry-point')
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'equipment_alerts',
        initialNotificationTitle: 'Poultry Smart System',
        initialNotificationContent: 'Monitoring Live Data 24/7',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  static void start() {
    FlutterBackgroundService().startService();
  }
}
