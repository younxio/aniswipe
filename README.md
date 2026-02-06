# AniSwipe

A lightweight, privacy-conscious anime discovery and social bookmarking app with Tinder-style swipe UX.

## Features

- **Swipe Discovery**: Swipe right to favorite, left to skip anime
- **Persistent Favorites**: Save favorites to Convex with undo capability
- **Watch Later**: Queue anime to watch later
- **Comments**: Add and view comments on anime
- **Search & Filters**: Find anime by genre, type, and score
- **Recommendations**: Content-based recommendations from your favorites
- **Offline Support**: Local caching for offline-first behavior
- **Profile Management**: Edit display name and view your lists

## Tech Stack

- **Frontend**: Flutter (web + mobile-ready)
- **Authentication**: Clerk (via Convex)
- **Database & Realtime**: Convex
- **Local Storage**: Hive
- **State Management**: Riverpod

## Prerequisites

- Flutter SDK (3.0 or higher)
- A Convex account ([sign up](https://convex.dev))
- A Clerk account for authentication ([sign up](https://clerk.com))

## Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd swipe
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Convex Setup

1. Install Convex CLI: `npm install -g convex`
2. Login: `npx convex login`
3. Initialize: `npx convex dev`
4. Get your deployment URL from the Convex dashboard

### 4. Environment Configuration

Create a `.env` file in the project root:

```env
# Convex Configuration
CONVEX_DEPLOYMENT_URL=https://your-deployment-url.convex.cloud
CONVEX_SECRET=your_convex_secret_key_here

# Clerk (for authentication)
CLERK_PUBLISHABLE_KEY=pk_test_your_clerk_key_here
```

### 5. Deploy Convex Functions

Copy the functions from `convex/schema.md` to your Convex project:

```bash
npx convex dev
```

Then deploy:

```bash
npx convex deploy
```

### 6. Run the App

For web:
```bash
flutter run -d chrome
```

For mobile:
```bash
flutter run
```

## Project Structure

```
lib/
  main.dart              # App entry point
  app.dart               # Root app widget
  src/
    ui/
      screens/           # Screen widgets
        discover_screen.dart
        search_screen.dart
        details_screen.dart
        profile_screen.dart
      widgets/           # Reusable widgets
        anime_card.dart
        swipe_stack.dart
        filter_panel.dart
        comment_list.dart
        three_js_background.dart
    services/            # Business logic
      convex_service.dart      # Convex database operations
      convex_auth_service.dart # Convex authentication
      anime_api.dart           # Jikan API wrapper
      recommendation_service.dart
    models/              # Data models
      anime.dart
      comment.dart
      profile.dart
    state/               # State management
      providers.dart
convex/
  schema.md              # Convex server functions
```

## Database Schema

Convex functions are defined in `convex/schema.md` and include:

- **profiles**: User profile information
- **favorites**: User's favorited anime
- **watch_later**: User's watch-later queue
- **comments**: User comments on anime

## Authentication

Authentication is handled via Clerk through Convex:

1. Users sign up/in using email/password
2. Clerk validates credentials
3. Convex stores user data and manages sessions
4. All database operations are authenticated

## Security

- All database writes are authenticated via Clerk tokens
- Convex functions validate user identity
- No service_role keys are exposed to the client
- Comments and favorites are tied to user IDs

## Testing

Run unit tests:
```bash
flutter test
```

Run widget tests:
```bash
flutter test --widget-tests
```

## Building for Production

### Web
```bash
flutter build web
```

### Android
```bash
flutter build apk
```

### iOS
```bash
flutter build ios
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

[Specify your license here]

## Support

For issues and questions, please open an issue on the repository.
