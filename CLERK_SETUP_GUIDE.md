# Clerk Authentication Setup Guide for AniSwipe Flutter Web

## Executive Summary

This guide provides the definitive configuration for integrating Clerk authentication into the AniSwipe Flutter Web application. The correct selection is **JavaScript** (not React, Next.js, Expo, or Mobile Native) because Flutter Web compiles to JavaScript and runs in the browser runtime, making Dart transparent to Clerk's JavaScript SDK.

---

## Why Flutter Web Requires JavaScript Selection

### Technical Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter Web Application                      │
│  (Dart → JavaScript Compilation)                          │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Compiles to
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Browser Runtime (JavaScript)                     │
│  - Chrome, Firefox, Safari, Edge                          │
│  - V8, SpiderMonkey, JavaScriptCore engines               │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Requires
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Clerk JavaScript SDK                          │
│  - Runs natively in browser                              │
│  - Direct DOM manipulation                                   │
│  - JWT/Session management in JS                            │
└─────────────────────────────────────────────────────────────────┘
```

### Why Other Frameworks Are Incorrect

| Framework | Why Incorrect for Flutter Web |
|-----------|---------------------------|
| **React** | Flutter Web doesn't use React's virtual DOM or component lifecycle |
| **Next.js** | Next.js is a React framework with SSR - incompatible with Flutter's compilation model |
| **Expo** | Expo manages React Native apps - Flutter has its own build system |
| **Mobile Native** | Flutter Web runs in browser, not as native mobile app |

---

## Clerk Dashboard Configuration

### Step 1: Create Clerk Application

1. Go to [Clerk Dashboard](https://dashboard.clerk.com)
2. Click **"Create Application"**
3. Fill in application details:
   - **Application Name**: AniSwipe
   - **Description**: Anime discovery app with swipe UX
   - **Application Type**: Select **"JavaScript"**
   - **Framework Preset**: Select **"None"** or **"Vanilla Web"**
   - **Allowed Origins**: Add your development and production URLs
     - Development: `http://localhost:3000`
     - Production: `https://your-domain.com`

### Step 2: Configure Application Settings

In your Clerk application settings:

1. **General Settings**:
   - Enable **"Email/Password"** authentication
   - Enable **"Social Login"** (Google, GitHub, etc.) if desired
   - Set **"Session Duration"** (recommended: 7 days)

2. **JWT Settings**:
   - **JWT Template**: Configure to include `user_id` claim
   - **Token Expiration**: Match session duration
   - **Algorithm**: RS256 (recommended)

3. **CORS Settings**:
   - Add your Flutter Web URL to allowed origins
   - Enable credentials if needed

### Step 3: Get API Keys

After creating the application, you'll receive:

1. **Publishable Key** (Frontend use)
   - Format: `pk_test_xxxxxxxxxxxxxxxxxxxxx`
   - Use in: Flutter Web client
   - Safe to expose: Yes

2. **Secret Key** (Backend use only)
   - Format: `sk_test_xxxxxxxxxxxxxxxxxxxxx`
   - Use in: Supabase Edge Functions (if any)
   - Never expose: No

---

## Flutter Web Implementation

### Step 1: Update pubspec.yaml

Add Clerk Flutter SDK dependency:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Clerk Authentication
  clerk_flutter: ^1.0.0
  
  # Existing dependencies...
  flutter_riverpod: ^2.4.9
  supabase_flutter: ^2.3.4
  # ... other dependencies
```

### Step 2: Create Clerk Service

Create `lib/src/services/clerk_service.dart`:

```dart
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ClerkService {
  final ClerkClient _client;

  ClerkService(this._client);

  // Get current user ID
  String? get currentUserId {
    return _client.user?.id;
  }

  // Get current user
  User? get currentUser {
    return _client.user;
  }

  // Check if user is signed in
  bool get isSignedIn {
    return _client.user != null;
  }

  // Sign out
  Future<void> signOut() async {
    await _client.signOut();
  }

  // Get JWT token for backend requests
  String? get jwtToken {
    return _client.session?.getToken();
  }
}

// Clerk Provider
final clerkClientProvider = Provider<ClerkClient>((ref) {
  return ClerkClient(
    publishableKey: const String.fromEnvironment('CLERK_PUBLISHABLE_KEY'),
  );
});

final clerkServiceProvider = Provider<ClerkService>((ref) {
  final client = ref.watch(clerkClientProvider);
  return ClerkService(client);
});

// Current User ID Provider
final currentUserIdProvider = Provider<String?>((ref) {
  final service = ref.watch(clerkServiceProvider);
  return service.currentUserId;
});
```

### Step 3: Update Providers

Update `lib/src/state/providers.dart`:

```dart
// Replace the placeholder currentUserIdProvider with:
final currentUserIdProvider = Provider<String?>((ref) {
  final service = ref.watch(clerkServiceProvider);
  return service.currentUserId;
});

// Add auth state provider
final authStateProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(clerkClientProvider);
  return client.authStateChanges();
});
```

### Step 4: Create Auth Screen

Create `lib/src/ui/screens/auth_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import '../../state/providers.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return Scaffold(
      body: Center(
        child: authState.when(
          data: (state) {
            if (state.isSignedIn) {
              return _buildSignedInView(context, ref);
            }
            return _buildSignInView(context, ref);
          },
          loading: () => const CircularProgressIndicator(),
          error: (error, stack) => Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildSignInView(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.lock_outline, size: 80),
        const SizedBox(height: 24),
        Text(
          'Welcome to AniSwipe',
          style: Theme.of(context).textTheme.displayLarge,
        ),
        const SizedBox(height: 48),
        SignInButton(
          mode: SignInMode.emailPassword,
          afterSignInAction: AfterSignInAction.redirect(
            to: '/',
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            // Navigate to sign up
          },
          child: const Text('Create an account'),
        ),
      ],
    );
  }

  Widget _buildSignedInView(BuildContext context, WidgetRef ref) {
    final user = ref.watch(clerkServiceProvider).currentUser;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: user?.imageUrl != null
              ? NetworkImage(user!.imageUrl!)
              : null,
          child: user?.imageUrl == null
              ? const Icon(Icons.person, size: 40)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          user?.fullName ?? 'Welcome back!',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            ref.read(clerkServiceProvider).signOut();
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }
}
```

### Step 5: Update App Entry Point

Update `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('discover_cache');
  await Hive.openBox('favorites_cache');
  await Hive.openBox('offline_queue');

  // Initialize Clerk
  final clerkPublishableKey = dotenv.env['CLERK_PUBLISHABLE_KEY'];
  if (clerkPublishableKey == null) {
    throw Exception('CLERK_PUBLISHABLE_KEY not found in .env file');
  }

  await ClerkFlutter.instance.init(
    publishableKey: clerkPublishableKey,
  );

  // Initialize Supabase with Clerk JWT
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception('Supabase credentials not found in .env file');
  }

  await Supabase.initialize(
    url: supabaseUrl!,
    anonKey: supabaseAnonKey!,
  );

  runApp(
    const ProviderScope(
      child: AniSwipeApp(),
    ),
  );
}
```

### Step 6: Update App Widget

Update `lib/app.dart` to include auth screen:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'src/ui/screens/auth_screen.dart';
import 'src/ui/screens/discover_screen.dart';
import 'src/ui/screens/search_screen.dart';
import 'src/ui/screens/profile_screen.dart';
import 'src/ui/widgets/three_js_background.dart';

class AniSwipeApp extends ConsumerWidget {
  const AniSwipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'AniSwipe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ... existing theme configuration
      ),
      home: authState.when(
        data: (state) {
          if (state.isSignedIn) {
            return const MainScreen();
          }
          return const AuthScreen();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          body: Center(child: Text('Error: $error')),
        ),
      ),
    );
  }
}
```

---

## Supabase Integration with Clerk JWT

### Option 1: Client-Side with Clerk User ID

Update `lib/src/services/supabase_service.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import '../state/providers.dart';

class SupabaseService {
  final SupabaseClient _client;
  final ClerkService _clerkService;

  SupabaseService(this._client, this._clerkService);

  // Get user ID from Clerk
  String? get _userId {
    return _clerkService.currentUserId;
  }

  // Example: Save favorite with Clerk user ID
  Future<Favorite?> saveFavorite(Anime anime) async {
    final userId = _userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client
          .from('favorites')
          .insert({
            'user_id': userId,
            'anime_id': anime.malId,
            'anime_title': anime.title,
            'anime_poster': anime.imageUrl,
            'anime_score': anime.score,
            'anime_type': anime.type,
            'anime_episodes': anime.episodes,
          })
          .select()
          .single();

      return Favorite.fromJson(response);
    } catch (e) {
      print('Error saving favorite: $e');
      return null;
    }
  }

  // All other methods use _userId instead of parameter
  Future<List<Favorite>> getFavorites() async {
    final userId = _userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Favorite.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching favorites: $e');
      return [];
    }
  }
}
```

### Option 2: Server-Side with JWT Verification (Recommended)

For enhanced security, verify Clerk JWT in Supabase Edge Functions:

1. **Create Edge Function** (`supabase/functions/verify-clerk-token/index.ts`):

```typescript
import { serve } from 'https://deno.land/std/http/server.ts';
import { createClient } from '@supabase/supabase-js';
import { verifyToken } from 'clerk-backend-core';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const clerkSecretKey = Deno.env.get('CLERK_SECRET_KEY')!;

const supabase = createClient(supabaseUrl, supabaseServiceKey);

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'authorization, content-type',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Extract JWT from Authorization header
    const authHeader = req.headers.get('authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: corsHeaders },
      );
    }

    const token = authHeader.substring(7);

    // Verify Clerk JWT
    const payload = await verifyToken(token, clerkSecretKey);
    
    if (!payload) {
      return new Response(
        JSON.stringify({ error: 'Invalid token' }),
        { status: 401, headers: corsHeaders },
      );
    }

    // Extract user ID from verified token
    const userId = payload.sub as string;

    // Set Supabase auth context with user ID
    const { data, error } = await supabase.auth.setAuth({
      token: userId, // Use Clerk user ID as Supabase token
      user: { id: userId },
    });

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message }),
        { status: 500, headers: corsHeaders },
      );
    }

    return new Response(
      JSON.stringify({ success: true, userId }),
      { headers: corsHeaders },
    );

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: corsHeaders },
    );
  }
});
```

2. **Update Flutter to use Edge Function**:

```dart
// In supabase_service.dart
Future<void> _setSupabaseAuthContext() async {
  final jwtToken = _clerkService.jwtToken;
  if (jwtToken == null) return;

  try {
    final response = await http.post(
      Uri.parse('${dotenv.env['SUPABASE_URL']}/functions/v1/verify-clerk-token'),
      headers: {
        'Authorization': 'Bearer $jwtToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      print('Supabase auth context set successfully');
    }
  } catch (e) {
    print('Error setting Supabase auth context: $e');
  }
}
```

---

## Environment Configuration

### Update .env.example

```env
# Clerk Configuration
CLERK_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxx

# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key_here

# Optional: For server-side JWT verification
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key_here
CLERK_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxx
```

---

## Clean Architecture Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    User Interaction                         │
│              (Tap "Sign In" button)                      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Triggers
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Clerk JavaScript SDK                       │
│  - Displays sign-in form                                   │
│  - Handles authentication flow                              │
│  - Manages session in browser                            │
│  - Returns JWT token                                      │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Provides
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Flutter Web Runtime                         │
│  - Receives auth state from Clerk                           │
│  - Stores user ID in Riverpod provider                     │
│  - Passes user ID to services                              │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Uses
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Supabase Service                          │
│  - Receives user ID from provider                          │
│  - Makes authenticated requests                            │
│  - Enforces RLS policies                                  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Stores
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              Supabase Database                          │
│  - RLS verifies user_id matches auth token                 │
│  - Allows/disallows operations based on ownership              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Testing Checklist

### Local Development

- [ ] Clerk application created with JavaScript framework
- [ ] Publishable key added to `.env` file
- [ ] Clerk Flutter SDK added to `pubspec.yaml`
- [ ] Auth screen displays sign-in form
- [ ] Sign-in redirects to main app
- [ ] User ID available in Riverpod provider
- [ ] Supabase requests include user ID
- [ ] RLS policies enforce ownership

### Production Deployment

- [ ] Production URLs added to Clerk allowed origins
- [ ] Production publishable key configured
- [ ] CORS settings verified
- [ ] JWT template includes user_id claim
- [ ] Session duration configured appropriately
- [ ] Edge functions deployed (if using server-side verification)
- [ ] Environment variables set in production

---

## Troubleshooting

### Issue: "Clerk SDK not initializing"

**Solution**: Verify you selected "JavaScript" as the application type in Clerk Dashboard. Flutter Web requires JavaScript SDK, not React or Mobile Native.

### Issue: "User ID is null after sign-in"

**Solution**: Ensure you're watching the correct provider:
```dart
final userId = ref.watch(currentUserIdProvider); // Correct
// Not:
final userId = ref.watch(clerkServiceProvider).currentUserId; // May not trigger rebuild
```

### Issue: "Supabase RLS blocking requests"

**Solution**: Verify RLS policies use `auth.uid()` or `auth.token()`:
```sql
-- Correct RLS policy
CREATE POLICY "Users can view own favorites"
ON favorites FOR SELECT
USING (auth.uid() = user_id);

-- Incorrect (won't work with Clerk)
CREATE POLICY "Users can view own favorites"
ON favorites FOR SELECT
USING (auth.jwt()->>'user_id' = user_id);
```

### Issue: "CORS errors in browser console"

**Solution**: Add your Flutter Web URL to Clerk CORS settings:
- Development: `http://localhost:3000`
- Production: `https://your-domain.com`

---

## Security Best Practices

1. **Never expose Secret Keys**: Only use publishable key in Flutter client
2. **Use HTTPS in Production**: All Clerk and Supabase URLs must use HTTPS
3. **Implement RLS**: All Supabase tables must have RLS policies
4. **Validate Tokens**: Verify Clerk JWT on server-side for sensitive operations
5. **Handle Session Expiry**: Implement token refresh logic
6. **Secure Local Storage**: Use secure storage for sensitive data
7. **Log Out Properly**: Clear all auth state on sign-out

---

## Summary

For AniSwipe Flutter Web:

1. **Select JavaScript** in Clerk Dashboard (not React, Next.js, Expo, or Mobile Native)
2. **Use Clerk Flutter SDK** for client-side authentication
3. **Pass User ID** to Supabase for RLS enforcement
4. **Optionally verify JWT** in Supabase Edge Functions for enhanced security
5. **Implement clean architecture** with proper separation of concerns

This architecture ensures secure, maintainable authentication that works seamlessly with Flutter Web's JavaScript compilation model.
