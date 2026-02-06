// Mock Convex Service for testing purposes
// This simulates the Convex backend without requiring the actual Convex Flutter SDK

class MockConvexClient {
  final Map<String, dynamic> _data = {};
  
  Future<dynamic> query(String functionName, {Map<String, dynamic>? args}) async {
    // Mock implementation - simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    switch (functionName) {
      case 'users:get':
        return {'user': null};
      case 'anime:fetchDiscover':
        return {'anime': []};
      default:
        return null;
    }
  }
  
  Future<dynamic> mutation(String functionName, {Map<String, dynamic>? args}) async {
    // Mock implementation - simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));
    
    switch (functionName) {
      case 'auth:signIn':
        return {'success': true, 'userId': 'mock_user_id'};
      case 'auth:signUp':
        return {'success': true, 'userId': 'mock_user_id'};
      default:
        return {'success': false};
    }
  }
}

class MockConvexService {
  final MockConvexClient _client;
  
  MockConvexService(this._client);
  
  Future<List<dynamic>> getDiscoverAnime() async {
    final result = await _client.query('anime:fetchDiscover');
    return result['anime'] ?? [];
  }
  
  Future<bool> saveFavorite(String userId, Anime anime) async {
    await _client.mutation('favorites:save', args: {
      'userId': userId,
      'animeId': anime.malId,
    });
    return true;
  }
  
  Future<bool> deleteFavorite(String userId, int animeId) async {
    await _client.mutation('favorites:delete', args: {
      'userId': userId,
      'animeId': animeId,
    });
    return true;
  }
  
  Future<bool> updateWatchLaterStatus(String userId, int animeId, bool value) async {
    await _client.mutation('watchLater:update', args: {
      'userId': userId,
      'animeId': animeId,
      'value': value,
    });
    return true;
  }
  
  Future<bool> removeFromWatchLater(String userId, int animeId) async {
    await _client.mutation('watchLater:remove', args: {
      'userId': userId,
      'animeId': animeId,
    });
    return true;
  }
  
  Future<bool> updateProfile(String userId, Map<String, dynamic> data) async {
    await _client.mutation('profile:update', args: {
      'userId': userId,
      'data': data,
    });
    return true;
  }
}

class MockConvexAuthService {
  final MockConvexClient _client;
  
  MockConvexAuthService(this._client);
  
  Future<AuthResult> signIn({required String email, required String password}) async {
    final result = await _client.mutation('auth:signIn', args: {
      'email': email,
      'password': password,
    });
    
    return AuthResult(
      success: result['success'] ?? false,
      userId: result['userId'],
      token: result['token'],
    );
  }
  
  Future<AuthResult> signUp({required String email, required String password}) async {
    final result = await _client.mutation('auth:signUp', args: {
      'email': email,
      'password': password,
    });
    
    return AuthResult(
      success: result['success'] ?? false,
      userId: result['userId'],
      token: result['token'],
    );
  }
  
  Future<void> signOut() async {
    await _client.mutation('auth:signOut');
  }
}

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
}
