// Common types for AniSwipe app
// This file defines shared types used across the app

import 'anime.dart';

// ============================================
// Authentication State
// ============================================

enum AuthState {
  initial,
  unauthenticated,
  authenticated,
  authenticating,
  loading,
  error,
}

// ============================================
// Swipe Direction
// ============================================

enum SwipeDirection {
  left,
  right,
}

// ============================================
// Toast Notification Types
// ============================================

enum ToastType {
  success,
  error,
  info,
  warning,
}

class ToastNotification {
  final String message;
  final ToastType type;
  final Duration duration;

  const ToastNotification({
    required this.message,
    required this.type,
    this.duration = const Duration(seconds: 3),
  });
}

// ============================================
// Undo Action Types
// ============================================

enum UndoActionType {
  favorite,
  watchLater,
}

class UndoAction {
  final UndoActionType type;
  final int animeId;
  final String animeTitle;
  final Anime anime;
  final DateTime timestamp;

  const UndoAction({
    required this.type,
    required this.animeId,
    required this.animeTitle,
    required this.anime,
    required this.timestamp,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp).inSeconds > 5;
  }
}

// ============================================
// Loading States
// ============================================

sealed class LoadingState<T> {
  const LoadingState();
}

class InitialState<T> extends LoadingState<T> {
  const InitialState();
}

class Loading<T> extends LoadingState<T> {
  const Loading();
}

class DataState<T> extends LoadingState<T> {
  final T data;
  const DataState(this.data);
}

class ErrorState<T> extends LoadingState<T> {
  final String message;
  const ErrorState(this.message);
}

// ============================================
// Result Wrapper
// ============================================

sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = SuccessResult<T>;
  const factory Result.failure(String error) = FailureResult<T>;
}

class SuccessResult<T> extends Result<T> {
  final T data;
  const SuccessResult(this.data);
}

class FailureResult<T> extends Result<T> {
  final String error;
  const FailureResult(this.error);
}

// ============================================
// Extension Methods
// ============================================

extension LoadingStateExtension<T> on LoadingState<T> {
  bool get isInitial => this is InitialState<T>;
  bool get isLoading => this is Loading<T>;
  bool get hasData => this is DataState<T>;
  bool get isError => this is ErrorState<T>;

  T? get dataOrNull => switch (this) {
    DataState(:final data) => data,
    _ => null,
  };

  String? get errorOrNull => switch (this) {
    ErrorState(:final message) => message,
    _ => null,
  };
}

extension ResultExtension<T> on Result<T> {
  bool get isSuccess => this is SuccessResult<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get dataOrNull => switch (this) {
    SuccessResult(:final data) => data,
    _ => null,
  };

  String? get errorOrNull => switch (this) {
    FailureResult(:final error) => error,
    _ => null,
  };
}
