import 'package:freezed_annotation/freezed_annotation.dart';

part 'anime.freezed.dart';
part 'anime.g.dart';

@freezed
class Anime with _$Anime {
  const factory Anime({
    required int malId,
    required String title,
    @JsonKey(name: 'title_english') String? titleEnglish,
    @JsonKey(name: 'title_japanese') String? titleJapanese,
    required String? imageUrl,
    @JsonKey(name: 'large_image_url') String? largeImageUrl,
    required String synopsis,
    @Default(0.0) double score,
    required int? episodes,
    required String type,
    required String status,
    required String rating,
    @Default(0) int rank,
    @Default(0) int popularity,
    @Default(0) int members,
    @Default(0) int favorites,
    @Default([]) List<String> genres,
    @Default([]) List<String> themes,
    @Default([]) List<String> demographics,
    @JsonKey(name: 'aired') AiredInfo? aired,
    @JsonKey(name: 'studios') List<Studio>? studios,
    @JsonKey(name: 'source') String? source,
    @JsonKey(name: 'duration') String? duration,
    @JsonKey(name: 'season') String? season,
    @JsonKey(name: 'year') int? year,
    @JsonKey(name: 'broadcast') BroadcastInfo? broadcast,
  }) = _Anime;

  factory Anime.fromJson(Map<String, dynamic> json) => _$AnimeFromJson(json);
}

@freezed
class AiredInfo with _$AiredInfo {
  const factory AiredInfo({
    required String from,
    required String to,
    String? string,
    Prop? prop,
  }) = _AiredInfo;

  factory AiredInfo.fromJson(Map<String, dynamic> json) =>
      _$AiredInfoFromJson(json);
}

@freezed
class Prop with _$Prop {
  const factory Prop({
    required FromTo from,
    required FromTo to,
  }) = _Prop;

  factory Prop.fromJson(Map<String, dynamic> json) => _$PropFromJson(json);
}

@freezed
class FromTo with _$FromTo {
  const factory FromTo({
    @Default(1) int day,
    @Default(1) int month,
    @Default(1970) int year,
  }) = _FromTo;

  factory FromTo.fromJson(Map<String, dynamic> json) => _$FromToFromJson(json);
}

@freezed
class Studio with _$Studio {
  const factory Studio({
    @Default(0) int malId,
    required String type,
    required String name,
    String? url,
  }) = _Studio;

  factory Studio.fromJson(Map<String, dynamic> json) => _$StudioFromJson(json);
}

@freezed
class BroadcastInfo with _$BroadcastInfo {
  const factory BroadcastInfo({
    String? day,
    String? time,
    String? timezone,
    String? string,
  }) = _BroadcastInfo;

  factory BroadcastInfo.fromJson(Map<String, dynamic> json) =>
      _$BroadcastInfoFromJson(json);
}

@freezed
class AnimeFilter with _$AnimeFilter {
  const factory AnimeFilter({
    String? query,
    List<String>? genres,
    String? type,
    double? minScore,
    String? status,
    String? rating,
    String? orderBy,
    String? sortDirection,
    int? page,
    int? limit,
  }) = _AnimeFilter;

  factory AnimeFilter.fromJson(Map<String, dynamic> json) =>
      _$AnimeFilterFromJson(json);
}

@freezed
class AnimeSearchResponse with _$AnimeSearchResponse {
  const factory AnimeSearchResponse({
    required List<Anime> data,
    required Pagination pagination,
  }) = _AnimeSearchResponse;

  factory AnimeSearchResponse.fromJson(Map<String, dynamic> json) =>
      _$AnimeSearchResponseFromJson(json);
}

@freezed
class Pagination with _$Pagination {
  const factory Pagination({
    required int lastVisiblePage,
    required bool hasNextPage,
    required int currentPage,
    required Map<String, dynamic> items,
  }) = _Pagination;

  factory Pagination.fromJson(Map<String, dynamic> json) =>
      _$PaginationFromJson(json);
}

// Extension for vector representation used in recommendations
extension AnimeVector on Anime {
  List<double> toVector(List<String> allGenres, List<String> allTypes) {
    final genreVector = allGenres.map((g) => genres.contains(g) ? 1.0 : 0.0).toList();
    final typeVector = allTypes.map((t) => type == t ? 1.0 : 0.0).toList();
    final scoreVector = [score / 10.0]; // Normalize score to 0-1

    return [...genreVector, ...typeVector, ...scoreVector];
  }
}
