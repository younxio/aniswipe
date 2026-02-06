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
- **Authentication**: Mock authentication (ready for production)
- **Database & Realtime**: Convex (ready for integration)
- **Local Storage**: Hive
- **State Management**: Riverpod

## Prerequisites

- Flutter SDK (3.0 or higher)
- A Convex account ([sign up](https://convex.dev)) - optional for mock mode

## Setup

### 1. Clone Repository

```bash
git clone https://github.com/younxio/aniswipe.git
cd aniswipe
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run App

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
        login_screen.dart
        signup_screen.dart
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
      mock_convex_service.dart # Mock services for testing
    models/              # Data models
      anime.dart
      comment.dart
      profile.dart
      types.dart
    state/               # State management
      providers.dart
convex/
  schema.md              # Convex server functions
```

## Current Status

### Completed
- Authentication UI with glassmorphism effects
- Mock authentication service for testing
- Complete state management with Riverpod
- Anime discovery and search functionality
- Responsive design and animations

### In Progress
- Production backend integration
- Glassmorphism effects on all components
- Three.js 3D background integration

### Next Steps
1. Set up Convex backend (optional - mock mode works)
2. Configure production authentication
3. Complete UI enhancements
4. Deploy to production

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

1. Fork repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

MIT License

## Support

For issues and questions, please open an issue on repository.
