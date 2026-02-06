import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/types.dart';

/// AuthResult - Result of authentication operation
class AuthResult {
  final bool success;
  final String? userId;
  final String? token;
  final String? error;
  final bool requiresEmailVerification;

  const AuthResult({
    required this.success,
    this.userId,
    this.token,
    this.error,
    this.requiresEmailVerification = false,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      success: json['success'] as bool? ?? false,
      userId: json['userId'] as String?,
      token: json['token'] as String?,
      error: json['error'] as String?,
      requiresEmailVerification: json['requiresEmailVerification'] as bool? ?? false,
    );
  }
}

/// ConvexAuthService - Handles authentication using Clerk via Convex
///
/// This service provides:
/// - Sign up with email/password
/// - Sign in with email/password
/// - Sign out
/// - Session management
/// - Token refresh
class ConvexAuthService {
  final Dio _dio;
  final Box _authBox;
  final String _baseUrl;
  
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';

  ConvexAuthService(Dio dio, {String? baseUrl})
      : _dio = dio,
        _authBox = Hive.box('auth_box'),
        _baseUrl = baseUrl ?? '';

  // ============================================
  // AUTHENTICATION OPERATIONS
  // ============================================

  /// Sign up with email and password
  /// 
  /// This creates a new user in Clerk and Convex
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/auth:signUp',
        data: {
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
      
      final result = AuthResult.fromJson(response.data);
      if (result.success) {
        await _saveAuthResult(result);
      }
      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/auth:signIn',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      final result = AuthResult.fromJson(response.data);
      if (result.success) {
        await _saveAuthResult(result);
      }
      return result;
    } catch (e) {
      return AuthResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      await _dio.post('$_baseUrl/auth:signOut', data: {});
    } catch (e) {
      print('Error signing out: $e');
    } finally {
      await _clearAuthData();
    }
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    final token = _authBox.get(_authTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _authBox.get(_userIdKey);
  }

  /// Get current auth token
  String? getAuthToken() {
    return _authBox.get(_authTokenKey);
  }

  /// Refresh the authentication token
  Future<bool> refreshToken() async {
    try {
      final response = await _dio.post('$_baseUrl/auth:refreshToken', data: {});
      if (response.data != null && response.data['token'] != null) {
        await _authBox.put(_authTokenKey, response.data['token']);
        return true;
      }
      return false;
    } catch (e) {
      print('Error refreshing token: $e');
      return false;
    }
  }

  /// Request password reset email
  Future<bool> requestPasswordReset(String email) async {
    try {
      await _dio.post('$_baseUrl/auth:requestPasswordReset', data: {'email': email});
      return true;
    } catch (e) {
      print('Error requesting password reset: $e');
      return false;
    }
  }

  /// Reset password with new password
  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/auth:resetPassword',
        data: {
          'token': token,
          'newPassword': newPassword,
        },
      );
      return response.data as bool? ?? false;
    } catch (e) {
      print('Error resetting password: $e');
      return false;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  Future<void> _saveAuthResult(AuthResult result) async {
    if (result.token != null) {
      await _authBox.put(_authTokenKey, result.token);
    }
    if (result.userId != null) {
      await _authBox.put(_userIdKey, result.userId);
    }
  }

  Future<void> _clearAuthData() async {
    await _authBox.delete(_authTokenKey);
    await _authBox.delete(_userIdKey);
  }
}
