import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Users table - stores user profile data linked to Clerk
  users: defineTable({
    clerkId: v.string(),
    displayName: v.optional(v.string()),
    avatarUrl: v.optional(v.string()),
    email: v.optional(v.string()),
    preferences: v.optional(v.object({
      favoriteGenres: v.optional(v.array(v.string())),
      defaultFilter: v.optional(v.string()),
      notificationsEnabled: v.optional(v.boolean()),
    })),
    createdAt: v.number(),
    updatedAt: v.optional(v.number()),
  })
    .index("by_clerkId", ["clerkId"]),

  // Favorites table - stores user's favorite anime
  favorites: defineTable({
    userId: v.string(),
    animeId: v.number(),
    animeTitle: v.string(),
    animePoster: v.optional(v.string()),
    animeScore: v.optional(v.number()),
    animeType: v.optional(v.string()),
    animeEpisodes: v.optional(v.number()),
    animeGenres: v.optional(v.array(v.string())),
    addedAt: v.number(),
    notes: v.optional(v.string()),
  })
    .index("by_userId", ["userId"])
    .index("by_userId_animeId", ["userId", "animeId"])
    .index("by_addedAt", ["addedAt"]),

  // Watch later table - stores user's watch list with order
  watchLater: defineTable({
    userId: v.string(),
    animeId: v.number(),
    animeTitle: v.string(),
    animePoster: v.optional(v.string()),
    status: v.string(),
    order: v.number(),
    addedAt: v.number(),
    updatedAt: v.optional(v.number()),
  })
    .index("by_userId", ["userId"])
    .index("by_userId_animeId", ["userId", "animeId"])
    .index("by_userId_order", ["userId", "order"]),

  // Comments table - stores user comments on anime with threading support
  comments: defineTable({
    animeId: v.number(),
    userId: v.string(),
    content: v.string(),
    parentCommentId: v.optional(v.id("comments")),
    createdAt: v.number(),
    updatedAt: v.optional(v.number()),
    likes: v.number(),
    likedBy: v.array(v.string()),
  })
    .index("by_animeId", ["animeId"])
    .index("by_userId", ["userId"])
    .index("by_parentCommentId", ["parentCommentId"])
    .index("by_createdAt", ["createdAt"]),

  // Search history table - stores user search queries
  searchHistory: defineTable({
    userId: v.string(),
    query: v.string(),
    filters: v.optional(v.object({
      genre: v.optional(v.string()),
      type: v.optional(v.string()),
      minScore: v.optional(v.number()),
      year: v.optional(v.number()),
      status: v.optional(v.string()),
    })),
    timestamp: v.number(),
    resultCount: v.optional(v.number()),
  })
    .index("by_userId", ["userId"])
    .index("by_userId_timestamp", ["userId", "timestamp"]),

  // Follows table - social feature for following users
  follows: defineTable({
    followerId: v.string(),
    followingId: v.string(),
    createdAt: v.number(),
  })
    .index("by_followerId", ["followerId"])
    .index("by_followingId", ["followingId"])
    .index("by_follower_following", ["followerId", "followingId"]),

  // Blocks table - for blocking users
  blocks: defineTable({
    blockerId: v.string(),
    blockedId: v.string(),
    createdAt: v.number(),
  })
    .index("by_blockerId", ["blockerId"])
    .index("by_blockedId", ["blockedId"])
    .index("by_blocker_blocked", ["blockerId", "blockedId"]),

  // Activity feed table - tracks user actions for feed
  activityFeed: defineTable({
    userId: v.string(),
    actionType: v.string(),
    animeId: v.optional(v.number()),
    animeTitle: v.optional(v.string()),
    details: v.optional(v.string()),
    createdAt: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_createdAt", ["createdAt"])
    .index("by_actionType", ["actionType"]),

  // Share links table - for shareable content
  shareLinks: defineTable({
    userId: v.string(),
    animeId: v.number(),
    shareToken: v.string(),
    createdAt: v.number(),
    expiresAt: v.optional(v.number()),
    views: v.number(),
  })
    .index("by_shareToken", ["shareToken"])
    .index("by_userId", ["userId"])
    .index("by_animeId", ["animeId"]),

  // Anime cache table - for caching Jikan API responses
  animeCache: defineTable({
    animeId: v.number(),
    data: v.any(),
    cachedAt: v.number(),
    expiresAt: v.number(),
  })
    .index("by_animeId", ["animeId"]),
});
