import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

/**
 * Comments functionality with threading support and pagination
 */

// Create a new comment
export const createComment = mutation({
  args: {
    userId: v.string(),
    animeId: v.number(),
    content: v.string(),
    parentCommentId: v.optional(v.id("comments")),
  },
  handler: async (ctx, args) => {
    // Validate content
    if (args.content.trim().length < 3) {
      throw new Error("Comment must be at least 3 characters");
    }

    if (args.content.length > 2000) {
      throw new Error("Comment must be less than 2000 characters");
    }

    const commentId = await ctx.db.insert("comments", {
      animeId: args.animeId,
      userId: args.userId,
      content: args.content.trim(),
      parentCommentId: args.parentCommentId,
      createdAt: Date.now(),
      likes: 0,
      likedBy: [],
    });

    return commentId;
  },
});

// Get comments for an anime
export const getComments = query({
  args: {
    animeId: v.number(),
    limit: v.optional(v.number()),
    cursor: v.optional(v.id("comments")),
  },
  handler: async (ctx, args) => {
    const limit = args.limit || 20;

    // Get top-level comments
    const comments = await ctx.db
      .query("comments")
      .withIndex("by_animeId", (q) => q.eq("animeId", args.animeId))
      .collect();

    // Filter and sort by createdAt
    const filtered = comments
      .filter((c) => c.parentCommentId === undefined)
      .sort((a, b) => b.createdAt - a.createdAt);

    // Get replies for each comment
    const commentsWithReplies = await Promise.all(
      filtered.map(async (comment) => {
        const replies = await ctx.db
          .query("comments")
          .withIndex("by_parentCommentId", (q) =>
            q.eq("parentCommentId", comment._id)
          )
          .collect();

        // Sort replies by createdAt
        replies.sort((a, b) => a.createdAt - b.createdAt);

        return {
          ...comment,
          replies,
          replyCount: replies.length,
        };
      })
    );

    return commentsWithReplies.slice(0, limit);
  },
});

// Get comment by ID
export const getCommentById = query({
  args: { commentId: v.id("comments") },
  handler: async (ctx, args) => {
    const comment = await ctx.db.get(args.commentId);
    return comment;
  },
});

// Update a comment
export const updateComment = mutation({
  args: {
    commentId: v.id("comments"),
    userId: v.string(),
    content: v.string(),
  },
  handler: async (ctx, args) => {
    const comment = await ctx.db.get(args.commentId);

    if (!comment) {
      throw new Error("Comment not found");
    }

    if (comment.userId !== args.userId) {
      throw new Error("You can only edit your own comments");
    }

    // Validate content
    if (args.content.trim().length < 3) {
      throw new Error("Comment must be at least 3 characters");
    }

    await ctx.db.patch(args.commentId, {
      content: args.content.trim(),
      updatedAt: Date.now(),
    });

    return { success: true };
  },
});

// Delete a comment
export const deleteComment = mutation({
  args: {
    commentId: v.id("comments"),
    userId: v.string(),
  },
  handler: async (ctx, args) => {
    const comment = await ctx.db.get(args.commentId);

    if (!comment) {
      throw new Error("Comment not found");
    }

    if (comment.userId !== args.userId) {
      throw new Error("You can only delete your own comments");
    }

    // Delete all replies recursively
    const deleteReplies = async (parentId: any) => {
      const replies = await ctx.db
        .query("comments")
        .withIndex("by_parentCommentId", (q) =>
          q.eq("parentCommentId", parentId)
        )
        .collect();

      for (const reply of replies) {
        await deleteReplies(reply._id);
        await ctx.db.delete(reply._id);
      }
    };

    await deleteReplies(args.commentId);
    await ctx.db.delete(args.commentId);

    return { success: true };
  },
});

// Like a comment
export const likeComment = mutation({
  args: {
    commentId: v.id("comments"),
    userId: v.string(),
  },
  handler: async (ctx, args) => {
    const comment = await ctx.db.get(args.commentId);

    if (!comment) {
      throw new Error("Comment not found");
    }

    const likedBy = comment.likedBy || [];

    if (likedBy.includes(args.userId)) {
      // Unlike
      const newLikedBy = likedBy.filter((id) => id !== args.userId);
      await ctx.db.patch(args.commentId, {
        likedBy: newLikedBy,
        likes: newLikedBy.length,
      });

      return { liked: false, likes: newLikedBy.length };
    } else {
      // Like
      const newLikedBy = [...likedBy, args.userId];
      await ctx.db.patch(args.commentId, {
        likedBy: newLikedBy,
        likes: newLikedBy.length,
      });

      return { liked: true, likes: newLikedBy.length };
    }
  },
});

// Get user's comments
export const getUserComments = query({
  args: {
    userId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const comments = await ctx.db
      .query("comments")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    // Sort by createdAt descending
    comments.sort((a, b) => b.createdAt - a.createdAt);

    return comments.slice(0, args.limit || 50);
  },
});

// Report a comment
export const reportComment = mutation({
  args: {
    commentId: v.id("comments"),
    userId: v.string(),
    reason: v.string(),
  },
  handler: async (ctx, args) => {
    // In a production app, this would send a notification to moderators
    console.log(`Comment ${args.commentId} reported by ${args.userId}: ${args.reason}`);

    return {
      success: true,
      message: "Comment reported successfully",
    };
  },
});

// Get comment count for an anime
export const getCommentCount = query({
  args: { animeId: v.number() },
  handler: async (ctx, args) => {
    const comments = await ctx.db
      .query("comments")
      .withIndex("by_animeId", (q) => q.eq("animeId", args.animeId))
      .collect();

    return comments.length;
  },
});
