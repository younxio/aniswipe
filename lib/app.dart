import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'dart:ui';
import 'src/ui/screens/login_screen.dart';
import 'src/ui/screens/signup_screen.dart';
import 'src/ui/screens/discover_screen.dart';
import 'src/ui/screens/search_screen.dart';
import 'src/ui/screens/profile_screen.dart';
import 'src/ui/widgets/three_js_background.dart';
import 'src/state/providers.dart';
import 'src/models/types.dart';
import 'src/services/convex_auth_service.dart';

class AniSwipeApp extends ConsumerWidget {
  const AniSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final userId = ref.watch(currentUserIdProvider);
    
    return MaterialApp(
      title: 'AniSwipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF1E293B),
          tertiary: const Color(0xFF334155),
          surface: const Color(0xFF0F172A),
          error: const Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onTertiary: Colors.white,
          onSurface: Colors.white,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          displayMedium: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.25,
          ),
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
          bodyMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white.withOpacity(0.08),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.black.withOpacity(0.3),
          selectedItemColor: const Color(0xFF60A5FA),
          unselectedItemColor: Colors.white.withOpacity(0.6),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      home: _buildHome(authState, userId),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
      },
    );
  }

  Widget _buildHome(AuthState authState, String? userId) {
    switch (authState) {
      case AuthState.authenticated:
        if (userId != null) {
          return const MainScreen();
        }
        return const LoginScreen();
        
      case AuthState.loading:
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
            ),
          ),
        );
        
      case AuthState.error:
      case AuthState.unauthenticated:
      default:
        // Check if user is already authenticated via Hive
        final authBox = Hive.box('auth_box');
        final existingToken = authBox.get('auth_token');
        final existingUserId = authBox.get('user_id');
        
        if (existingToken != null && existingUserId != null) {
          // User has a valid session, show main screen
          // The auth state will be updated asynchronously
          return FutureBuilder(
            future: Future.delayed(const Duration(milliseconds: 500)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF60A5FA)),
                    ),
                  ),
                );
              }
              return const MainScreen();
            },
          );
        }
        return const LoginScreen();
    }
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DiscoverScreen(),
    SearchScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 3D Background
        const ThreeJSBackground(),

        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.08),
                    ],
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.explore_outlined),
                      activeIcon: Icon(Icons.explore),
                      label: 'Discover',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.search_outlined),
                      activeIcon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.person_outline),
                      activeIcon: Icon(Icons.person),
                      label: 'Profile',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
