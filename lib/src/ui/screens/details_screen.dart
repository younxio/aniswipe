import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../state/providers.dart';
import '../../models/anime.dart';
import '../../models/types.dart';
import '../widgets/comment_list.dart';

class DetailsScreen extends ConsumerStatefulWidget {
  const DetailsScreen({super.key});

  @override
  ConsumerState<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends ConsumerState<DetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final selectedAnime = ref.watch(selectedAnimeProvider);

    if (selectedAnime == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Details'),
        ),
        body: const Center(
          child: Text('No anime selected'),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Parallax header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                selectedAnime.title,
                style: const TextStyle(
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (selectedAnime.largeImageUrl != null)
                    Image.network(
                      selectedAnime.largeImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                        );
                      },
                    )
                  else
                    Container(
                      color: Colors.grey[800],
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats row
                  _buildStatsRow(selectedAnime),

                  const SizedBox(height: 24),

                  // Action buttons
                  _buildActionButtons(selectedAnime),

                  const SizedBox(height: 24),

                  // Synopsis
                  _buildSectionTitle('Synopsis'),
                  const SizedBox(height: 8),
                  Text(
                    selectedAnime.synopsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                  const SizedBox(height: 24),

                  // Genres
                  if (selectedAnime.genres.isNotEmpty) ...[
                    _buildSectionTitle('Genres'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedAnime.genres.map((genre) {
                        return Chip(
                          label: Text(genre),
                          backgroundColor: const Color(0xFF334155),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Studios
                  if (selectedAnime.studios != null && selectedAnime.studios!.isNotEmpty) ...[
                    _buildSectionTitle('Studios'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedAnime.studios!.map((studio) {
                        return Chip(
                          label: Text(studio.name),
                          backgroundColor: const Color(0xFF334155),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Additional info
                  _buildAdditionalInfo(selectedAnime),

                  const SizedBox(height: 24),

                  // Comments section
                  _buildSectionTitle('Comments'),
                  const SizedBox(height: 8),
                  CommentList(animeId: selectedAnime.malId),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Anime anime) {
    return Row(
      children: [
        _buildStatItem(
          Icons.star,
          anime.score.toStringAsFixed(2),
          'Score',
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          Icons.people,
          anime.popularity.toString(),
          'Popularity',
        ),
        const SizedBox(width: 16),
        _buildStatItem(
          Icons.star,
          '#${anime.rank}',
          'Rank',
        ),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF6B6B)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Anime anime) {
    final userId = ref.watch(currentUserIdProvider);
    final favoriteStatus = userId != null
        ? ref.watch(animeFavoriteStatusProvider(anime.malId))
        : const AsyncValue.data(false);
    final watchLaterStatus = userId != null
        ? ref.watch(animeWatchLaterStatusProvider(anime.malId))
        : const AsyncValue.data(false);

    return Row(
      children: [
        Expanded(
          child: favoriteStatus.when(
            data: (isFavorited) => ElevatedButton.icon(
              onPressed: userId != null
                  ? () => _toggleFavorite(anime, isFavorited)
                  : () => showToast(ref, 'Please sign in', type: ToastType.warning),
              icon: Icon(
                isFavorited ? Icons.favorite : Icons.favorite_border,
                color: isFavorited ? Colors.white : const Color(0xFFFF6B6B),
              ),
              label: Text(isFavorited ? 'Favorited' : 'Favorite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFavorited ? const Color(0xFFFF6B6B) : const Color(0xFF1E293B),
              ),
            ),
            loading: () => const ElevatedButton(
              onPressed: null,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.favorite_border),
              label: const Text('Favorite'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: watchLaterStatus.when(
            data: (isInWatchLater) => ElevatedButton.icon(
              onPressed: userId != null
                  ? () => _toggleWatchLater(anime, isInWatchLater)
                  : () => showToast(ref, 'Please sign in', type: ToastType.warning),
              icon: Icon(
                isInWatchLater ? Icons.bookmark : Icons.bookmark_border,
                color: isInWatchLater ? Colors.white : const Color(0xFFFF6B6B),
              ),
              label: Text(isInWatchLater ? 'Saved' : 'Watch Later'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isInWatchLater ? const Color(0xFFFF6B6B) : const Color(0xFF1E293B),
              ),
            ),
            loading: () => const ElevatedButton(
              onPressed: null,
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.bookmark_border),
              label: const Text('Watch Later'),
            ),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _shareAnime(anime),
          icon: const Icon(Icons.share),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.displayMedium,
    );
  }

  Widget _buildAdditionalInfo(Anime anime) {
    final info = <String, String?>{
      'Type': anime.type,
      'Episodes': anime.episodes?.toString(),
      'Status': anime.status,
      'Rating': anime.rating,
      'Duration': anime.duration,
      'Source': anime.source,
      'Season': anime.season != null && anime.year != null
          ? '${anime.season} ${anime.year}'
          : null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: info.entries
          .where((entry) => entry.value != null)
          .map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  '${entry.key}:',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  entry.value!,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _toggleFavorite(Anime anime, bool isFavorited) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final service = ref.read(convexServiceProvider);

    if (isFavorited) {
      final success = await service.deleteFavorite(userId, anime.malId);
      if (success) {
        showToast(ref, 'Removed from favorites', type: ToastType.success);
        invalidateUserProviders(ref);
      } else {
        showToast(ref, 'Failed to remove favorite', type: ToastType.error);
      }
    } else {
      final result = await service.saveFavorite(userId, anime);
      if (result != null) {
        showToast(ref, 'Added to favorites', type: ToastType.success);
        invalidateUserProviders(ref);
      } else {
        showToast(ref, 'Failed to add favorite', type: ToastType.error);
      }
    }
  }

  Future<void> _toggleWatchLater(Anime anime, bool isInWatchLater) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    final service = ref.read(convexServiceProvider);

    if (isInWatchLater) {
      final success = await service.removeFromWatchLater(userId, anime.malId);
      if (success) {
        showToast(ref, 'Removed from watch later', type: ToastType.success);
        invalidateUserProviders(ref);
      } else {
        showToast(ref, 'Failed to remove', type: ToastType.error);
      }
    } else {
      final result = await service.addToWatchLater(userId, anime);
      if (result != null) {
        showToast(ref, 'Added to watch later', type: ToastType.success);
        invalidateUserProviders(ref);
      } else {
        showToast(ref, 'Failed to add', type: ToastType.error);
      }
    }
  }

  Future<void> _shareAnime(Anime anime) async {
    final text = 'Check out ${anime.title}!\n\nScore: ${anime.score}\n\nShared from AniSwipe';
    await Share.share(text);
  }
}
