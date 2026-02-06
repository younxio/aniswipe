import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../widgets/filter_panel.dart';
import '../../models/anime.dart';
import '../../models/types.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final isLoading = ref.watch(searchLoadingProvider);
    final filter = ref.watch(searchFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search anime...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(searchQueryProvider.notifier).state = '';
                                ref.read(searchResultsProvider.notifier).state = [];
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (value) {
                      _performSearch(value);
                    },
                    onChanged: (value) {
                      ref.read(searchQueryProvider.notifier).state = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list),
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),
              ],
            ),
          ),

          // Filter panel
          if (_showFilters)
            FilterPanel(
              filter: filter,
              onFilterChanged: (newFilter) {
                ref.read(searchFilterProvider.notifier).state = newFilter;
              },
              onApply: () {
                _performSearch(_searchController.text);
                setState(() {
                  _showFilters = false;
                });
              },
              onClear: () {
                ref.read(searchFilterProvider.notifier).state = const AnimeFilter();
                _performSearch(_searchController.text);
              },
            ),

          // Active filters chips
          if (_hasActiveFilters(filter))
            _buildActiveFilters(filter),

          // Search results
          Expanded(
            child: _buildSearchResults(searchResults, isLoading),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(AnimeFilter filter) {
    final chips = <Widget>[];

    if (filter.genres != null && filter.genres!.isNotEmpty) {
      chips.addAll(filter.genres!.map((genre) => Chip(
        label: Text(genre),
        onDeleted: () {
          final newGenres = List<String>.from(filter.genres!);
          newGenres.remove(genre);
          ref.read(searchFilterProvider.notifier).state = filter.copyWith(
            genres: newGenres.isEmpty ? null : newGenres,
          );
        },
      )));
    }

    if (filter.type != null) {
      chips.add(Chip(
        label: Text(filter.type!),
        onDeleted: () {
          ref.read(searchFilterProvider.notifier).state = filter.copyWith(type: null);
        },
      ));
    }

    if (filter.minScore != null) {
      chips.add(Chip(
        label: Text('Score ≥ ${filter.minScore}'),
        onDeleted: () {
          ref.read(searchFilterProvider.notifier).state = filter.copyWith(minScore: null);
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _buildSearchResults(List<Anime> results, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search or filters',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final anime = results[index];
        return _buildAnimeCard(anime);
      },
    );
  }

  Widget _buildAnimeCard(Anime anime) {
    return GestureDetector(
      onTap: () {
        ref.read(selectedAnimeProvider.notifier).state = anime;
        Navigator.pushNamed(context, '/details');
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (anime.imageUrl != null)
                    Image.network(
                      anime.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.movie,
                            size: 48,
                            color: Colors.grey,
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.movie,
                        size: 48,
                        color: Colors.grey,
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            anime.score.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (anime.type != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            anime.type!,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      if (anime.episodes != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${anime.episodes} eps',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActiveFilters(AnimeFilter filter) {
    return (filter.genres != null && filter.genres!.isNotEmpty) ||
        filter.type != null ||
        filter.minScore != null ||
        filter.status != null ||
        filter.rating != null;
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty && !_hasActiveFilters(ref.read(searchFilterProvider))) {
      return;
    }

    ref.read(searchLoadingProvider.notifier).state = true;

    try {
      final animeApi = ref.read(animeApiProvider);
      final filter = ref.read(searchFilterProvider);
      final searchFilter = filter.copyWith(query: query.trim().isEmpty ? null : query);

      final results = await animeApi.searchAnime(searchFilter);
      ref.read(searchResultsProvider.notifier).state = results;
    } catch (e) {
      showToast(ref, 'Search failed: $e', type: ToastType.error);
    } finally {
      ref.read(searchLoadingProvider.notifier).state = false;
    }
  }
}
