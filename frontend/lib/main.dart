import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/users_screen.dart';
import 'services/socket_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoultryAutomationApp());
}

class PoultryAutomationApp extends StatefulWidget {
  const PoultryAutomationApp({super.key});

  @override
  State<PoultryAutomationApp> createState() => _PoultryAutomationAppState();
}

class _PoultryAutomationAppState extends State<PoultryAutomationApp> {
  bool _isChecking = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _checkLoginStatus();
  }

  Future<void> _initializeApp() async {
    try {
      // 1. Initialize notifications first
      await NotificationService().init();
      print('✅ Notifications ready');

      // 2. Refresh UI to show app is ready
      if (mounted) {
        setState(() => _isChecking = false);
      }

      // 3. Request permissions (crucial for Android 14 foreground)
      await NotificationService().requestPermissions();
      
      // 4. Start background service only after we have permissions and app is foregrounded
      await Future.delayed(const Duration(seconds: 2));
      _initBackgroundService();
    } catch (e) {
      print('Init Error: $e');
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _initBackgroundService() async {
    await Future.delayed(const Duration(seconds: 5));
    try {
      await AppBackgroundService.initializeService();
      AppBackgroundService.start();
      print('⚙️ Background Service Initialized and Started');
    } catch (e) {
      print('Background Service Init Error: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final isLoggedIn = await ApiService.checkSession();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF4AB08B)),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Poultry Automation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1F1F1F),
        primaryColor: const Color(0xFF4AB08B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4AB08B),
          brightness: Brightness.dark,
          surface: const Color(0xFF292929),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF292929).withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: _isChecking 
        ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF4AB08B))))
        : (_isLoggedIn ? const MainScreen() : const LoginScreen()),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/users': (context) => const UsersScreen(),
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  int _activeCount = 0;
  final SocketService _socketService = SocketService();

  bool get _isAdmin => ApiService.currentUser?.role == 'admin';

  List<Widget> _getScreens() {
    if (_isAdmin) {
      return [
        const HomeScreen(),
        const ReportsScreen(),
        const UsersScreen(),
      ];
    }
    return [const HomeScreen()];
  }

  List<BottomNavigationBarItem> _getNavItems() {
    final List<BottomNavigationBarItem> items = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
    ];

    if (_isAdmin) {
      items.addAll([
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Reports',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people_outline),
          activeIcon: Icon(Icons.people),
          label: 'Users',
        ),
      ]);
    }

    return items;
  }

  @override
  void initState() {
    super.initState();
    _initSocket();
    _fetchInitialStats();
  }

  void _initSocket() {
    _socketService.initSocket(
      onSensorUpdate: (data) {
        // MainScreen doesn't need sensor data, but we provide the callback to satisfy requirements
      },
      onEquipmentUpdate: (status) {
        if (mounted) {
          int count = 0;
          if (status.fanOn) count++;
          if (status.foggerOn) count++;
          if (status.sprinklerOn) count++;
          if (status.motorOn) count++;
          if (status.lightOn) count++;
          if (status.feederOn) count++;
          setState(() => _activeCount = count);
        }
      },
    );
  }

  Future<void> _fetchInitialStats() async {
    final status = await ApiService.getLatestEquipmentStatus();
    if (status != null && mounted) {
      int count = 0;
      if (status.fanOn) count++;
      if (status.foggerOn) count++;
      if (status.sprinklerOn) count++;
      if (status.motorOn) count++;
      if (status.lightOn) count++;
      if (status.feederOn) count++;
      setState(() => _activeCount = count);
    }
  }

  @override
  void dispose() {
    _socketService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Poultry Automation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              'Smart Farm Dashboard',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _activeCount > 0 
                  ? const Color(0xFF4AB08B).withOpacity(0.12)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _activeCount > 0 
                    ? const Color(0xFF4AB08B).withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _activeCount > 0 ? const Color(0xFF4AB08B) : Colors.grey,
                    shape: BoxShape.circle,
                    boxShadow: _activeCount > 0 ? [
                      BoxShadow(
                        color: const Color(0xFF4AB08B).withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ] : [],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_activeCount/6 Online',
                  style: TextStyle(
                    color: _activeCount > 0 ? const Color(0xFF4AB08B) : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4AB08B)),
            onPressed: () {
              _fetchInitialStats();
              // Create a new key for the body to force build if necessary
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFD84040)),
            onPressed: () async {
              await ApiService.logout();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _getScreens(),
      ),
      bottomNavigationBar: _isAdmin ? BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF292929),
        selectedItemColor: const Color(0xFF4AB08B),
        unselectedItemColor: const Color(0xFF737373),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: _getNavItems(),
      ) : null,
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
