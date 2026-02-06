import 'dart:ui';
import 'package:flutter/material.dart';
import '../../models/anime.dart';
import '../../services/anime_api.dart';

class FilterPanel extends StatefulWidget {
  final AnimeFilter filter;
  final Function(AnimeFilter) onFilterChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const FilterPanel({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late AnimeFilter _currentFilter;
  double _minScore = 0.0;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _minScore = widget.filter.minScore ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.06),
              ],
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.15),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Genre selection
              _buildSectionTitle('Genres'),
              const SizedBox(height: 12),
              _buildGenreChips(),

              const SizedBox(height: 24),

              // Type selection
              _buildSectionTitle('Type'),
              const SizedBox(height: 12),
              _buildTypeSegmentedControl(),

              const SizedBox(height: 24),

              // Score slider
              _buildSectionTitle('Minimum Score: ${_minScore.toStringAsFixed(1)}'),
              const SizedBox(height: 12),
              _buildScoreSlider(),

              const SizedBox(height: 24),

              // Status selection
              _buildSectionTitle('Status'),
              const SizedBox(height: 12),
              _buildStatusChips(),

              const SizedBox(height: 24),

              // Rating selection
              _buildSectionTitle('Rating'),
              const SizedBox(height: 12),
              _buildRatingChips(),

              const SizedBox(height: 32),

              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        letterSpacing: -0.5,
        height: 1.3,
      ),
    );
  }

  Widget _buildGenreChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AnimeApi.allGenres.map((genre) {
        final isSelected = _currentFilter.genres?.contains(genre) ?? false;
        return _buildGlassChip(
          label: genre,
          isSelected: isSelected,
          onSelected: (selected) {
            final genres = List<String>.from(_currentFilter.genres ?? []);
            if (selected) {
              genres.add(genre);
            } else {
              genres.remove(genre);
            }
            setState(() {
              _currentFilter = _currentFilter.copyWith(
                genres: genres.isEmpty ? null : genres,
              );
            });
            widget.onFilterChanged(_currentFilter);
          },
        );
      }).toList(),
    );
  }

  Widget _buildTypeSegmentedControl() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: SegmentedButton<String>(
        segments: AnimeApi.allTypes.map((type) {
          return ButtonSegment(
            value: type,
            label: Text(
              type,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          );
        }).toList(),
        selected: _currentFilter.type != null
            ? {_currentFilter.type!}
            : const <String>{},
        onSelectionChanged: (Set<String> selected) {
          setState(() {
            _currentFilter = _currentFilter.copyWith(
              type: selected.isEmpty ? null : selected.first,
            );
          });
          widget.onFilterChanged(_currentFilter);
        },
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const Color(0xFFFF6B6B).withOpacity(0.9);
            }
            return Colors.transparent;
          }),
          foregroundColor: MaterialStateProperty.all(Colors.white),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.white.withOpacity(0.2);
            }
            return Colors.white.withOpacity(0.1);
          }),
        ),
      ),
    );
  }

  Widget _buildScoreSlider() {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: const Color(0xFFFF6B6B),
        inactiveTrackColor: Colors.white.withOpacity(0.15),
        thumbColor: const Color(0xFFFF6B6B),
        overlayColor: const Color(0xFFFF6B6B).withOpacity(0.2),
        valueIndicatorColor: const Color(0xFFFF6B6B),
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      child: Slider(
        value: _minScore,
        min: 0.0,
        max: 10.0,
        divisions: 20,
        label: _minScore.toStringAsFixed(1),
        onChanged: (value) {
          setState(() {
            _minScore = value;
            _currentFilter = _currentFilter.copyWith(
              minScore: value == 0.0 ? null : value,
            );
          });
          widget.onFilterChanged(_currentFilter);
        },
      ),
    );
  }

  Widget _buildStatusChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AnimeApi.allStatuses.map((status) {
        final isSelected = _currentFilter.status == status;
        return _buildGlassChip(
          label: status.capitalize(),
          isSelected: isSelected,
          onSelected: (selected) {
            setState(() {
              _currentFilter = _currentFilter.copyWith(
                status: selected ? status : null,
              );
            });
            widget.onFilterChanged(_currentFilter);
          },
        );
      }).toList(),
    );
  }

  Widget _buildRatingChips() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AnimeApi.allRatings.map((rating) {
        final isSelected = _currentFilter.rating == rating;
        return _buildGlassChip(
          label: rating.toUpperCase(),
          isSelected: isSelected,
          onSelected: (selected) {
            setState(() {
              _currentFilter = _currentFilter.copyWith(
                rating: selected ? rating : null,
              );
            });
            widget.onFilterChanged(_currentFilter);
          },
        );
      }).toList(),
    );
  }

  Widget _buildGlassChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!isSelected),
        borderRadius: BorderRadius.circular(24),
        splashColor: isSelected
            ? Colors.white.withOpacity(0.2)
            : const Color(0xFFFF6B6B).withOpacity(0.2),
        highlightColor: isSelected
            ? Colors.white.withOpacity(0.1)
            : const Color(0xFFFF6B6B).withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFF6B6B).withOpacity(0.85)
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildGlassButton(
            text: 'Clear',
            onPressed: widget.onClear,
            isPrimary: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassButton(
            text: 'Apply Filters',
            onPressed: widget.onApply,
            isPrimary: true,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        splashColor: isPrimary
            ? Colors.white.withOpacity(0.3)
            : Colors.white.withOpacity(0.15),
        highlightColor: isPrimary
            ? Colors.white.withOpacity(0.2)
            : Colors.white.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFFFF6B6B).withOpacity(0.9)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B6B).withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
