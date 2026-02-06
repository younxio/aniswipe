import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../widgets/swipe_stack.dart';
import '../widgets/anime_card.dart';
import '../../models/anime.dart';
import '../../models/types.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  @override
  Widget build(BuildContext context) {
    final discoverStack = ref.watch(discoverStackProvider);
    final isLoading = ref.watch(discoverLoadingProvider);
    final undoAction = ref.watch(undoActionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              ref.read(discoverLoadingProvider.notifier).state = true;
              await ref.read(discoverStackProvider.notifier).refreshStack();
              ref.read(discoverLoadingProvider.notifier).state = false;
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          if (isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (discoverStack.isEmpty)
            _buildEmptyState()
          else
            SwipeStack(
              animeList: discoverStack,
              onSwipeRight: (anime) => _handleSwipeRight(anime),
              onSwipeLeft: (anime) => _handleSwipeLeft(anime),
              onTap: (anime) => _handleTap(anime),
            ),

          // Undo toast
          if (undoAction != null && !undoAction.isExpired)
            _buildUndoToast(undoAction),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.movie_filter_outlined,
            size: 80,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No anime to show',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh or check back later',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildUndoToast(UndoAction action) {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                action.type == UndoActionType.favorite ? Icons.favorite : Icons.bookmark,
                color: const Color(0xFFFF6B6B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.type == UndoActionType.favorite ? 'Added to favorites' : 'Added to watch later',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      action.anime.title,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  await executeUndo(ref);
                },
                child: const Text(
                  'Undo',
                  style: TextStyle(
                    color: Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSwipeRight(Anime anime) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      showToast(ref, 'Please sign in to save favorites', type: ToastType.warning);
      return;
    }

    final service = ref.read(convexServiceProvider);
    final result = await service.saveFavorite(userId, anime);

    if (result != null) {
      setUndoAction(ref, UndoActionType.favorite, anime);
      showToast(ref, 'Added to favorites', type: ToastType.success);
      invalidateUserProviders(ref);
    } else {
      showToast(ref, 'Failed to add to favorites', type: ToastType.error);
    }
  }

  void _handleSwipeLeft(Anime anime) {
    // Left swipe just removes the card, no database action
    ref.read(discoverStackProvider.notifier).removeTopCard();
  }

  void _handleTap(Anime anime) {
    ref.read(selectedAnimeProvider.notifier).state = anime;
    Navigator.pushNamed(context, '/details');
  }
}
