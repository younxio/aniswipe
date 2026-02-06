import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import '../models/anime.dart';
import '../models/comment.dart';
import '../models/profile.dart';
import '../models/types.dart';
import '../services/anime_api.dart';
import '../services/convex_service.dart';
import '../services/convex_auth_service.dart';

// ============================================
// DIO PROVIDER
// ============================================

final dioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
});

// ============================================
// SERVICE PROVIDERS
// ============================================

final animeApiProvider = Provider<AnimeApi>((ref) {
  final dio = ref.watch(dioProvider);
  return AnimeApi(dio);
});

final convexServiceProvider = Provider<ConvexService>((ref) {
  final dio = ref.watch(dioProvider);
  final baseUrl = dotenv.env['CONVEX_DEPLOYMENT_URL'] ?? '';
  return ConvexService(dio, baseUrl: baseUrl);
});

final convexAuthServiceProvider = Provider<ConvexAuthService>((ref) {
  final dio = ref.watch(dioProvider);
  final baseUrl = dotenv.env['CONVEX_DEPLOYMENT_URL'] ?? '';
  return ConvexAuthService(dio, baseUrl: baseUrl);
});

// ============================================
// AUTH STATE PROVIDERS
// ============================================

final authStateProvider = StateProvider<AuthState>((ref) {
  return AuthState.initial;
});

final currentUserIdProvider = StateProvider<String?>((ref) {
  final authBox = Hive.box('auth_box');
  return authBox.get('user_id') as String?;
});

// ============================================
// DISCOVER PROVIDERS
// ============================================

class DiscoverStackNotifier extends StateNotifier<List<Anime>> {
  final AnimeApi _animeApi;

  DiscoverStackNotifier(this._animeApi) : super([]) {
    loadInitialStack();
  }

  Future<void> loadInitialStack() async {
    try {
      final animeList = await _animeApi.fetchDiscover(limit: 20);
      state = animeList;
    } catch (e) {
      print('Error loading initial stack: $e');
    }
  }

  Future<void> refreshStack() async {
    try {
      final animeList = await _animeApi.fetchDiscover(limit: 20);
      state = animeList;
    } catch (e) {
      print('Error refreshing stack: $e');
    }
  }

  void removeTopCard() {
    if (state.isNotEmpty) {
      state = state.sublist(1);
    }
  }
}

final discoverStackProvider = StateNotifierProvider<DiscoverStackNotifier, List<Anime>>((ref) {
  final animeApi = ref.watch(animeApiProvider);
  return DiscoverStackNotifier(animeApi);
});

final discoverLoadingProvider = StateProvider<bool>((ref) => false);

// ============================================
// UNDO ACTION PROVIDER
// ============================================

final undoActionProvider = StateProvider<UndoAction?>((ref) => null);

// ============================================
// SELECTED ANIME PROVIDER
// ============================================

final selectedAnimeProvider = StateProvider<Anime?>((ref) => null);

// ============================================
// USER PROFILE PROVIDERS
// ============================================

final userProfileDataProvider = FutureProvider<UserProfileData?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final service = ref.watch(convexServiceProvider);
  return await service.getUserProfileData(userId);
});

// ============================================
// SEARCH PROVIDERS
// ============================================

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchFilterProvider = StateProvider<AnimeFilter>((ref) => const AnimeFilter());

final searchResultsProvider = StateProvider<List<Anime>>((ref) => []);

final searchLoadingProvider = StateProvider<bool>((ref) => false);

// ============================================
// COMMENTS PROVIDER
// ============================================

final commentsProvider = FutureProvider.family<List<Comment>, int>((ref, animeId) async {
  final service = ref.watch(convexServiceProvider);
  return await service.getComments(animeId);
});

// ============================================
// ANIME STATUS PROVIDERS
// ============================================

final animeFavoriteStatusProvider = FutureProvider.family<bool, int>((ref, animeId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final service = ref.watch(convexServiceProvider);
  return await service.isAnimeFavorited(userId, animeId);
});

final animeWatchLaterStatusProvider = FutureProvider.family<bool, int>((ref, animeId) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final service = ref.watch(convexServiceProvider);
  return await service.isAnimeInWatchLater(userId, animeId);
});

// ============================================
// HELPER FUNCTIONS
// ============================================

void showToast(WidgetRef ref, String message, {ToastType type = ToastType.info}) {
  // Show a toast notification
  // This is a simplified implementation
  // In a real app, you would use a proper toast notification system
  print('Toast [$type]: $message');
}

void setUndoAction(WidgetRef ref, UndoActionType type, Anime anime) {
  ref.read(undoActionProvider.notifier).state = UndoAction(
    type: type,
    animeId: anime.malId,
    animeTitle: anime.title,
    anime: anime,
    timestamp: DateTime.now(),
  );
}

Future<void> executeUndo(WidgetRef ref) async {
  final undoAction = ref.read(undoActionProvider);
  if (undoAction == null || undoAction.isExpired) return;

  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  final service = ref.read(convexServiceProvider);

  try {
    switch (undoAction.type) {
      case UndoActionType.favorite:
        await service.deleteFavorite(userId, undoAction.animeId);
        break;
      case UndoActionType.watchLater:
        await service.removeFromWatchLater(userId, undoAction.animeId);
        break;
    }
    showToast(ref, 'Action undone', type: ToastType.success);
    invalidateUserProviders(ref);
  } catch (e) {
    showToast(ref, 'Failed to undo action', type: ToastType.error);
  } finally {
    ref.read(undoActionProvider.notifier).state = null;
  }
}

void invalidateUserProviders(WidgetRef ref) {
  ref.invalidate(userProfileDataProvider);
  ref.invalidate(animeFavoriteStatusProvider);
  ref.invalidate(animeWatchLaterStatusProvider);
}

Future<void> signOut(WidgetRef ref) async {
  final authService = ref.read(convexAuthServiceProvider);
  await authService.signOut();

  ref.read(currentUserIdProvider.notifier).state = null;
  ref.read(authStateProvider.notifier).state = AuthState.unauthenticated;

  final authBox = Hive.box('auth_box');
  await authBox.delete('user_id');
  await authBox.delete('auth_token');
}
