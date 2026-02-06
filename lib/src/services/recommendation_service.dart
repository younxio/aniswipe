import 'dart:math';
import '../models/anime.dart';
import '../models/profile.dart';
import 'anime_api.dart';

class RecommendationService {
  final AnimeApi _animeApi;

  RecommendationService(this._animeApi);

  // ============================================
  // RECOMMENDATION ALGORITHM
  // ============================================

  /// Get personalized recommendations based on user's favorites
  Future<List<Anime>> getRecommendations(
    List<Favorite> favorites, {
    int topN = 10,
    List<Anime>? candidateAnime,
  }) async {
    if (favorites.isEmpty) {
      // Return top anime if no favorites
      return await _animeApi.fetchTopAnime(limit: topN);
    }

    // Build user preference vector from favorites
    final userVector = _buildUserVector(favorites);

    // Get candidate anime (either provided or fetch top anime)
    final candidates = candidateAnime ?? await _animeApi.fetchTopAnime(limit: 100);

    // Calculate similarity scores and rank
    final scoredAnime = candidates.map((anime) {
      final animeVector = anime.toVector(
        AnimeApi.allGenres,
        AnimeApi.allTypes,
      );
      final similarity = _cosineSimilarity(userVector, animeVector);
      return MapEntry(anime, similarity);
    }).toList();

    // Sort by similarity (descending)
    scoredAnime.sort((a, b) => b.value.compareTo(a.value));

    // Filter out already favorited anime
    final favoriteIds = favorites.map((f) => f.animeId).toSet();
    final recommendations = scoredAnime
        .where((entry) => !favoriteIds.contains(entry.key.malId))
        .take(topN)
        .map((entry) => entry.key)
        .toList();

    return recommendations;
  }

  /// Build user preference vector by averaging favorite anime vectors
  List<double> _buildUserVector(List<Favorite> favorites) {
    final vectors = favorites.map((favorite) {
      // Create a minimal anime object for vector calculation
      final anime = Anime(
        malId: favorite.animeId,
        title: favorite.animeTitle,
        titleEnglish: null,
        titleJapanese: null,
        imageUrl: favorite.animePoster,
        largeImageUrl: favorite.animePoster,
        synopsis: '',
        score: favorite.animeScore ?? 0.0,
        episodes: favorite.animeEpisodes,
        type: favorite.animeType ?? 'Unknown',
        status: 'Unknown',
        rating: 'Unknown',
        rank: 0,
        popularity: 0,
        members: 0,
        favorites: 0,
        genres: [], // We don't have genre info in favorites
        themes: [],
        demographics: [],
        aired: null,
        studios: [],
        source: null,
        duration: null,
        season: null,
        year: null,
        broadcast: null,
      );
      return anime.toVector(AnimeApi.allGenres, AnimeApi.allTypes);
    }).toList();

    if (vectors.isEmpty) {
      return List.filled(
        AnimeApi.allGenres.length + AnimeApi.allTypes.length + 1,
        0.0,
      );
    }

    // Calculate average vector
    final dimensions = vectors.first.length;
    final averageVector = List<double>.filled(dimensions, 0.0);

    for (final vector in vectors) {
      for (int i = 0; i < dimensions; i++) {
        averageVector[i] += vector[i];
      }
    }

    for (int i = 0; i < dimensions; i++) {
      averageVector[i] /= vectors.length;
    }

    return averageVector;
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> vectorA, List<double> vectorB) {
    if (vectorA.length != vectorB.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < vectorA.length; i++) {
      dotProduct += vectorA[i] * vectorB[i];
      normA += vectorA[i] * vectorA[i];
      normB += vectorB[i] * vectorB[i];
    }

    if (normA == 0 || normB == 0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  // ============================================
  // CONTENT-BASED FILTERING
  // ============================================

  /// Get similar anime based on a reference anime
  Future<List<Anime>> getSimilarAnime(
    Anime referenceAnime, {
    int topN = 10,
    List<Anime>? candidateAnime,
  }) async {
    final referenceVector = referenceAnime.toVector(
      AnimeApi.allGenres,
      AnimeApi.allTypes,
    );

    // Get candidate anime
    final candidates = candidateAnime ?? await _animeApi.fetchTopAnime(limit: 100);

    // Calculate similarity scores
    final scoredAnime = candidates.map((anime) {
      if (anime.malId == referenceAnime.malId) {
        return MapEntry(anime, -1.0); // Exclude the reference anime
      }
      final animeVector = anime.toVector(
        AnimeApi.allGenres,
        AnimeApi.allTypes,
      );
      final similarity = _cosineSimilarity(referenceVector, animeVector);
      return MapEntry(anime, similarity);
    }).toList();

    // Sort by similarity (descending)
    scoredAnime.sort((a, b) => b.value.compareTo(a.value));

    // Return top N
    return scoredAnime
        .take(topN)
        .map((entry) => entry.key)
        .toList();
  }

  // ============================================
  // DIVERSITY-AWARE RECOMMENDATIONS
  // ============================================

  /// Get diverse recommendations to avoid genre clustering
  Future<List<Anime>> getDiverseRecommendations(
    List<Favorite> favorites, {
    int topN = 10,
    double diversityThreshold = 0.7,
  }) async {
    final recommendations = await getRecommendations(favorites, topN: topN * 2);

    if (recommendations.isEmpty) return [];

    final diverseRecommendations = <Anime>[];
    final selectedGenres = <String>{};

    for (final anime in recommendations) {
      if (diverseRecommendations.length >= topN) break;

      // Check if anime adds diversity
      final newGenres = anime.genres.where((g) => !selectedGenres.contains(g)).toList();
      
      if (newGenres.isNotEmpty || diverseRecommendations.isEmpty) {
        diverseRecommendations.add(anime);
        selectedGenres.addAll(anime.genres);
      }
    }

    return diverseRecommendations;
  }

  // ============================================
  // TRENDING AND POPULAR
  // ============================================

  /// Get trending anime (high popularity + recent)
  Future<List<Anime>> getTrendingAnime({int limit = 10}) async {
    try {
      final response = await _animeApi.fetchTopAnime(
        type: 'tv',
        limit: limit,
      );

      // Sort by popularity (higher is better)
      response.sort((a, b) => b.popularity.compareTo(a.popularity));

      return response.take(limit).toList();
    } catch (e) {
      print('Error fetching trending anime: $e');
      return [];
    }
  }

  /// Get highly rated anime
  Future<List<Anime>> getHighlyRatedAnime({
    int limit = 10,
    double minScore = 8.0,
  }) async {
    try {
      final response = await _animeApi.fetchTopAnime(
        type: 'tv',
        limit: 50,
      );

      // Filter by score and sort
      final highlyRated = response
          .where((anime) => anime.score >= minScore)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      return highlyRated.take(limit).toList();
    } catch (e) {
      print('Error fetching highly rated anime: $e');
      return [];
    }
  }

  // ============================================
  // SEASONAL RECOMMENDATIONS
  // ============================================

  /// Get current season anime
  Future<List<Anime>> getCurrentSeasonAnime({int limit = 10}) async {
    try {
      final now = DateTime.now();
      final year = now.year;
      final season = _getCurrentSeason(now.month);

      return await _animeApi.fetchSeasonalAnime(
        year: year,
        season: season,
        limit: limit,
      );
    } catch (e) {
      print('Error fetching current season anime: $e');
      return [];
    }
  }

  String _getCurrentSeason(int month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter';
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Get explanation for why an anime was recommended
  String getRecommendationExplanation(Anime anime, List<Favorite> favorites) {
    if (favorites.isEmpty) {
      return 'Popular anime with high ratings';
    }

    final matchingGenres = <String>[];
    for (final favorite in favorites) {
      // We don't have genre info in favorites, so we'll use a generic explanation
      matchingGenres.add('similar to your favorites');
    }

    if (matchingGenres.isEmpty) {
      return 'Highly rated anime';
    }

    return 'Matches your interests: ${matchingGenres.join(', ')}';
  }

  /// Calculate confidence score for a recommendation
  double calculateConfidenceScore(
    Anime anime,
    List<Favorite> favorites,
    double similarityScore,
  ) {
    if (favorites.isEmpty) {
      return anime.score / 10.0; // Base confidence on score
    }

    // Weight similarity and score
    final similarityWeight = 0.7;
    final scoreWeight = 0.3;

    return (similarityScore * similarityWeight) + 
           ((anime.score / 10.0) * scoreWeight);
  }
}
