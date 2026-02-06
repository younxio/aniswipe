# AniSwipe Production Readiness Guide

This document outlines comprehensive recommendations for making the AniSwipe anime discovery app fully production-ready.

---

## 1. Error Handling & Retry Mechanisms with Dio

### Current Issue
The [`anime_api.dart`](lib/src/services/anime_api.dart) has basic error handling but lacks retry logic and comprehensive error categorization.

### Recommendations

#### 1.1 Create an Interceptor for Automatic Retries

```dart
// lib/src/core/network/retry_interceptor.dart
class RetryInterceptor extends Interceptor {
  final int maxRetries;
  final Duration initialDelay;
  
  RetryInterceptor({this.maxRetries = 3, this.initialDelay = const Duration(milliseconds: 500)});

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    if (_shouldRetry(err)) {
      final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
      if (retryCount < maxRetries) {
        await Future.delayed(initialDelay * (retryCount + 1));
        err.requestOptions.extra['retryCount'] = retryCount + 1;
        return handler.resolve(await _retryRequest(err.requestOptions));
      }
    }
    return super.onError(err, handler);
  }

  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
           err.type == DioExceptionType.receiveTimeout ||
           err.type == DioExceptionType.connectionError ||
           err.response?.statusCode == 503;
  }

  Future<Response> _retryRequest(RequestOptions options) async {
    final dio = Dio();
    return dio.request(options.path, options: options);
  }
}
```

#### 1.2 Custom Exception Hierarchy

```dart
// lib/src/core/exceptions/app_exceptions.dart
sealed class AppException implements Exception {
  final String message;
  final String? code;
  
  const AppException(this.message, [this.code]);
}

class NetworkException extends AppException {
  NetworkException([String message = 'Network error']) : super(message, 'NETWORK_ERROR');
}

class ServerException extends AppException {
  final int statusCode;
  ServerException(this.statusCode, [String message = 'Server error']) 
    : super(message, 'SERVER_ERROR_$statusCode');
}

class CacheException extends AppException {
  CacheException([String message = 'Cache error']) : super(message, 'CACHE_ERROR');
}

class AuthenticationException extends AppException {
  AuthenticationException([String message = 'Authentication required']) 
    : super(message, 'AUTH_ERROR');
}
```

#### 1.3 Enhanced Dio Configuration

```dart
// lib/src/core/network/dio_client.dart
class DioClient {
  static Dio create({
    required String baseUrl,
    required String apiKey,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {
          'X-MAL-CLIENT-ID': apiKey,
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.addAll([
      RetryInterceptor(maxRetries: 3),
      LogInterceptor(requestBody: true, responseBody: true),
      ErrorInterceptor(),
    ]);

    return dio;
  }
}
```

---

## 2. State Management Architecture

### Current Issue
The [`providers.dart`](lib/src/state/providers.dart) has a mix of providers and notifiers that could be better organized.

### Recommendations

#### 2.1 Organize Providers by Domain

```
lib/src/state/
├── auth/
│   ├── auth_provider.dart
│   ├── auth_notifier.dart
│   └── auth_state.dart
├── anime/
│   ├── discover_provider.dart
│   ├── search_provider.dart
│   ├── favorites_provider.dart
│   └── watchlist_provider.dart
├── ui/
│   ├── theme_provider.dart
│   ├── navigation_provider.dart
│   └── toast_provider.dart
└── app_state.dart
```

#### 2.2 Use Freezed for State Classes

```dart
// lib/src/state/auth/auth_state.dart
@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = Initial;
  const factory AuthState.authenticated(User user) = Authenticated;
  const factory AuthState.unauthenticated() = Unauthenticated;
  const factory AuthState.loading() = Loading;
  const factory AuthState.error(String message) = Error;
}

// lib/src/state/auth/auth_provider.dart
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    authService: ref.watch(convexAuthServiceProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final SecureStorage _secureStorage;
  
  AuthNotifier(this._authService, this._secureStorage) : super(const AuthState.initial());
  
  Future<void> signInWithClerk() async {
    state = const AuthState.loading();
    try {
      final user = await _authService.signInWithClerk();
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }
}
```

#### 2.3 Implement Offline-First Strategy

```dart
// lib/src/state/anime/discover_provider.dart
final discoverProvider = AsyncNotifierProvider<DiscoverNotifier, List<Anime>>(() {
  return DiscoverNotifier();
});

class DiscoverNotifier extends AsyncNotifier<List<Anime>> {
  @override
  Future<List<Anime>> build() async {
    // First, try to load from cache
    final cached = await _loadFromCache();
    if (cached.isNotEmpty) {
      state = AsyncData(cached);
      // Then refresh from network
      _refreshFromNetwork();
      return cached;
    }
    // If no cache, load from network
    return await _fetchFromNetwork();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final anime = await _fetchFromNetwork();
      await _saveToCache(anime);
      state = AsyncData(anime);
    } catch (e, stack) {
      state = AsyncError(e, stack);
    }
  }
}
```

---

## 3. Data Caching & Persistence with Hive

### Current Issue
The app uses basic Hive boxes but lacks proper cache invalidation and data consistency.

### Recommendations

#### 3.1 Create Cache Manager

```dart
// lib/src/core/cache/cache_manager.dart
class CacheManager {
  static const String _discoverBox = 'discover_cache';
  static const String _animeBox = 'anime_cache';
  static const String _userDataBox = 'user_data';
  static const Duration _defaultTtl = Duration(hours: 1);

  final Box _discoverBox;
  final Box _animeBox;
  final Box _userDataBox;

  CacheManager(this._discoverBox, this._animeBox, this._userDataBox);

  // Generic cache operations
  Future<T?> get<T>(String box, String key) async {
    final data = _getBox(box).get(key);
    if (data == null) return null;
    
    final cached = CacheEntry<T>.fromJson(data as Map<String, dynamic>);
    if (cached.isExpired) {
      await delete(box, key);
      return null;
    }
    return cached.data;
  }

  Future<void> set<T>(String box, String key, T data, {Duration? ttl}) async {
    final entry = CacheEntry(
      data: data,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      ttl: ttl ?? _defaultTtl,
    );
    await _getBox(box).put(key, entry.toJson());
  }

  Future<void> delete(String box, String key) async {
    await _getBox(box).delete(key);
  }

  Future<void> clearBox(String box) async {
    await _getBox(box).clear();
  }

  Box _getBox(String name) {
    switch (name) {
      case _discoverBox: return _discoverBox;
      case _animeBox: return _animeBox;
      case _userDataBox: return _userDataBox;
      default: throw ArgumentError('Unknown box: $name');
    }
  }
}

class CacheEntry<T> {
  final T data;
  final int timestamp;
  final Duration ttl;

  CacheEntry({required this.data, required this.timestamp, required this.ttl});

  bool get isExpired => DateTime.now().millisecondsSinceEpoch - timestamp > ttl.inMilliseconds;

  Map<String, dynamic> toJson() => {
    'data': data,
    'timestamp': timestamp,
    'ttl': ttl.inMilliseconds,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    data: json['data'],
    timestamp: json['timestamp'],
    ttl: Duration(milliseconds: json['ttl']),
  );
}
```

#### 3.2 Implement Offline Queue with Sync

```dart
// lib/src/core/cache/offline_queue.dart
class OfflineQueue {
  final Box _queueBox;
  final ConvexClient _client;
  final Logger _logger;

  OfflineQueue(this._queueBox, this._client, this._logger);

  Future<void> enqueue(OfflineAction action) async {
    final entry = QueueEntry(
      id: const Uuid().v4(),
      type: action.type,
      payload: action.payload,
      timestamp: DateTime.now(),
      retryCount: 0,
    );
    await _queueBox.put(entry.id, entry.toJson());
    _logger.info('Action queued: ${action.type}');
  }

  Future<void> sync() async {
    final actions = await getPendingActions();
    
    for (final action in actions) {
      try {
        await _processAction(action);
        await _queueBox.delete(action.id);
        _logger.info('Action synced: ${action.type}');
      } catch (e) {
        await _updateRetryCount(action);
        if (action.retryCount >= 3) {
          _logger.error('Action failed after 3 retries: ${action.type}');
          // Could move to failed queue for later review
        }
      }
    }
  }

  Future<void> _processAction(QueueEntry action) async {
    switch (action.type) {
      case 'favorite':
        await _client.mutation('saveFavorite', action.payload);
        break;
      case 'comment':
        await _client.mutation('addComment', action.payload);
        break;
      // Add more cases
    }
  }
}
```

---

## 4. Environment-Specific Configuration

### Current Issue
The `.env` handling is basic and doesn't support environment-specific configurations.

### Recommendations

#### 4.1 Enhanced Environment Configuration

```dart
// lib/src/core/config/app_config.dart
class AppConfig {
  final String appName;
  final String apiBaseUrl;
  final String convexDeploymentUrl;
  final String clerkPublishableKey;
  final bool enableDebugLogs;
  final bool enableCrashReporting;
  final Environment environment;

  AppConfig._({
    required this.appName,
    required this.apiBaseUrl,
    required this.convexDeploymentUrl,
    required this.clerkPublishableKey,
    required this.enableDebugLogs,
    required this.enableCrashReporting,
    required this.environment,
  });

  factory AppConfig.fromEnvironment() {
    final env = dotenv.env;
    
    return AppConfig._(
      appName: env['APP_NAME'] ?? 'AniSwipe',
      apiBaseUrl: env['API_BASE_URL'] ?? 'https://api.jikan.moe/v4',
      convexDeploymentUrl: env['CONVEX_DEPLOYMENT_URL']!,
      clerkPublishableKey: env['CLERK_PUBLISHABLE_KEY']!,
      enableDebugLogs: env['ENABLE_DEBUG_LOGS'] == 'true',
      enableCrashReporting: env['ENABLE_CRASH_REPORTING'] == 'true',
      environment: _parseEnvironment(env['ENVIRONMENT']),
    );
  }

  static Environment _parseEnvironment(String? env) {
    switch (env?.toLowerCase()) {
      case 'production': return Environment.production;
      case 'staging': return Environment.staging;
      case 'development': return Environment.development;
      default: return Environment.development;
    }
  }
}

enum Environment { development, staging, production }

class EnvironmentConfig {
  static final AppConfig config = AppConfig.fromEnvironment();

  static bool get isDevelopment => config.environment == Environment.development;
  static bool get isStaging => config.environment == Environment.staging;
  static bool get isProduction => config.environment == Environment.production;
}
```

#### 4.2 Environment-Specific .env Files

```
.env.development
.env.staging
.env.production
```

```bash
# .env.development
ENVIRONMENT=development
API_BASE_URL=https://api.jikan.moe/v4
CONVEX_DEPLOYMENT_URL=https://your-dev.convex.cloud
CLERK_PUBLISHABLE_KEY=pk_dev_xxx
ENABLE_DEBUG_LOGS=true
ENABLE_CRASH_REPORTING=false
```

#### 4.3 Build Configuration

```dart
// lib/main.dart with environment-aware initialization
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment-specific .env file
  await dotenv.load(
    fileName: EnvironmentConfig.isProduction 
      ? '.env.production' 
      : EnvironmentConfig.isStaging 
        ? '.env.staging' 
        : '.env.development',
  );

  if (EnvironmentConfig.isDevelopment) {
    // Additional debug configuration
  }

  runApp(const AniSwipeApp());
}
```

---

## 5. Logging & Crash Reporting

### Current Issue
The app uses basic `print` statements instead of structured logging and crash reporting.

### Recommendations

#### 5.1 Structured Logging

```dart
// lib/src/core/logging/logger.dart
class Logger {
  final String _tag;
  final bool _isDebug;

  Logger(this._tag) : _isDebug = EnvironmentConfig.isDevelopment;

  void debug(String message, [Map<String, dynamic>? extras]) {
    if (_isDebug) {
      _log('DEBUG', message, extras);
    }
  }

  void info(String message, [Map<String, dynamic>? extras]) {
    _log('INFO', message, extras);
  }

  void warning(String message, [Map<String, dynamic>? extras]) {
    _log('WARNING', message, extras);
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _log('ERROR', message, {
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
    });
    _sendToCrashReporting(message, error, stackTrace);
  }

  void _log(String level, String message, [Map<String, dynamic>? extras]) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$level] [$_tag] $message';
    
    if (extras != null) {
      // Could write to file for later analysis
    }

    // In production, send to remote logging service
    if (!EnvironmentConfig.isDevelopment) {
      // Firebase Crashlytics, Sentry, etc.
    }
  }

  void _sendToCrashReporting(String message, [dynamic error, StackTrace? stackTrace]) {
    if (EnvironmentConfig.isProduction) {
      // FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }
}

// Usage
final log = Logger('AnimeService');
log.debug('Fetching anime list');
log.info('Anime saved to favorites', {'animeId': animeId});
log.error('Failed to fetch anime', error, stackTrace);
```

#### 5.2 Crash Reporting Integration

```dart
// lib/src/core/logging/crash_reporter.dart
class CrashReporter {
  static Future<void> initialize() async {
    // Firebase Crashlytics
    // await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    
    // Set custom keys for better debugging
    // await FirebaseCrashlytics.instance.setCustomKey('app_version', '1.0.0');
    // await FirebaseCrashlytics.instance.setUserId(userId);
  }

  static Future<void> recordError(dynamic error, StackTrace stackTrace, 
      [Map<String, dynamic>? extras]) async {
    // Log to console in development
    if (EnvironmentConfig.isDevelopment) {
      print('ERROR: $error\n$stackTrace');
    }

    // Send to crash reporting in production
    if (EnvironmentConfig.isProduction) {
      // await FirebaseCrashlytics.instance.recordError(error, stackTrace, extras: extras);
    }
  }

  static Future<void> recordFatalError(dynamic error, StackTrace stackTrace) async {
    // Critical errors that caused app termination
    if (EnvironmentConfig.isProduction) {
      // await FirebaseCrashlytics.instance.recordFatalError(error, stackTrace);
    }
  }
}
```

---

## 6. Testing Setup

### Current Issue
The app has basic test files but lacks comprehensive test coverage.

### Recommendations

#### 6.1 Test Directory Structure

```
test/
├── unit/
│   ├── models/
│   │   ├── anime_test.dart
│   │   ├── comment_test.dart
│   │   └── profile_test.dart
│   ├── services/
│   │   ├── anime_api_test.dart
│   │   ├── convex_service_test.dart
│   │   └── recommendation_service_test.dart
│   └── state/
│       ├── auth_state_test.dart
│       └── providers_test.dart
├── widget/
│   ├── screens/
│   │   ├── discover_screen_test.dart
│   │   ├── search_screen_test.dart
│   │   └── profile_screen_test.dart
│   └── components/
│       ├── anime_card_test.dart
│       └── swipe_stack_test.dart
├── integration/
│   ├── app_test.dart
│   └── offline_sync_test.dart
└── helpers/
    ├── mocks/
    │   ├── mock_convex_client.dart
    │   └── mock_anime_api.dart
    └── test_utils.dart
```

#### 6.2 Unit Tests Example

```dart
// test/unit/services/recommendation_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:aniswipe/src/services/recommendation_service.dart';
import 'package:aniswipe/src/models/anime.dart';

class MockAnimeApi extends Mock implements AnimeApi {}

void main() {
  late RecommendationService service;
  late MockAnimeApi mockApi;

  setUp(() {
    mockApi = MockAnimeApi();
    service = RecommendationService(mockApi);
  });

  group('getRecommendations', () {
    test('returns empty list when no favorites', () async {
      final result = await service.getRecommendations([], topN: 10);
      expect(result, isEmpty);
    });

    test('returns recommendations based on favorite genres', () async {
      final favorites = [
        Anime(
          malId: 1,
          title: 'Anime 1',
          imageUrl: 'url1',
          synopsis: 'Synopsis',
          score: 8.0,
          episodes: 12,
          type: 'TV',
          status: 'Airing',
          rating: 'PG-13',
          genres: ['Action', 'Adventure'],
        ),
      ];

      final result = await service.getRecommendations(favorites, topN: 10);
      
      expect(result, isNotEmpty);
      // Verify genres are considered
      for (final anime in result) {
        expect(anime.genres, anyOf(['Action', 'Adventure']));
      }
    });

    test('limits results to topN', () async {
      final favorites = List.generate(5, (i) => createTestAnime(i));
      
      final result = await service.getRecommendations(favorites, topN: 3);
      
      expect(result.length, lessThanOrEqualTo(3));
    });
  });
}
```

#### 6.3 Widget Tests Example

```dart
// test/widget/screens/discover_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniswipe/src/ui/screens/discover_screen.dart';
import 'package:aniswipe/src/state/providers.dart';
import '../helpers/test_utils.dart';

void main() {
  testWidgets('displays anime cards in stack', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverStackProvider.overrideWith((ref) => [
            createTestAnime(1),
            createTestAnime(2),
          ]),
        ],
        child: const MaterialApp(home: DiscoverScreen()),
      ),
    );

    expect(find.byType(AnimeCard), findsNWidgets(2));
    expect(find.text('Anime 1'), findsOneWidget);
    expect(find.text('Anime 2'), findsOneWidget);
  });

  testWidgets('swipe right adds to favorites', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverStackProvider.overrideWith((ref) => [createTestAnime(1)]),
        ],
        child: const MaterialApp(home: DiscoverScreen()),
      ),
    );

    // Perform swipe right gesture
    final card = find.byType(AnimeCard).first;
    await tester.drag(card, const Offset(500, 0));
    await tester.pumpAndSettle();

    // Verify favorite was added
    verify(() => mockConvexService.saveFavorite(any(), any())).called(1);
  });
}
```

---

## 7. Performance Optimizations

### Current Issue
The swipe animations and list scrolling may not be optimized for all devices.

### Recommendations

#### 7.1 Image Caching with Optimization

```dart
// lib/src/ui/widgets/anime_card.dart
class AnimeCard extends ConsumerWidget {
  const AnimeCard({super.key, required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: anime.imageUrl ?? '',
          memCacheWidth: 400, // Reduce memory usage
          memCacheHeight: 600,
          maxWidthDiskCache: 400,
          maxHeightDiskCache: 600,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildErrorWidget(),
          fadeInDuration: const Duration(milliseconds: 200),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
```

#### 7.2 Optimize List Performance

```dart
// Use ListView.builder instead of ListView
// Implement pagination for large lists
final animeListProvider = FutureProvider.autoDispose
    .family<List<Anime>, int>((ref, page) async {
  final service = ref.watch(animeApiProvider);
  return service.fetchDiscover(page: page);
});

// In the widget
Consumer(
  builder: (context, ref, child) {
    final animePages = ref.watch(animeListProvider);
    return animePages.when(
      data: (anime) => ListView.builder(
        itemCount: anime.length,
        itemBuilder: (context, index) => AnimeListTile(anime: anime[index]),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, stack) => ErrorWidget(e),
    );
  },
);
```

#### 7.3 Swipe Animation Optimization

```dart
// lib/src/ui/widgets/swipe_stack.dart
class SwipeStack extends StatefulWidget {
  const SwipeStack({super.key, required this.items, required this.onSwipe});

  final List<Anime> items;
  final Function(Anime, SwipeDirection) onSwipe;

  @override
  State<SwipeStack> createState() => _SwipeStackState();
}

class _SwipeStackState extends State<SwipeStack> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<Offset> _translationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: widget.items.asMap().entries.reversed.map((entry) {
        final index = entry.key;
        final anime = entry.value;
        
        if (index >= 3) return const SizedBox.shrink(); // Only render top 3
        
        return Positioned.fill(
          child: _buildCard(anime, index),
        );
      }).toList(),
    );
  }

  Widget _buildCard(Anime anime, int index) {
    final offset = widget.items.length - index;
    final scale = 1.0 - (offset * 0.05);
    final opacity = 1.0 - (offset * 0.3);

    return Transform.scale(
      scale: scale,
      child: Opacity(
        opacity: opacity,
        child: Dismissible(
          key: Key('${anime.malId}'),
          direction: DismissDirection.horizontal,
          onDismissed: (direction) {
            final swipeDirection = direction == DismissDirection.endToStart
                ? SwipeDirection.left
                : SwipeDirection.right;
            widget.onSwipe(anime, swipeDirection);
          },
          child: AnimeCard(anime: anime),
        ),
      ),
    );
  }
}
```

---

## 8. Security Best Practices

### Current Issue
API keys and sensitive data may be exposed.

### Recommendations

#### 8.1 Secure API Key Storage

```dart
// lib/src/core/security/security_manager.dart
class SecurityManager {
  static const String _keyConvexUrl = 'convex_deployment_url';
  static const String _keyClerkKey = 'clerk_publishable_key';
  static const String _keyApiKey = 'mal_api_key';

  // Use flutter_secure_storage instead of Hive for sensitive data
  final FlutterSecureStorage _secureStorage;

  SecurityManager(this._secureStorage);

  Future<String?> getConvexDeploymentUrl() async {
    return await _secureStorage.read(key: _keyConvexUrl);
  }

  Future<void> saveConvexDeploymentUrl(String value) async {
    await _secureStorage.write(key: _keyConvexUrl, value: value);
  }

  // For Android, enable encryption in AndroidManifest
  // For iOS, ensure proper Info.plist configuration
}

// In main.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final secureStorage = FlutterSecureStorage();
  final securityManager = SecurityManager(secureStorage);
  
  // Move sensitive data from .env to secure storage on first launch
  if (!await secureStorage.containsKey(key: 'initialized')) {
    await securityManager.saveConvexDeploymentUrl(dotenv.env['CONVEX_DEPLOYMENT_URL']!);
    await securityManager.saveClerkKey(dotenv.env['CLERK_PUBLISHABLE_KEY']!);
    await secureStorage.write(key: 'initialized', value: 'true');
  }
}
```

#### 8.2 Certificate Pinning for API Calls

```dart
// lib/src/core/network/dio_client.dart
class DioClient {
  static Dio createWithSecurity() {
    final dio = Dio();
    
    // Certificate pinning (for production)
    // SecurityConfig.addCertificates(dio);
    
    // Only allow specific headers
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Remove any sensitive headers
        options.headers.remove('Authorization');
        return handler.next(options);
      },
    ));
    
    return dio;
  }
}
```

#### 8.3 Biometric Authentication (Optional)

```dart
// lib/src/core/security/biometric_auth.dart
class BiometricAuth {
  final LocalAuthentication _localAuth;

  BiometricAuth(this._localAuth);

  Future<bool> isAvailable() async {
    return await _localAuth.canCheckBiometrics;
  }

  Future<bool> authenticate({required String reason}) async {
    if (!await isAvailable()) return false;
    
    return await _localAuth.authenticate(
      localizedReason: reason,
      options: const AuthenticationOptions(
        biometricOnly: true,
        useErrorDialogs: true,
        stickyAuth: true,
      ),
    );
  }
}

// Usage for sensitive operations
Future<void> _showDeleteConfirmation() async {
  final biometric = BiometricAuth(LocalAuthentication());
  
  if (await biometric.authenticate(
    reason: 'Confirm your identity to delete account'
  )) {
    // Proceed with deletion
  }
}
```

---

## 9. CI/CD Pipeline Configuration

### Current Issue
No CI/CD configuration exists for automated builds and deployments.

### Recommendations

#### 9.1 GitHub Actions Workflow

```yaml
# .github/workflows/flutter.yml
name: AniSwipe CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test --coverage

  build-android:
    needs: analyze
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter build apk --release
        env:
          CONVEX_DEPLOYMENT_URL: ${{ secrets.CONVEX_DEPLOYMENT_URL }}
          CLERK_PUBLISHABLE_KEY: ${{ secrets.CLERK_PUBLISHABLE_KEY }}
      - uses: actions/upload-artifact@v4
        with:
          name: android-apk
          path: build/app/outputs/flutter-apk/app-release.apk

  build-ios:
    needs: analyze
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter build ipa --release
        env:
          CONVEX_DEPLOYMENT_URL: ${{ secrets.CONVEX_DEPLOYMENT_URL }}
          CLERK_PUBLISHABLE_KEY: ${{ secrets.CLERK_PUBLISHABLE_KEY }}
      - uses: actions/upload-artifact@v4
        with:
          name: ios-ipa
          path: build/ios/iphoneos/Runner.ipa

  deploy-web:
    needs: build-web
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.19.0'
      - run: flutter pub get
      - run: flutter build web --release
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
```

#### 9.2 Code Quality Gates

```yaml
# .github/workflows/code-quality.yml
name: Code Quality

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter analyze
      - run: flutter format --set-exit-if-changed lib/

  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage --coverage-exclude='**/main.dart'
      - uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          files: ./coverage/lcov.info

  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub outdated
      - run: flutter pub deps --style=compact
```

---

## 10. Accessibility Compliance

### Current Issue
The app may not fully comply with WCAG accessibility guidelines.

### Recommendations

#### 10.1 Semantic Widgets

```dart
// lib/src/ui/widgets/anime_card.dart
class AnimeCard extends StatelessWidget {
  const AnimeCard({super.key, required this.anime});

  final Anime anime;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${anime.title}, rated ${anime.score.toStringAsFixed(1)} out of 10',
      hint: 'Double tap to view details, swipe right to add to favorites',
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DetailsScreen(anime: anime)),
        ),
        child: Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Poster image for ${anime.title}',
                excludeSemantics: true,
                child: CachedNetworkImage(
                  imageUrl: anime.imageUrl ?? '',
                  errorListener: () {},
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      semanticsLabel: anime.title,
                    ),
                    Text(
                      'Score: ${anime.score.toStringAsFixed(1)}',
                      semanticsLabel: 'Score ${anime.score.toStringAsFixed(1)} out of 10',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### 10.2 High Contrast Support

```dart
// lib/src/ui/theme/app_theme.dart
class AppTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
    ).copyWith(
      // High contrast mode support
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
    );
  }

  static ThemeData highContrastTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.highContrastLight(),
    ).copyWith(
      // Increase touch target sizes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 48), // WCAG AA minimum
        ),
      ),
      // Larger fonts
      textTheme: ThemeData.highContrastLight().textTheme.apply(
        fontSizeFactor: 1.2,
      ),
    );
  }
}
```

#### 10.3 Screen Reader Testing

```dart
// Add to test/widget/accessibility_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('verify discover screen is accessible', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: DiscoverScreen()),
      ),
    );

    // Verify semantic nodes exist
    expect(find.bySemanticsLabel('Discover anime'), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(find.bySemanticsLabel('Profile'), findsOneWidget);

    // Verify minimum touch target sizes
    final discoverButton = find.byType(ElevatedButton).first;
    expect(tester.getSize(discoverButton).width, greaterThanOrEqualTo(44));
    expect(tester.getSize(discoverButton).height, greaterThanOrEqualTo(44));
  });
}
```

---

## 11. Additional Production Considerations

### 11.1 App Icon & Splash Screen

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/
    - assets/splash/
  fonts:
    - family: Poppins
      fonts:
        - asset: assets/fonts/Poppins-Regular.ttf
        - asset: assets/fonts/Poppins-Bold.ttf
          weight: 700
```

### 11.2 Deep Linking

```dart
// lib/src/core/deep_linking/deep_link_handler.dart
class DeepLinkHandler {
  static Future<void> handleLink(Uri link) async {
    if (link.host == 'aniswipe.app') {
      final path = link.pathSegments;
      
      if (path.first == 'share') {
        // Handle share links
        final token = path[1];
        // Navigate to anime details
      }
    }
  }
}
```

### 11.3 Analytics Integration

```dart
// lib/src/core/analytics/analytics_service.dart
class AnalyticsService {
  // Firebase Analytics or Mixpanel
  static void logEvent(String name, [Map<String, dynamic>? parameters]) {
    // FirebaseAnalytics.instance.logEvent(name, parameters);
  }

  static void setUserProperties({
    required String userId,
    String? userRole,
    String? subscriptionType,
  }) {
    // FirebaseAnalytics.instance.setUserProperty(name: 'user_id', value: userId);
  }

  static void trackScreen(String screenName) {
    // FirebaseAnalytics.instance.logScreenView(screenName: screenName);
  }
}
```

---

## Summary Checklist

| Category | Priority | Action Item |
|----------|----------|-------------|
| Error Handling | High | Implement retry interceptor for Dio |
| Error Handling | High | Create exception hierarchy |
| State Management | Medium | Refactor providers by domain |
| Caching | High | Implement CacheManager |
| Caching | High | Build offline queue with sync |
| Configuration | Medium | Environment-specific configs |
| Logging | High | Integrate crash reporting |
| Testing | High | Add unit tests for services |
| Testing | Medium | Add widget tests |
| Performance | Medium | Optimize image caching |
| Performance | High | Optimize list scrolling |
| Security | High | Move keys to secure storage |
| CI/CD | High | Setup GitHub Actions |
| Accessibility | Medium | Add semantic widgets |
| Analytics | Medium | Integrate analytics |

---

## Next Steps

1. **Immediate**: Set up GitHub Actions for CI/CD
2. **This Sprint**: Implement retry interceptor and exception hierarchy
3. **This Sprint**: Build comprehensive test suite
4. **Next Sprint**: Integrate crash reporting and analytics
5. **Ongoing**: Accessibility audit and improvements
