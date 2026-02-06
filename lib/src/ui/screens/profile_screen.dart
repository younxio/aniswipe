import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../models/profile.dart';
import '../../models/types.dart';
import '../../services/convex_auth_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return _buildSignInPrompt();
    }

    final profileData = ref.watch(userProfileDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: profileData.when(
        data: (data) {
          if (data == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return _buildProfileContent(data);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading profile: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to access your profile',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showSignInDialog(),
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(UserProfileData data) {
    return Column(
      children: [
        // Profile header
        _buildProfileHeader(data.profile, data),

        // Tabs
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Favorites'),
            Tab(text: 'Watch Later'),
          ],
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFavoritesList(data.favorites),
              _buildWatchLaterList(data.watchLater),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(Profile profile, UserProfileData data) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundImage: profile.avatarUrl != null
                ? NetworkImage(profile.avatarUrl!)
                : null,
            child: profile.avatarUrl == null
                ? const Icon(Icons.person, size: 50)
                : null,
          ),

          const SizedBox(height: 16),

          // Display name
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                profile.displayName ?? 'Anonymous',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () => _showEditDisplayNameDialog(profile),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatChip(Icons.favorite, '${data.favorites.length}', 'Favorites'),
              const SizedBox(width: 16),
              _buildStatChip(Icons.bookmark, '${data.watchLater.length}', 'Watch Later'),
            ],
          ),

          const SizedBox(height: 16),

          // Sign out button
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await signOut(ref);
                showToast(ref, 'Signed out successfully', type: ToastType.success);
              } catch (e) {
                showToast(ref, 'Failed to sign out', type: ToastType.error);
              }
            },
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFFF6B6B)),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(List<Favorite> favorites) {
    if (favorites.isEmpty) {
      return _buildEmptyList(
        icon: Icons.favorite_border,
        title: 'No favorites yet',
        subtitle: 'Swipe right on anime to add them to your favorites',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final favorite = favorites[index];
        return _buildAnimeListItem(
          animeId: favorite.animeId,
          title: favorite.animeTitle,
          imageUrl: favorite.animePoster,
          score: favorite.animeScore,
          type: favorite.animeType,
          episodes: favorite.animeEpisodes,
          onRemove: () => _removeFavorite(favorite),
        );
      },
    );
  }

  Widget _buildWatchLaterList(List<WatchLater> watchLater) {
    if (watchLater.isEmpty) {
      return _buildEmptyList(
        icon: Icons.bookmark_border,
        title: 'Watch later list is empty',
        subtitle: 'Add anime to watch later from the details screen',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: watchLater.length,
      itemBuilder: (context, index) {
        final item = watchLater[index];
        return _buildAnimeListItem(
          animeId: item.animeId,
          title: item.animeTitle,
          imageUrl: item.animePoster,
          onRemove: () => _removeFromWatchLater(item),
          trailing: _buildStatusDropdown(item),
        );
      },
    );
  }

  Widget _buildAnimeListItem({
    required int animeId,
    required String title,
    String? imageUrl,
    double? score,
    String? type,
    int? episodes,
    VoidCallback? onRemove,
    Widget? trailing,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  width: 60,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 80,
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.grey),
                    );
                  },
                )
              : Container(
                  width: 60,
                  height: 80,
                  color: Colors.grey[800],
                  child: const Icon(Icons.movie, color: Colors.grey),
                ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (score != null)
              Row(
                children: [
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(score.toStringAsFixed(2)),
                ],
              ),
            if (type != null || episodes != null)
              Text(
                '${type ?? ''}${type != null && episodes != null ? ' • ' : ''}${episodes != null ? '$episodes eps' : ''}',
              ),
          ],
        ),
        trailing: trailing ??
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
        onTap: () {
          // TODO: Navigate to details
        },
      ),
    );
  }

  Widget _buildStatusDropdown(WatchLater item) {
    return DropdownButton<String>(
      value: item.status,
      underline: const SizedBox.shrink(),
      items: const [
        DropdownMenuItem(value: 'unwatched', child: Text('Unwatched')),
        DropdownMenuItem(value: 'watching', child: Text('Watching')),
        DropdownMenuItem(value: 'completed', child: Text('Completed')),
        DropdownMenuItem(value: 'dropped', child: Text('Dropped')),
      ],
      onChanged: (value) async {
        if (value != null) {
          final userId = ref.read(currentUserIdProvider);
          if (userId != null) {
            final service = ref.read(convexServiceProvider);
            await service.updateWatchLaterStatus(userId, item.animeId, value);
            invalidateUserProviders(ref);
          }
        }
      },
    );
  }

  Widget _buildEmptyList({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDisplayNameDialog(Profile profile) {
    _displayNameController.text = profile.displayName ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            hintText: 'Enter your display name',
          ),
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = _displayNameController.text.trim();
              if (newName.isNotEmpty) {
                final userId = ref.read(currentUserIdProvider);
                if (userId != null) {
                  final service = ref.read(convexServiceProvider);
                  await service.updateProfile(
                    userId,
                    ProfileUpdateRequest(displayName: newName),
                  );
                  invalidateUserProviders(ref);
                  if (mounted) {
                    Navigator.pop(context);
                    showToast(ref, 'Display name updated', type: ToastType.success);
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeFavorite(Favorite favorite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Favorite'),
        content: Text('Remove "${favorite.animeTitle}" from favorites?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final service = ref.read(convexServiceProvider);
        final success = await service.deleteFavorite(userId, favorite.animeId);
        if (success) {
          showToast(ref, 'Removed from favorites', type: ToastType.success);
          invalidateUserProviders(ref);
        } else {
          showToast(ref, 'Failed to remove', type: ToastType.error);
        }
      }
    }
  }

  Future<void> _removeFromWatchLater(WatchLater item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Watch Later'),
        content: Text('Remove "${item.animeTitle}" from watch later?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        final service = ref.read(convexServiceProvider);
        final success = await service.removeFromWatchLater(userId, item.animeId);
        if (success) {
          showToast(ref, 'Removed from watch later', type: ToastType.success);
          invalidateUserProviders(ref);
        } else {
          showToast(ref, 'Failed to remove', type: ToastType.error);
        }
      }
    }
  }

  void _showSignInDialog() {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSignUp = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isSignUp ? 'Sign Up' : 'Sign In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => isSignUp = !isSignUp),
                child: Text(
                  isSignUp 
                    ? 'Already have an account? Sign in'
                    : "Don't have an account? Sign up",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                final password = passwordController.text;

                if (email.isEmpty || password.isEmpty) {
                  showToast(ref, 'Please fill all fields', type: ToastType.error);
                  return;
                }

                try {
                  final authService = ref.read(convexAuthServiceProvider);
                  AuthResult result;
                  if (isSignUp) {
                    result = await authService.signUp(email: email, password: password);
                    if (result.success) {
                      showToast(ref, 'Account created! Please check your email.', type: ToastType.success);
                    } else {
                      showToast(ref, result.error ?? 'Sign up failed', type: ToastType.error);
                      return;
                    }
                  } else {
                    result = await authService.signIn(email: email, password: password);
                    if (result.success) {
                      showToast(ref, 'Signed in successfully!', type: ToastType.success);
                    } else {
                      showToast(ref, result.error ?? 'Sign in failed', type: ToastType.error);
                      return;
                    }
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  showToast(ref, e.toString(), type: ToastType.error);
                }
              },
              child: Text(isSignUp ? 'Sign Up' : 'Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
