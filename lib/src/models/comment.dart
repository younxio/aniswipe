import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';
part 'comment.g.dart';

@freezed
class Comment with _$Comment {
  const factory Comment({
    required String id,
    required int animeId,
    required String userId,
    required String userName,
    String? userAvatar,
    required String content,
    required DateTime createdAt,
    DateTime? updatedAt,
  }) = _Comment;

  factory Comment.fromJson(Map<String, dynamic> json) =>
      _$CommentFromJson(json);
}

@freezed
class CommentCreateRequest with _$CommentCreateRequest {
  const factory CommentCreateRequest({
    required int animeId,
    required String userId,
    required String content,
  }) = _CommentCreateRequest;

  factory CommentCreateRequest.fromJson(Map<String, dynamic> json) =>
      _$CommentCreateRequestFromJson(json);
}

@freezed
class CommentUpdateRequest with _$CommentUpdateRequest {
  const factory CommentUpdateRequest({
    required String content,
  }) = _CommentUpdateRequest;

  factory CommentUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$CommentUpdateRequestFromJson(json);
}
