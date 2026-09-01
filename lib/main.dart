import 'package:flutter/material.dart';
import 'services/app_state.dart';
import 'screens/wardrobe_screen.dart';
import 'screens/outfit_screen.dart';
import 'screens/recommend_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '共享衣柜',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFB8860B),
        scaffoldBackgroundColor: const Color(0xFFFAF6F0),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB8860B),
          primary: const Color(0xFFB8860B),
          background: const Color(0xFFFAF6F0),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFAF6F0),
          foregroundColor: Color(0xFF333333),
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFB8860B),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFB8860B),
          unselectedItemColor: Color(0xFF999999),
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F0E8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final AppState _state = AppState();
  bool _initialized = false;

  final List<Widget> _pages = [
    const WardrobeScreen(),
    const OutfitScreen(),
    const RecommendScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _state.init();
    if (mounted) {
      setState(() => _initialized = true);
      _state.addListener(_onStateChange);
    }
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFB8860B))),
      );
    }
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: '衣柜'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: '穿搭'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: '推荐'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}
