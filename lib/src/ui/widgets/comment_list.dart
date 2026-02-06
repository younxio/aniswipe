import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../models/comment.dart';
import '../../models/types.dart';

class CommentList extends ConsumerStatefulWidget {
  final int animeId;

  const CommentList({
    super.key,
    required this.animeId,
  });

  @override
  ConsumerState<CommentList> createState() => _CommentListState();
}

class _CommentListState extends ConsumerState<CommentList> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(commentsProvider(widget.animeId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add comment input
        _buildCommentInput(),

        const SizedBox(height: 24),

        // Comments list
        commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return _buildEmptyComments();
            }
            return _buildCommentsList(comments);
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B6B)),
              ),
            ),
          ),
          error: (error, stack) => _buildErrorState(error),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    final userId = ref.watch(currentUserIdProvider);

    if (userId == null) {
      return _buildGlassCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.login_outlined,
                size: 24,
                color: Colors.white.withOpacity(0.6),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Sign in to leave a comment',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _commentController,
              maxLines: 3,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Write a comment...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF6B6B),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildGlassButton(
                  text: 'Cancel',
                  onPressed: () {
                    _commentController.clear();
                  },
                  isPrimary: false,
                ),
                const SizedBox(width: 12),
                _buildGlassButton(
                  text: 'Post Comment',
                  onPressed: _isSubmitting ? null : _submitComment,
                  isPrimary: true,
                  isLoading: _isSubmitting,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyComments() {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.comment_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'No comments yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Be the first to share your thoughts!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
                fontSize: 15,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList(List<Comment> comments) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Divider(
          height: 1,
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return _buildCommentItem(comment);
      },
    );
  }

  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and timestamp
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: comment.userAvatar != null
                      ? NetworkImage(comment.userAvatar!)
                      : null,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  child: comment.userAvatar == null
                      ? Icon(
                          Icons.person,
                          size: 24,
                          color: Colors.white.withOpacity(0.7),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(comment.createdAt),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Comment content
          Text(
            comment.content,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return _buildGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 24,
              color: const Color(0xFFFF6B6B),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Failed to load comments: $error',
                style: const TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.invalidate(commentsProvider(widget.animeId));
              },
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: const Color(0xFFFF6B6B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary
                ? (onPressed == null
                    ? Colors.white.withOpacity(0.3)
                    : const Color(0xFFFF6B6B).withOpacity(0.9))
                : (onPressed == null
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.15)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
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

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      showToast(ref, 'Please enter a comment', type: ToastType.warning);
      return;
    }

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final service = ref.read(convexServiceProvider);
      final request = CommentCreateRequest(
        animeId: widget.animeId,
        userId: userId,
        content: content,
      );

      final result = await service.addComment(request);

      if (result != null) {
        _commentController.clear();
        ref.invalidate(commentsProvider(widget.animeId));
        showToast(ref, 'Comment posted!', type: ToastType.success);
      } else {
        showToast(ref, 'Failed to post comment', type: ToastType.error);
      }
    } catch (e) {
      showToast(ref, 'Error: $e', type: ToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
