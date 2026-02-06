import 'package:dio/dio.dart';
import '../models/profile.dart';
import '../models/anime.dart';
import '../models/comment.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';

/// ConvexService - Handles all database operations using Convex REST API
///
/// This service replaces Supabase and provides:
/// - User profile management (profiles table)
/// - Favorites management (favorites table)
/// - Watch later management (watch_later table)
/// - Comments management (comments table)
/// - Offline queue support with automatic sync
class ConvexService {
  final Dio _dio;
  final Box _offlineQueue;
  final String _baseUrl;

  ConvexService(Dio dio, {String? baseUrl})
      : _dio = dio,
        _offlineQueue = Hive.box('offline_queue'),
        _baseUrl = baseUrl ?? '';

  // ============================================
  // HELPER METHODS
  // ============================================

  Future<dynamic> _query(String queryName, Map<String, dynamic> args) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/$queryName',
        data: args,
      );
      return response.data;
    } catch (e) {
      print('Error in query $queryName: $e');
      rethrow;
    }
  }

  Future<dynamic> _mutation(String mutationName, Map<String, dynamic> args) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/$mutationName',
        data: args,
      );
      return response.data;
    } catch (e) {
      print('Error in mutation $mutationName: $e');
      rethrow;
    }
  }

  // ============================================
  // PROFILE OPERATIONS
  // ============================================

  Future<Profile?> getProfile(String userId) async {
    try {
      final response = await _query('getProfile', {'userId': userId});
      if (response == null || response.isEmpty) return null;
      return Profile.fromJson(response);
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  Future<Profile?> createProfile(String userId, {String? displayName}) async {
    try {
      final response = await _mutation('createProfile', {
        'userId': userId,
        'displayName': displayName,
      });
      return Profile.fromJson(response);
    } catch (e) {
      print('Error creating profile: $e');
      return null;
    }
  }

  Future<Profile?> updateProfile(
    String userId,
    ProfileUpdateRequest request,
  ) async {
    try {
      final response = await _mutation('updateProfile', {
        'userId': userId,
        'displayName': request.displayName,
        'avatarUrl': request.avatarUrl,
      });
      return Profile.fromJson(response);
    } catch (e) {
      print('Error updating profile: $e');
      return null;
    }
  }

  // ============================================
  // FAVORITES OPERATIONS
  // ============================================

  Future<List<Favorite>> getFavorites(String userId) async {
    try {
      final response = await _query('getFavorites', {'userId': userId});
      if (response == null) return [];
      return (response as List).map((e) => Favorite.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }

  Future<Favorite?> saveFavorite(String userId, Anime anime) async {
    try {
      final response = await _mutation('saveFavorite', {
        'userId': userId,
        'animeId': anime.malId,
        'animeTitle': anime.title,
        'animePoster': anime.imageUrl,
        'animeScore': anime.score,
        'animeType': anime.type,
        'animeEpisodes': anime.episodes,
      });
      return Favorite.fromJson(response);
    } catch (e) {
      print('Error saving favorite: $e');
      return null;
    }
  }

  Future<bool> deleteFavorite(String userId, int animeId) async {
    try {
      await _mutation('deleteFavorite', {
        'userId': userId,
        'animeId': animeId,
      });
      return true;
    } catch (e) {
      print('Error deleting favorite: $e');
      return false;
    }
  }

  Future<bool> isAnimeFavorited(String userId, int animeId) async {
    try {
      final response = await _query('isFavorite', {
        'userId': userId,
        'animeId': animeId,
      });
      return response as bool? ?? false;
    } catch (e) {
      print('Error checking favorite status: $e');
      return false;
    }
  }

  // ============================================
  // WATCH LATER OPERATIONS
  // ============================================

  Future<List<WatchLater>> getWatchLater(String userId) async {
    try {
      final response = await _query('getWatchLater', {'userId': userId});
      if (response == null) return [];
      return (response as List).map((e) => WatchLater.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching watch later: $e');
      return [];
    }
  }

  Future<WatchLater?> addToWatchLater(String userId, Anime anime) async {
    try {
      final response = await _mutation('addToWatchLater', {
        'userId': userId,
        'animeId': anime.malId,
        'animeTitle': anime.title,
        'animePoster': anime.imageUrl,
      });
      return WatchLater.fromJson(response);
    } catch (e) {
      print('Error adding to watch later: $e');
      return null;
    }
  }

  Future<bool> removeFromWatchLater(String userId, int animeId) async {
    try {
      await _mutation('removeFromWatchLater', {
        'userId': userId,
        'animeId': animeId,
      });
      return true;
    } catch (e) {
      print('Error removing from watch later: $e');
      return false;
    }
  }

  Future<bool> isAnimeInWatchLater(String userId, int animeId) async {
    try {
      final response = await _query('isInWatchLater', {
        'userId': userId,
        'animeId': animeId,
      });
      return response as bool? ?? false;
    } catch (e) {
      print('Error checking watch later status: $e');
      return false;
    }
  }

  Future<bool> updateWatchLaterStatus(
    String userId,
    int animeId,
    String status,
  ) async {
    try {
      await _mutation('updateWatchLaterStatus', {
        'userId': userId,
        'animeId': animeId,
        'status': status,
      });
      return true;
    } catch (e) {
      print('Error updating watch later status: $e');
      return false;
    }
  }

  // ============================================
  // COMMENTS OPERATIONS
  // ============================================

  Future<List<Comment>> getComments(int animeId) async {
    try {
      final response = await _query('getComments', {'animeId': animeId});
      if (response == null) return [];
      return (response as List).map((e) => Comment.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  Future<Comment?> addComment(CommentCreateRequest request) async {
    try {
      final response = await _mutation('addComment', {
        'animeId': request.animeId,
        'userId': request.userId,
        'content': request.content,
      });
      return Comment.fromJson(response);
    } catch (e) {
      print('Error adding comment: $e');
      return null;
    }
  }

  Future<bool> updateComment(String commentId, CommentUpdateRequest request) async {
    try {
      await _mutation('updateComment', {
        'commentId': commentId,
        'content': request.content,
      });
      return true;
    } catch (e) {
      print('Error updating comment: $e');
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _mutation('deleteComment', {'commentId': commentId});
      return true;
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }

  // ============================================
  // OFFLINE QUEUE OPERATIONS
  // ============================================

  Future<void> queueOfflineOperation(Map<String, dynamic> operation) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _offlineQueue.put('op_$timestamp', operation);
  }

  Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    final operations = <Map<String, dynamic>>[];
    for (final key in _offlineQueue.keys) {
      if (key.toString().startsWith('op_')) {
        final operation = _offlineQueue.get(key) as Map<String, dynamic>;
        operations.add(operation);
      }
    }
    return operations;
  }

  Future<void> clearOfflineQueue() async {
    for (final key in _offlineQueue.keys) {
      if (key.toString().startsWith('op_')) {
        await _offlineQueue.delete(key);
      }
    }
  }

  Future<void> syncOfflineQueue(String userId) async {
    final operations = await getOfflineQueue();
    for (final operation in operations) {
      try {
        final type = operation['type'] as String;
        switch (type) {
          case 'save_favorite':
            final anime = Anime.fromJson(operation['anime']);
            await saveFavorite(userId, anime);
            break;
          case 'add_comment':
            final request = CommentCreateRequest.fromJson(operation['request']);
            await addComment(request);
            break;
          case 'add_to_watch_later':
            final anime = Anime.fromJson(operation['anime']);
            await addToWatchLater(userId, anime);
            break;
        }
      } catch (e) {
        print('Error syncing operation: $e');
      }
    }
    await clearOfflineQueue();
  }

  // ============================================
  // USER PROFILE DATA
  // ============================================

  Future<UserProfileData?> getUserProfileData(String userId) async {
    try {
      final profile = await getProfile(userId);
      if (profile == null) return null;

      final favorites = await getFavorites(userId);
      final watchLater = await getWatchLater(userId);

      return UserProfileData(
        profile: profile,
        favorites: favorites,
        watchLater: watchLater,
      );
    } catch (e) {
      print('Error fetching user profile data: $e');
      return null;
    }
  }
}

// ============================================
// QUERY NAMES (defined in Convex dashboard)
// ============================================

const String getProfileQuery = 'getProfile';
const String createProfileMutation = 'createProfile';
const String updateProfileMutation = 'updateProfile';
const String getFavoritesQuery = 'getFavorites';
const String saveFavoriteMutation = 'saveFavorite';
const String deleteFavoriteMutation = 'deleteFavorite';
const String isFavoriteQuery = 'isFavorite';
const String getWatchLaterQuery = 'getWatchLater';
const String addToWatchLaterMutation = 'addToWatchLater';
const String removeFromWatchLaterMutation = 'removeFromWatchLater';
const String isInWatchLaterQuery = 'isInWatchLater';
const String updateWatchLaterStatusMutation = 'updateWatchLaterStatus';
const String getCommentsQuery = 'getComments';
const String addCommentMutation = 'addComment';
const String updateCommentMutation = 'updateComment';
const String deleteCommentMutation = 'deleteComment';
