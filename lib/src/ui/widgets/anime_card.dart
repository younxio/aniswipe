import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import '../../models/anime.dart';

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onWatchLater;
  final bool showActions;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.onFavorite,
    this.onWatchLater,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster image
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPosterImage(),
                        _buildOverlay(),
                        _buildScoreBadge(),
                        if (showActions) _buildActionButtons(),
                      ],
                    ),
                  ),

                  // Title and metadata
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          anime.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            letterSpacing: -0.5,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        _buildMetadataRow(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterImage() {
    if (anime.imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: anime.imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[800],
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[800],
          child: const Icon(
            Icons.movie,
            size: 48,
            color: Colors.grey,
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey[800],
      child: const Icon(
        Icons.movie,
        size: 48,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.2),
            Colors.black.withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildScoreBadge() {
    return Positioned(
      top: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.star,
              size: 18,
              color: Colors.amber,
            ),
            const SizedBox(width: 6),
            Text(
              anime.score.toStringAsFixed(2),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          if (onFavorite != null)
            Expanded(
              child: _buildActionButton(
                icon: Icons.favorite_border,
                label: 'Favorite',
                onTap: onFavorite!,
              ),
            ),
          if (onFavorite != null && onWatchLater != null)
            const SizedBox(width: 12),
          if (onWatchLater != null)
            Expanded(
              child: _buildActionButton(
                icon: Icons.bookmark_border,
                label: 'Watch Later',
                onTap: onWatchLater!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: const Color(0xFFFF6B6B).withOpacity(0.3),
        highlightColor: const Color(0xFFFF6B6B).withOpacity(0.2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withOpacity(0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataRow() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        if (anime.type != null)
          _buildMetadataChip(anime.type!),
        if (anime.episodes != null)
          _buildMetadataChip('${anime.episodes} eps'),
        if (anime.status != null)
          _buildMetadataChip(anime.status!),
      ],
    );
  }

  Widget _buildMetadataChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class SwipeableAnimeCard extends StatefulWidget {
  final Anime anime;
  final VoidCallback? onTap;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onSwipeLeft;
  final double rotation;
  final double offset;

  const SwipeableAnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.rotation = 0,
    this.offset = 0,
  });

  @override
  State<SwipeableAnimeCard> createState() => _SwipeableAnimeCardState();
}

class _SwipeableAnimeCardState extends State<SwipeableAnimeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(widget.offset, 0),
      child: Transform.rotate(
        angle: widget.rotation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            children: [
              AnimeCard(anime: widget.anime, onTap: widget.onTap),
              _buildSwipeIndicators(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeIndicators() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Like indicator (right)
            Positioned(
              top: 50,
              right: 24,
              child: Opacity(
                opacity: widget.offset > 0 ? widget.offset.clamp(0.0, 1.0) : 0.0,
                child: _buildSwipeStamp(
                  'LIKE',
                  const Color(0xFF4ADE80),
                  widget.rotation * 0.5,
                ),
              ),
            ),
            // Nope indicator (left)
            Positioned(
              top: 50,
              left: 24,
              child: Opacity(
                opacity: widget.offset < 0 ? (-widget.offset).clamp(0.0, 1.0) : 0.0,
                child: _buildSwipeStamp(
                  'NOPE',
                  const Color(0xFFFF6B6B),
                  widget.rotation * 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeStamp(String text, Color color, double rotation) {
    return Transform.rotate(
      angle: rotation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
      ),
    );
  }
}
