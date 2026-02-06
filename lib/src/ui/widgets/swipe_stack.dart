import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:card_swiper/card_swiper.dart';
import '../../models/anime.dart';
import 'anime_card.dart';

class SwipeStack extends StatefulWidget {
  final List<Anime> animeList;
  final Function(Anime)? onSwipeRight;
  final Function(Anime)? onSwipeLeft;
  final Function(Anime)? onTap;

  const SwipeStack({
    super.key,
    required this.animeList,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onTap,
  });

  @override
  State<SwipeStack> createState() => _SwipeStackState();
}

class _SwipeStackState extends State<SwipeStack>
    with SingleTickerProviderStateMixin {
  final SwiperController _controller = SwiperController();
  int _currentIndex = 0;
  double _dragOffset = 0.0;
  double _dragRotation = 0.0;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.animeList.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // Background cards (for visual depth)
        ..._buildBackgroundCards(),

        // Main swipeable card
        _buildMainCard(),

        // Action buttons
        _buildActionButtons(),
      ],
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
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No more anime',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh for more',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundCards() {
    final backgrounds = <Widget>[];
    final maxBackgrounds = math.min(3, widget.animeList.length - _currentIndex - 1);

    for (int i = 0; i < maxBackgrounds; i++) {
      final index = _currentIndex + i + 1;
      if (index < widget.animeList.length) {
        backgrounds.add(
          Positioned(
            top: 20 + (i * 10),
            left: 20 + (i * 10),
            right: 20 + (i * 10),
            bottom: 100 + (i * 10),
            child: Opacity(
              opacity: 0.25 - (i * 0.07),
              child: Transform.scale(
                scale: 1.0 - (i * 0.05),
                child: AnimeCard(anime: widget.animeList[index]),
              ),
            ),
          ),
        );
      }
    }

    return backgrounds;
  }

  Widget _buildMainCard() {
    if (_currentIndex >= widget.animeList.length) {
      return const SizedBox.shrink();
    }

    final anime = widget.animeList[_currentIndex];

    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      bottom: 100,
      child: GestureDetector(
        onPanStart: (details) {
          _scaleController.forward(from: 0.0);
        },
        onPanUpdate: (details) {
          setState(() {
            _dragOffset = details.delta.dx;
            _dragRotation = _dragOffset * 0.003;
          });
        },
        onPanEnd: (details) {
          _scaleController.reverse();
          final velocity = details.velocity.pixelsPerSecond.dx;
          
          // Haptic feedback
          if (velocity.abs() > 300) {
            // Trigger haptic feedback if available
          }

          if (velocity > 500) {
            _handleSwipeRight();
          } else if (velocity < -500) {
            _handleSwipeLeft();
          } else {
            // Reset position if not swiped
            setState(() {
              _dragOffset = 0.0;
              _dragRotation = 0.0;
            });
          }
        },
        onTap: () {
          widget.onTap?.call(anime);
        },
        child: Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: Transform.rotate(
            angle: _dragRotation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Stack(
                children: [
                  AnimeCard(anime: anime),
                  _buildSwipeIndicators(),
                ],
              ),
            ),
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
                opacity: _dragOffset > 0 ? _dragOffset.clamp(0.0, 1.0) : 0.0,
                child: _buildSwipeStamp(
                  'LIKE',
                  const Color(0xFF4ADE80),
                  _dragRotation * 0.5,
                ),
              ),
            ),
            // Nope indicator (left)
            Positioned(
              top: 50,
              left: 24,
              child: Opacity(
                opacity: _dragOffset < 0 ? (-_dragOffset).clamp(0.0, 1.0) : 0.0,
                child: _buildSwipeStamp(
                  'NOPE',
                  const Color(0xFFFF6B6B),
                  _dragRotation * 0.5,
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

  Widget _buildActionButtons() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            icon: Icons.close,
            color: const Color(0xFFFF6B6B),
            onPressed: _handleSwipeLeft,
          ),
          const SizedBox(width: 40),
          _buildActionButton(
            icon: Icons.refresh,
            color: Colors.orange,
            onPressed: () {
              // TODO: Implement undo or refresh
            },
          ),
          const SizedBox(width: 40),
          _buildActionButton(
            icon: Icons.favorite,
            color: const Color(0xFF4ADE80),
            onPressed: _handleSwipeRight,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(32),
        splashColor: color.withOpacity(0.3),
        highlightColor: color.withOpacity(0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(icon, color: color, size: 32),
        ),
      ),
    );
  }

  void _handleSwipeRight() {
    if (_currentIndex < widget.animeList.length) {
      final anime = widget.animeList[_currentIndex];
      widget.onSwipeRight?.call(anime);
      setState(() {
        _currentIndex++;
        _dragOffset = 0.0;
        _dragRotation = 0.0;
      });
    }
  }

  void _handleSwipeLeft() {
    if (_currentIndex < widget.animeList.length) {
      final anime = widget.animeList[_currentIndex];
      widget.onSwipeLeft?.call(anime);
      setState(() {
        _currentIndex++;
        _dragOffset = 0.0;
        _dragRotation = 0.0;
      });
    }
  }
}

// Alternative implementation using flutter_card_swiper
class CardSwiperStack extends StatefulWidget {
  final List<Anime> animeList;
  final Function(Anime)? onSwipeRight;
  final Function(Anime)? onSwipeLeft;
  final Function(Anime)? onTap;

  const CardSwiperStack({
    super.key,
    required this.animeList,
    this.onSwipeRight,
    this.onSwipeLeft,
    this.onTap,
  });

  @override
  State<CardSwiperStack> createState() => _CardSwiperStackState();
}

class _CardSwiperStackState extends State<CardSwiperStack> {
  final SwiperController _controller = SwiperController();

  @override
  Widget build(BuildContext context) {
    if (widget.animeList.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Swiper(
        controller: _controller,
        itemCount: widget.animeList.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              widget.onTap?.call(widget.animeList[index]);
            },
            child: AnimeCard(anime: widget.animeList[index]),
          );
        },
        layout: SwiperLayout.STACK,
        itemWidth: MediaQuery.of(context).size.width * 0.85,
        itemHeight: MediaQuery.of(context).size.height * 0.65,
        onIndexChanged: (index) {
          // Handle index change if needed
        },
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
            color: Colors.white.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No more anime',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull to refresh for more',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white.withOpacity(0.7),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
