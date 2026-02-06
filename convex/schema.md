# Convex Schema Documentation

This document describes the Convex functions and schema required for AniSwipe.

## Setup Instructions

1. Create a new Convex project: `npx create convex@latest`
2. Copy the functions below to your `convex/` directory
3. Deploy with `npx convex deploy`

## Directory Structure

```
convex/
  ├── schema.ts          # Database schema
  ├── auth.ts            # Authentication functions
  ├── profiles.ts        # Profile operations
  ├── favorites.ts       # Favorites operations
  ├── watchLater.ts      # Watch later operations
  ├── comments.ts        # Comments operations
  └── utils.ts           # Helper functions
```

## schema.ts

```typescript
// convex/schema.ts
import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  // Profiles table - stores user profile data
  profiles: defineTable({
    userId: v.string(),
    displayName: v.optional(v.string()),
    avatarUrl: v.optional(v.string()),
    createdAt: v.number(),
    updatedAt: v.optional(v.number()),
  })
    .index("by_userId", ["userId"]),

  // Favorites table - stores user's favorite anime
  favorites: defineTable({
    userId: v.string(),
    animeId: v.number(),
    animeTitle: v.string(),
    animePoster: v.optional(v.string()),
    animeScore: v.optional(v.number()),
    animeType: v.optional(v.string()),
    animeEpisodes: v.optional(v.number()),
    createdAt: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_userId_animeId", ["userId", "animeId"]),

  // Watch later table - stores user's watch list
  watchLater: defineTable({
    userId: v.string(),
    animeId: v.number(),
    animeTitle: v.string(),
    animePoster: v.optional(v.string()),
    status: v.string(),
    createdAt: v.number(),
    updatedAt: v.optional(v.number()),
  })
    .index("by_userId", ["userId"])
    .index("by_userId_animeId", ["userId", "animeId"]),

  // Comments table - stores user comments on anime
  comments: defineTable({
    animeId: v.number(),
    userId: v.string(),
    content: v.string(),
    createdAt: v.number(),
  })
    .index("by_animeId", ["animeId"])
    .index("by_userId", ["userId"]),
});
```

## auth.ts

```typescript
// convex/auth.ts
import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// Sign up with email/password
export const signUp = mutation({
  args: {
    email: v.string(),
    password: v.string(),
    displayName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Create user in Clerk (handled by Convex Clerk integration)
    // For now, we'll create a simple user record
    
    const userId = `user_${Date.now()}`;
    const now = Date.now();
    
    // Create profile
    await ctx.db.insert("profiles", {
      userId,
      displayName: args.displayName,
      createdAt: now,
    });
    
    return {
      success: true,
      userId,
      token: `token_${userId}`,
    };
  },
});

// Sign in with email/password
export const signIn = mutation({
  args: {
    email: v.string(),
    password: v.string(),
  },
  handler: async (ctx, args) => {
    // Validate credentials (handled by Clerk in production)
    
    // For demo, create a simple user record
    const userId = `user_${Date.now()}`;
    
    // Create profile if doesn't exist
    const existingProfile = await ctx.db
      .query("profiles")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .first();
    
    if (!existingProfile) {
      await ctx.db.insert("profiles", {
        userId,
        createdAt: Date.now(),
      });
    }
    
    return {
      success: true,
      userId,
      token: `token_${userId}`,
    };
  },
});

// Sign out
export const signOut = mutation({
  args: {},
  handler: async (ctx) => {
    // Clear session (handled by Clerk)
    return { success: true };
  },
});

// Refresh token
export const refreshToken = mutation({
  args: {},
  handler: async (ctx) => {
    return {
      success: true,
      token: `token_refreshed_${Date.now()}`,
    };
  },
});
```

## profiles.ts

```typescript
// convex/profiles.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get user profile
export const getProfile = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("profiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();
  },
});

// Create user profile
export const createProfile = mutation({
  args: {
    userId: v.string(),
    displayName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    
    const profile = await ctx.db.insert("profiles", {
      userId: args.userId,
      displayName: args.displayName,
      createdAt: now,
    });
    
    return profile;
  },
});

// Update user profile
export const updateProfile = mutation({
  args: {
    userId: v.string(),
    displayName: v.optional(v.string()),
    avatarUrl: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("profiles")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .first();
    
    if (!existing) {
      throw new Error("Profile not found");
    }
    
    await ctx.db.patch(existing._id, {
      ...(args.displayName !== undefined && { displayName: args.displayName }),
      ...(args.avatarUrl !== undefined && { avatarUrl: args.avatarUrl }),
      updatedAt: Date.now(),
    });
    
    return { success: true };
  },
});
```

## favorites.ts

```typescript
// convex/favorites.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get all favorites for a user
export const getFavorites = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("favorites")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

// Save a favorite
export const saveFavorite = mutation({
  args: {
    userId: v.string(),
    animeId: v.number(),
    animeTitle: v.string(),
    animePoster: v.optional(v.string()),
    animeScore: v.optional(v.number()),
    animeType: v.optional(v.string()),
    animeEpisodes: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Check if already favorited
    const existing = await ctx.db
      .query("favorites")
      .withIndex("by_userId_animeId", (q) => 
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();
    
    if (existing) {
      return existing;
    }
    
    const favorite = await ctx.db.insert("favorites", {
      userId: args.userId,
      animeId: args.animeId,
      animeTitle: args.animeTitle,
      animePoster: args.animePoster,
      animeScore: args.animeScore,
      animeType: args.animeType,
      animeEpisodes: args.animeEpisodes,
      createdAt: Date.now(),
    });
    
    return favorite;
  },
});

// Delete a favorite
export const deleteFavorite = mutation({
  args: {
    userId: v.string(),
    animeId: v.number(),
  },
  handler: async) => {
    (ctx, args const existing = await ctx.db
      .query("favorites")
      .withIndex("by_userId_animeId", (q) => 
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();
    
    if (existing) {
      await ctx.db.delete(existing._id);
    }
    
    return { success: true };
  },
});

// Check if anime is favorited
export const isFavorite = query({
  args: {
    userId: v.string(),
    animeId: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("favorites")
      .withIndex("by_userId_animeId", (q) => 
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();
    
    return existing !== null;
  },
});
```

## watchLater.ts

```typescript
// convex/watchLater.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get all watch later items for a user
export const getWatchLater = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("watchLater")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

// Add to watch later
export const addToWatchLater = mutation({
  args: {
    userId: v.string(),
    animeId: v.number(),
    animeTitle: v.string(),
    animePoster: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchLater")
      .withIndex("by_userId_animeId", (q) => 
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();
    
    if (existing) {
      return existing;
    }
    
    const item = await ctx.db.insert("watchLater", {
      userId: args.userId,
      animeId: args.animeId,
      animeTitle: args.animeTitle,
      animePoster: args.animePoster,
      status: "planned",
      createdAt: Date.now(),
    });
    
    return item;
  },
});

// Remove from watch later
export const removeFromWatchLater = mutation({
  args: {
    userId: v.string(),
    animeId: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchLater")
      .withIndex("by_userId_animeId", (q) => 
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();
    
    if (existing) {
      await ctx.db.delete(existing._id);
    }
    
    return { success: true };
  },
});

// Check if in watch later
export const isInWatchLater = query({
  args: {
    userId: v.string(),
    animeId: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchLater")
      .withIndex("by_userId_animeId", (q) => 
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();
    
    return existing !== null;
  },
});

// Update watch later status
export const updateWatchLaterStatus = mutation({
  args: {
    userId: v.string(),
    animeId: v.number(),
    status: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchLater")
      .withIndex("by_userId_animeId", (q) => 
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();
    
    if (existing) {
      await ctx.db.patch(existing._id, {
        status: args.status,
        updatedAt: Date.now(),
      });
    }
    
    return { success: true };
  },
});
```

## comments.ts

```typescript
// convex/comments.ts
import { query, mutation } from "./_generated/server";
import { v } from "convex/values";

// Get all comments for an anime
export const getComments = query({
  args: { animeId: v.number() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("comments")
      .withIndex("by_animeId", (q) => q.eq("animeId", args.animeId))
      .collect();
  },
});

// Add a comment
export const addComment = mutation({
  args: {
    animeId: v.number(),
    userId: v.string(),
    content: v.string(),
  },
  handler: async (ctx, args) => {
    const comment = await ctx.db.insert("comments", {
      animeId: args.animeId,
      userId: args.userId,
      content: args.content,
      createdAt: Date.now(),
    });
    
    return comment;
  },
});

// Update a comment
export const updateComment = mutation({
  args: {
    commentId: v.id("comments"),
    content: v.string(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.commentId, {
      content: args.content,
    });
    
    return { success: true };
  },
});

// Delete a comment
export const deleteComment = mutation({
  args: {
    commentId: v.id("comments"),
  },
  handler: async (ctx, args) => {
    await ctx.db.delete(args.commentId);
    return { success: true };
  },
});
```

## Deployment

1. Install Convex CLI: `npm install -g convex`
2. Login: `npx convex login`
3. Initialize: `npx convex dev`
4. Deploy: `npx convex deploy`

## Environment Variables

Set these in your Convex dashboard or `.env.local`:

```
CLERK_PUBLISHABLE_KEY=pk_test_xxx
CLERK_SECRET_KEY=sk_test_xxx
```

## Testing

Run tests with: `npx convex run --watch`
