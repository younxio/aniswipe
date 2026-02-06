import 'package:freezed_annotation/freezed_annotation.dart';
import 'anime.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String clerkId,
    String? displayName,
    String? avatarUrl,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

@freezed
class Favorite with _$Favorite {
  const factory Favorite({
    required String id,
    required String userId,
    required int animeId,
    required String animeTitle,
    String? animePoster,
    double? animeScore,
    String? animeType,
    int? animeEpisodes,
    required DateTime createdAt,
  }) = _Favorite;

  factory Favorite.fromJson(Map<String, dynamic> json) =>
      _$FavoriteFromJson(json);
}

@freezed
class WatchLater with _$WatchLater {
  const factory WatchLater({
    required String id,
    required String userId,
    required int animeId,
    required String animeTitle,
    String? animePoster,
    @Default('planned') String status,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _WatchLater;

  factory WatchLater.fromJson(Map<String, dynamic> json) =>
      _$WatchLaterFromJson(json);
}

@freezed
class ProfileUpdateRequest with _$ProfileUpdateRequest {
  const factory ProfileUpdateRequest({
    String? displayName,
    String? avatarUrl,
  }) = _ProfileUpdateRequest;

  factory ProfileUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$ProfileUpdateRequestFromJson(json);
}

@freezed
class UserProfileData with _$UserProfileData {
  const factory UserProfileData({
    required Profile profile,
    required List<Favorite> favorites,
    required List<WatchLater> watchLater,
  }) = _UserProfileData;

  factory UserProfileData.fromJson(Map<String, dynamic> json) =>
      _$UserProfileDataFromJson(json);
}

// Extension to convert Favorite to Anime
extension FavoriteToAnime on Favorite {
  Anime toAnime() {
    return Anime(
      malId: animeId,
      title: animeTitle,
      titleEnglish: null,
      titleJapanese: null,
      imageUrl: animePoster,
      largeImageUrl: animePoster,
      synopsis: '',
      score: animeScore ?? 0.0,
      episodes: animeEpisodes,
      type: animeType ?? 'Unknown',
      status: 'Unknown',
      rating: 'Unknown',
      rank: 0,
      popularity: 0,
      members: 0,
      favorites: 0,
      genres: [],
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
  }
}

// Extension to convert WatchLater to Anime
extension WatchLaterToAnime on WatchLater {
  Anime toAnime() {
    return Anime(
      malId: animeId,
      title: animeTitle,
      titleEnglish: null,
      titleJapanese: null,
      imageUrl: animePoster,
      largeImageUrl: animePoster,
      synopsis: '',
      score: 0.0,
      episodes: null,
      type: 'Unknown',
      status: 'Unknown',
      rating: 'Unknown',
      rank: 0,
      popularity: 0,
      members: 0,
      favorites: 0,
      genres: [],
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
  }
}
