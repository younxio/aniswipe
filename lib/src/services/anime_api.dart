import 'package:dio/dio.dart';
import '../models/anime.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AnimeApi {
  final Dio _dio;
  final Box _discoverCache;
  final Box _animeCache;

  static const String _baseUrl = 'https://api.jikan.moe/v4';

  AnimeApi(this._dio)
      : _discoverCache = Hive.box('discover_cache'),
        _animeCache = Hive.box('anime_cache');

  // ============================================
  // DISCOVER OPERATIONS
  // ============================================

  Future<List<Anime>> fetchDiscover({
    int limit = 20,
    AnimeFilter? filter,
  }) async {
    try {
      // Check cache first
      final cacheKey = _buildCacheKey('discover', filter);
      final cached = _discoverCache.get(cacheKey);
      if (cached != null) {
        final timestamp = cached['timestamp'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        // Cache is valid for 1 hour
        if (age < 3600000) {
          return (cached['data'] as List)
              .map((e) => Anime.fromJson(e))
              .toList();
        }
      }

      // Fetch from API
      final response = await _dio.get(
        '$_baseUrl/anime',
        queryParameters: _buildQueryParams(limit, filter),
      );

      final animeSearchResponse = AnimeSearchResponse.fromJson(response.data);
      final animeList = animeSearchResponse.data;

      // Cache the result
      await _discoverCache.put(cacheKey, {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': animeList.map((e) => e.toJson()).toList(),
      });

      return animeList;
    } on DioException catch (e) {
      print('Error fetching discover: $e');
      // Return cached data if available
      final cacheKey = _buildCacheKey('discover', filter);
      final cached = _discoverCache.get(cacheKey);
      if (cached != null) {
        return (cached['data'] as List)
            .map((e) => Anime.fromJson(e))
            .toList();
      }
      rethrow;
    }
  }

  Future<Anime> fetchById(int animeId) async {
    try {
      // Check cache first
      final cached = _animeCache.get(animeId);
      if (cached != null) {
        final timestamp = cached['timestamp'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        // Cache is valid for 24 hours
        if (age < 86400000) {
          return Anime.fromJson(cached['data']);
        }
      }

      // Fetch from API
      final response = await _dio.get('$_baseUrl/anime/$animeId/full');
      final anime = Anime.fromJson(response.data['data']);

      // Cache the result
      await _animeCache.put(animeId, {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': anime.toJson(),
      });

      return anime;
    } on DioException catch (e) {
      print('Error fetching anime by id: $e');
      // Return cached data if available
      final cached = _animeCache.get(animeId);
      if (cached != null) {
        return Anime.fromJson(cached['data']);
      }
      rethrow;
    }
  }

  Future<List<Anime>> searchAnime(AnimeFilter filter) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/anime',
        queryParameters: _buildQueryParams(25, filter),
      );

      final animeSearchResponse = AnimeSearchResponse.fromJson(response.data);
      return animeSearchResponse.data;
    } on DioException catch (e) {
      print('Error searching anime: $e');
      rethrow;
    }
  }

  Future<List<Anime>> fetchTopAnime({
    String type = 'tv',
    int limit = 20,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/top/anime',
        queryParameters: {
          'type': type,
          'limit': limit,
          'page': page,
        },
      );

      final animeSearchResponse = AnimeSearchResponse.fromJson(response.data);
      return animeSearchResponse.data;
    } on DioException catch (e) {
      print('Error fetching top anime: $e');
      rethrow;
    }
  }

  Future<List<Anime>> fetchSeasonalAnime({
    int? year,
    String? season,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/seasons/$year/$season',
        queryParameters: {
          'limit': limit,
        },
      );

      final animeSearchResponse = AnimeSearchResponse.fromJson(response.data);
      return animeSearchResponse.data;
    } on DioException catch (e) {
      print('Error fetching seasonal anime: $e');
      rethrow;
    }
  }

  Future<List<Anime>> fetchRecommendations(int animeId) async {
    try {
      final response = await _dio.get('$_baseUrl/anime/$animeId/recommendations');

      final recommendations = (response.data['data'] as List)
          .map((e) => Anime.fromJson(e['entry']))
          .toList();

      return recommendations;
    } on DioException catch (e) {
      print('Error fetching recommendations: $e');
      return [];
    }
  }

  // ============================================
  // HELPER METHODS
  // ============================================

  Map<String, dynamic> _buildQueryParams(int limit, AnimeFilter? filter) {
    final params = <String, dynamic>{
      'limit': limit,
      'sfw': true,
    };

    if (filter != null) {
      if (filter.query != null && filter.query!.isNotEmpty) {
        params['q'] = filter.query;
      }
      if (filter.genres != null && filter.genres!.isNotEmpty) {
        params['genres'] = filter.genres!.join(',');
      }
      if (filter.type != null) {
        params['type'] = filter.type;
      }
      if (filter.minScore != null) {
        params['min_score'] = filter.minScore;
      }
      if (filter.status != null) {
        params['status'] = filter.status;
      }
      if (filter.rating != null) {
        params['rating'] = filter.rating;
      }
      if (filter.orderBy != null) {
        params['order_by'] = filter.orderBy;
      }
      if (filter.sortDirection != null) {
        params['sort'] = filter.sortDirection;
      }
      if (filter.page != null) {
        params['page'] = filter.page;
      }
    }

    return params;
  }

  String _buildCacheKey(String prefix, AnimeFilter? filter) {
    if (filter == null) return prefix;
    final parts = [prefix];
    if (filter.query != null) parts.add('q:${filter.query}');
    if (filter.genres != null) parts.add('g:${filter.genres!.join(',')}');
    if (filter.type != null) parts.add('t:${filter.type}');
    if (filter.minScore != null) parts.add('s:${filter.minScore}');
    return parts.join('|');
  }

  // ============================================
  // CACHE MANAGEMENT
  // ============================================

  Future<void> clearDiscoverCache() async {
    await _discoverCache.clear();
  }

  Future<void> clearAnimeCache() async {
    await _animeCache.clear();
  }

  Future<void> clearAllCache() async {
    await clearDiscoverCache();
    await clearAnimeCache();
  }

  // ============================================
  // GENRES AND TYPES
  // ============================================

  static const List<String> allGenres = [
    'Action',
    'Adventure',
    'Avant Garde',
    'Award Winning',
    'Boys Love',
    'Comedy',
    'Drama',
    'Fantasy',
    'Girls Love',
    'Gourmet',
    'Horror',
    'Mystery',
    'Romance',
    'Sci-Fi',
    'Slice of Life',
    'Sports',
    'Supernatural',
    'Suspense',
  ];

  static const List<String> allTypes = [
    'TV',
    'Movie',
    'OVA',
    'Special',
    'ONA',
    'Music',
  ];

  static const List<String> allStatuses = [
    'airing',
    'complete',
    'upcoming',
  ];

  static const List<String> allRatings = [
    'g',
    'pg',
    'pg-13',
    'r17',
    'r',
    'rx',
  ];

  static const List<String> orderByOptions = [
    'score',
    'popularity',
    'rank',
    'start_date',
    'end_date',
    'episodes',
  ];
}
