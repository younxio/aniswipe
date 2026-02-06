import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { getAuthUserId, ActionStatusError } from "./auth";

// ============================================
// Constants
// ============================================

const BLOCK_ALREADY_EXISTS = "BLOCK_ALREADY_EXISTS";
const BLOCK_NOT_FOUND = "BLOCK_NOT_FOUND";
const CANNOT_BLOCK_SELF = "CANNOT_BLOCK_SELF";
const CANNOT_FOLLOW_SELF = "CANNOT_FOLLOW_SELF";
const USER_NOT_FOUND = "USER_NOT_FOUND";
const ALREADY_FOLLOWING = "ALREADY_FOLLOWING";
const NOT_FOLLOWING = "NOT_FOLLOWING";
const SHARE_LINK_NOT_FOUND = "SHARE_LINK_NOT_FOUND";
const UNAUTHORIZED = "UNAUTHORIZED";
const LINK_EXPIRED = "LINK_EXPIRED";
const LINK_NOT_FOUND = "LINK_NOT_FOUND";

const MAX_FOLLOWERS_PER_PAGE = 50;
const MAX_BLOCKS_PER_PAGE = 100;
const MAX_ACTIVITY_PER_PAGE = 50;
const MAX_SHARE_LINKS_PER_PAGE = 50;
const TOKEN_LENGTH = 32;

// ============================================
// Helper Functions
// ============================================

function validateUserId(userId: string): void {
  if (!userId || typeof userId !== "string") {
    throw new Error("Invalid user ID: must be a non-empty string");
  }
  if (userId.length < 10 || userId.length > 100) {
    throw new Error("Invalid user ID: length must be between 10 and 100 characters");
  }
}

function validateAnimeId(animeId: number | undefined): void {
  if (animeId !== undefined && (typeof animeId !== "number" || animeId <= 0)) {
    throw new Error("Invalid anime ID: must be a positive number");
  }
}

function validateContent(content: string | undefined, maxLength: number = 1000): void {
  if (content !== undefined && (typeof content !== "string" || content.length > maxLength)) {
    throw new Error(`Invalid content: must be a string with max ${maxLength} characters`);
  }
}

async function getUserByClerkId(ctx: any, clerkId: string): Promise<any> {
  return await ctx.db
    .query("users")
    .withIndex("by_clerkId", (q: any) => q.eq("clerkId", clerkId))
    .first();
}

// Polyfill for crypto.getRandomValues if not available
const cryptoObj = typeof globalThis.crypto !== 'undefined' 
  ? globalThis.crypto 
  : {
      getRandomValues: (buffer: Uint8Array) => {
        for (let i = 0; i < buffer.length; i++) {
          buffer[i] = Math.floor(Math.random() * 256);
        }
        return buffer;
      }
    };

// ============================================
// Follow System
// ============================================

export const followUser = mutation({
  args: {
    targetUserId: v.string(),
  },
  handler: async (ctx: any, args: { targetUserId: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateUserId(args.targetUserId);
    
    if (requesterId === args.targetUserId) {
      throw new ActionStatusError(CANNOT_FOLLOW_SELF, "Cannot follow yourself");
    }

    // Check if target user exists
    const targetUser = await getUserByClerkId(ctx, args.targetUserId);
    if (!targetUser) {
      throw new ActionStatusError(USER_NOT_FOUND, "User not found");
    }

    // Check if already following
    const existingFollow = await ctx.db
      .query("follows")
      .withIndex("by_follower_following", (q: any) =>
        q.eq("followerId", requesterId).eq("followingId", args.targetUserId)
      )
      .first();
    
    if (existingFollow) {
      throw new ActionStatusError(ALREADY_FOLLOWING, "Already following this user");
    }

    // Check if blocked by target
    const blockedByTarget = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q: any) =>
        q.eq("blockerId", args.targetUserId).eq("blockedId", requesterId)
      )
      .first();
    
    if (blockedByTarget) {
      throw new ActionStatusError("BLOCKED_BY_USER", "Cannot follow: you are blocked by this user");
    }

    // Create follow
    const followId = await ctx.db.insert("follows", {
      followerId: requesterId,
      followingId: args.targetUserId,
      createdAt: Date.now(),
    });

    // Record activity
    await ctx.db.insert("activityFeed", {
      userId: requesterId,
      actionType: "follow",
      animeId: undefined,
      animeTitle: undefined,
      details: args.targetUserId,
      createdAt: Date.now(),
    });

    return { success: true, followId };
  },
});

export const unfollowUser = mutation({
  args: {
    targetUserId: v.string(),
  },
  handler: async (ctx: any, args: { targetUserId: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateUserId(args.targetUserId);

    const existingFollow = await ctx.db
      .query("follows")
      .withIndex("by_follower_following", (q: any) =>
        q.eq("followerId", requesterId).eq("followingId", args.targetUserId)
      )
      .first();

    if (!existingFollow) {
      throw new ActionStatusError(NOT_FOLLOWING, "Not following this user");
    }

    await ctx.db.delete(existingFollow._id);
    return { success: true };
  },
});

export const getFollowers = query({
  args: {
    userId: v.string(),
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx: any, args: { userId: string; cursor?: string; limit?: number }) => {
    validateUserId(args.userId);
    const pageSize = Math.min(args.limit ?? MAX_FOLLOWERS_PER_PAGE, MAX_FOLLOWERS_PER_PAGE);

    let followersQuery = ctx.db
      .query("follows")
      .withIndex("by_followingId", (q: any) => q.eq("followingId", args.userId));

    const followers = await followersQuery.collect(pageSize + 1);
    const hasMore = followers.length > pageSize;
    const paginatedFollowers = hasMore ? followers.slice(0, pageSize) : followers;

    // Batch fetch user details
    const followerIds = paginatedFollowers.map((f: any) => f.followerId);
    const users = await Promise.all(
      followerIds.map((id: string) => 
        ctx.db
          .query("users")
          .withIndex("by_clerkId", (q: any) => q.eq("clerkId", id))
          .first()
      )
    );

    const userMap = new Map(
      users.filter((u): u is any => u !== null).map((u) => [u.clerkId, u])
    );

    return {
      followers: paginatedFollowers.map((follow: any) => ({
        _id: follow._id,
        followerId: follow.followerId,
        createdAt: follow.createdAt,
        user: userMap.get(follow.followerId)
          ? {
              clerkId: userMap.get(follow.followerId)!.clerkId,
              displayName: userMap.get(follow.followerId)!.displayName,
              avatarUrl: userMap.get(follow.followerId)!.avatarUrl,
            }
          : null,
      })),
      nextCursor: hasMore && paginatedFollowers.length > 0 ? String(paginatedFollowers[pageSize - 1]._id) : undefined,
    };
  },
});

export const getFollowing = query({
  args: {
    userId: v.string(),
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx: any, args: { userId: string; cursor?: string; limit?: number }) => {
    validateUserId(args.userId);
    const pageSize = Math.min(args.limit ?? MAX_FOLLOWERS_PER_PAGE, MAX_FOLLOWERS_PER_PAGE);

    let followingQuery = ctx.db
      .query("follows")
      .withIndex("by_followerId", (q: any) => q.eq("followerId", args.userId));

    const following = await followingQuery.collect(pageSize + 1);
    const hasMore = following.length > pageSize;
    const paginatedFollowing = hasMore ? following.slice(0, pageSize) : following;

    // Batch fetch user details
    const followingIds = paginatedFollowing.map((f: any) => f.followingId);
    const users = await Promise.all(
      followingIds.map((id: string) =>
        ctx.db
          .query("users")
          .withIndex("by_clerkId", (q: any) => q.eq("clerkId", id))
          .first()
      )
    );

    const userMap = new Map(
      users.filter((u): u is any => u !== null).map((u) => [u.clerkId, u])
    );

    return {
      following: paginatedFollowing.map((follow: any) => ({
        _id: follow._id,
        followingId: follow.followingId,
        createdAt: follow.createdAt,
        user: userMap.get(follow.followingId)
          ? {
              clerkId: userMap.get(follow.followingId)!.clerkId,
              displayName: userMap.get(follow.followingId)!.displayName,
              avatarUrl: userMap.get(follow.followingId)!.avatarUrl,
            }
          : null,
      })),
      nextCursor: hasMore && paginatedFollowing.length > 0 ? String(paginatedFollowing[pageSize - 1]._id) : undefined,
    };
  },
});

export const isFollowing = query({
  args: {
    targetUserId: v.string(),
  },
  handler: async (ctx: any, args: { targetUserId: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateUserId(args.targetUserId);

    const existing = await ctx.db
      .query("follows")
      .withIndex("by_follower_following", (q: any) =>
        q.eq("followerId", requesterId).eq("followingId", args.targetUserId)
      )
      .first();

    return { isFollowing: existing !== null };
  },
});

export const getFollowerCount = query({
  args: { userId: v.string() },
  handler: async (ctx: any, args: { userId: string }) => {
    validateUserId(args.userId);
    const followers = await ctx.db
      .query("follows")
      .withIndex("by_followingId", (q: any) => q.eq("followingId", args.userId))
      .collect();
    return { count: followers.length };
  },
});

export const getFollowingCount = query({
  args: { userId: v.string() },
  handler: async (ctx: any, args: { userId: string }) => {
    validateUserId(args.userId);
    const following = await ctx.db
      .query("follows")
      .withIndex("by_followerId", (q: any) => q.eq("followerId", args.userId))
      .collect();
    return { count: following.length };
  },
});

// ============================================
// Block System
// ============================================

export const blockUser = mutation({
  args: {
    targetUserId: v.string(),
  },
  handler: async (ctx: any, args: { targetUserId: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateUserId(args.targetUserId);

    if (requesterId === args.targetUserId) {
      throw new ActionStatusError(CANNOT_BLOCK_SELF, "Cannot block yourself");
    }

    // Check if target user exists
    const targetUser = await getUserByClerkId(ctx, args.targetUserId);
    if (!targetUser) {
      throw new ActionStatusError(USER_NOT_FOUND, "User not found");
    }

    // Check if already blocking
    const existingBlock = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q: any) =>
        q.eq("blockerId", requesterId).eq("blockedId", args.targetUserId)
      )
      .first();

    if (existingBlock) {
      throw new ActionStatusError(BLOCK_ALREADY_EXISTS, "Already blocking this user");
    }

    // Create block
    const blockId = await ctx.db.insert("blocks", {
      blockerId: requesterId,
      blockedId: args.targetUserId,
      createdAt: Date.now(),
    });

    // Remove follow relationships (both directions)
    const followToRemove = await ctx.db
      .query("follows")
      .withIndex("by_follower_following", (q: any) =>
        q.eq("followerId", requesterId).eq("followingId", args.targetUserId)
      )
      .first();

    if (followToRemove) {
      await ctx.db.delete(followToRemove._id);
    }

    const followerToRemove = await ctx.db
      .query("follows")
      .withIndex("by_follower_following", (q: any) =>
        q.eq("followerId", args.targetUserId).eq("followingId", requesterId)
      )
      .first();

    if (followerToRemove) {
      await ctx.db.delete(followerToRemove._id);
    }

    // Get updated block list
    const allBlocks = await ctx.db
      .query("blocks")
      .withIndex("by_blockerId", (q: any) => q.eq("blockerId", requesterId))
      .collect();

    const blockedUserIds = allBlocks.map((b: any) => b.blockedId);

    // Record activity
    await ctx.db.insert("activityFeed", {
      userId: requesterId,
      actionType: "block",
      animeId: undefined,
      animeTitle: undefined,
      details: args.targetUserId,
      createdAt: Date.now(),
    });

    return {
      success: true,
      blockId,
      blockedUserIds,
      message: `Successfully blocked ${targetUser.displayName || args.targetUserId}`,
    };
  },
});

export const unblockUser = mutation({
  args: {
    targetUserId: v.string(),
  },
  handler: async (ctx: any, args: { targetUserId: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateUserId(args.targetUserId);

    if (requesterId === args.targetUserId) {
      throw new ActionStatusError("INVALID_OPERATION", "Cannot unblock yourself");
    }

    const existingBlock = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q: any) =>
        q.eq("blockerId", requesterId).eq("blockedId", args.targetUserId)
      )
      .first();

    if (!existingBlock) {
      throw new ActionStatusError(BLOCK_NOT_FOUND, "Not blocking this user");
    }

    const targetUser = await getUserByClerkId(ctx, args.targetUserId);
    await ctx.db.delete(existingBlock._id);

    // Get updated block list
    const allBlocks = await ctx.db
      .query("blocks")
      .withIndex("by_blockerId", (q: any) => q.eq("blockerId", requesterId))
      .collect();

    const blockedUserIds = allBlocks.map((b: any) => b.blockedId);

    // Record activity
    await ctx.db.insert("activityFeed", {
      userId: requesterId,
      actionType: "unblock",
      animeId: undefined,
      animeTitle: undefined,
      details: args.targetUserId,
      createdAt: Date.now(),
    });

    return {
      success: true,
      blockedUserIds,
      message: `Successfully unblocked ${targetUser?.displayName || args.targetUserId}`,
    };
  },
});

export const getBlockedUsers = query({
  args: {
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx: any, args: { cursor?: string; limit?: number }) => {
    const requesterId = await getAuthUserId(ctx);
    const pageSize = Math.min(args.limit ?? MAX_BLOCKS_PER_PAGE, MAX_BLOCKS_PER_PAGE);

    let blocksQuery = ctx.db
      .query("blocks")
      .withIndex("by_blockerId", (q: any) => q.eq("blockerId", requesterId));

    const blocks = await blocksQuery.collect(pageSize + 1);
    const hasMore = blocks.length > pageSize;
    const paginatedBlocks = hasMore ? blocks.slice(0, pageSize) : blocks;

    // Batch fetch user details
    const blockedUserIds = paginatedBlocks.map((b: any) => b.blockedId);
    const users = await Promise.all(
      blockedUserIds.map((userId: string) =>
        ctx.db
          .query("users")
          .withIndex("by_clerkId", (q: any) => q.eq("clerkId", userId))
          .first()
      )
    );

    const userMap = new Map(
      users.filter((u): u is any => u !== null).map((u) => [u.clerkId, u])
    );

    return {
      blockedUsers: paginatedBlocks.map((block: any) => ({
        blockId: block._id,
        blockedId: block.blockedId,
        createdAt: block.createdAt,
        user: userMap.get(block.blockedId)
          ? {
              clerkId: userMap.get(block.blockedId)!.clerkId,
              displayName: userMap.get(block.blockedId)!.displayName,
              avatarUrl: userMap.get(block.blockedId)!.avatarUrl,
            }
          : null,
      })),
      nextCursor: hasMore && paginatedBlocks.length > 0 ? String(paginatedBlocks[pageSize - 1]._id) : undefined,
      totalCount: blocks.length,
    };
  },
});

export const isBlocked = query({
  args: {
    targetUserId: v.string(),
  },
  handler: async (ctx: any, args: { targetUserId: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateUserId(args.targetUserId);

    const blocked = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q: any) =>
        q.eq("blockerId", requesterId).eq("blockedId", args.targetUserId)
      )
      .first();

    const blockedBy = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q: any) =>
        q.eq("blockerId", args.targetUserId).eq("blockedId", requesterId)
      )
      .first();

    return {
      isBlocked: blocked !== null,
      isBlockedBy: blockedBy !== null,
      relationship: blocked !== null
        ? "blocked"
        : blockedBy !== null
        ? "blocked_by"
        : "none",
    };
  },
});

export const canInteract = query({
  args: {
    targetUserId: v.string(),
  },
  handler: async (ctx: any, args: { targetUserId: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateUserId(args.targetUserId);

    // Check if blocked by target
    const blockedBy = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q: any) =>
        q.eq("blockerId", args.targetUserId).eq("blockedId", requesterId)
      )
      .first();

    if (blockedBy) {
      return {
        allowed: false,
        reason: "You are blocked by this user",
        code: "BLOCKED_BY_USER",
      };
    }

    // Check if we blocked target
    const blocked = await ctx.db
      .query("blocks")
      .withIndex("by_blocker_blocked", (q: any) =>
        q.eq("blockerId", requesterId).eq("blockedId", args.targetUserId)
      )
      .first();

    if (blocked) {
      return {
        allowed: false,
        reason: "You have blocked this user",
        code: "USER_BLOCKED",
      };
    }

    return { allowed: true, reason: null, code: "ALLOWED" };
  },
});

// ============================================
// Activity Feed
// ============================================

export const addActivity = mutation({
  args: {
    actionType: v.string(),
    animeId: v.optional(v.number()),
    animeTitle: v.optional(v.string()),
    details: v.optional(v.string()),
  },
  handler: async (ctx: any, args: { actionType: string; animeId?: number; animeTitle?: string; details?: string }) => {
    const requesterId = await getAuthUserId(ctx);
    validateAnimeId(args.animeId);
    validateContent(args.details, 255);

    const activityId = await ctx.db.insert("activityFeed", {
      userId: requesterId,
      actionType: args.actionType,
      animeId: args.animeId,
      animeTitle: args.animeTitle,
      details: args.details,
      createdAt: Date.now(),
    });

    return activityId;
  },
});

export const getActivityFeed = query({
  args: {
    cursor: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx: any, args: { cursor?: number; limit?: number }) => {
    const requesterId = await getAuthUserId(ctx);
    const pageSize = Math.min(args.limit ?? MAX_ACTIVITY_PER_PAGE, MAX_ACTIVITY_PER_PAGE);

    // Get following list
    const following = await ctx.db
      .query("follows")
      .withIndex("by_followerId", (q: any) => q.eq("followerId", requesterId))
      .collect();

    const followingIds = new Set(following.map((f: any) => f.followingId));
    followingIds.add(requesterId);

    // Get blocked users
    const blocks = await ctx.db
      .query("blocks")
      .withIndex("by_blockerId", (q: any) => q.eq("blockerId", requesterId))
      .collect();

    const blockedIds = new Set(blocks.map((b: any) => b.blockedId));

    // Get users who blocked me
    const blockedBy = await ctx.db
      .query("blocks")
      .withIndex("by_blockedId", (q: any) => q.eq("blockedId", requesterId))
      .collect();

    const blockedByIds = new Set(blockedBy.map((b: any) => b.blockerId));

    // Query activities from followed users
    let allActivities: any[] = [];
    for (const followedId of followingIds) {
      const activities = await ctx.db
        .query("activityFeed")
        .withIndex("by_userId", (q: any) => q.eq("userId", followedId))
        .collect(pageSize);
      allActivities = allActivities.concat(activities);
    }

    // Filter and sort
    const activities = allActivities
      .filter((a: any) => {
        if (!followingIds.has(a.userId)) return false;
        if (blockedIds.has(a.userId)) return false;
        if (blockedByIds.has(a.userId)) return false;
        return true;
      })
      .sort((a: any, b: any) => b.createdAt - a.createdAt)
      .slice(0, pageSize);

    const hasMore = activities.length >= pageSize;

    // Batch fetch user details
    const userIds = [...new Set(activities.map((a: any) => a.userId))];
    const users = await Promise.all(
      userIds.map((userId: string) =>
        ctx.db
          .query("users")
          .withIndex("by_clerkId", (q: any) => q.eq("clerkId", userId))
          .first()
      )
    );

    const userMap = new Map(
      users.filter((u): u is any => u !== null).map((u) => [u.clerkId, u])
    );

    return {
      activities: activities.map((activity: any) => ({
        _id: activity._id,
        userId: activity.userId,
        actionType: activity.actionType,
        animeId: activity.animeId,
        animeTitle: activity.animeTitle,
        details: activity.details,
        createdAt: activity.createdAt,
        user: userMap.get(activity.userId)
          ? {
              clerkId: userMap.get(activity.userId)!.clerkId,
              displayName: userMap.get(activity.userId)!.displayName,
              avatarUrl: userMap.get(activity.userId)!.avatarUrl,
            }
          : null,
      })),
      nextCursor: hasMore && activities.length > 0 ? activities[activities.length - 1].createdAt : undefined,
    };
  },
});

export const getUserActivity = query({
  args: {
    targetUserId: v.string(),
    cursor: v.optional(v.number()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx: any, args: { targetUserId: string; cursor?: number; limit?: number }) => {
    validateUserId(args.targetUserId);
    const pageSize = Math.min(args.limit ?? MAX_ACTIVITY_PER_PAGE, MAX_ACTIVITY_PER_PAGE);

    let activitiesQuery = ctx.db
      .query("activityFeed")
      .withIndex("by_userId", (q: any) => q.eq("userId", args.targetUserId));

    const allActivities = await activitiesQuery.collect(pageSize + 1);
    const hasMore = allActivities.length > pageSize;
    const activities = hasMore ? allActivities.slice(0, pageSize) : allActivities;

    return {
      activities: activities,
      nextCursor: hasMore && activities.length > 0 ? activities[activities.length - 1].createdAt : undefined,
    };
  },
});

// ============================================
// Share Functionality
// ============================================

export const createShareLink = mutation({
  args: {
    animeId: v.number(),
    expiresInDays: v.optional(v.number()),
  },
  handler: async (ctx: any, args: { animeId: number; expiresInDays?: number }) => {
    const requesterId = await getAuthUserId(ctx);
    validateAnimeId(args.animeId);

    if (args.animeId <= 0) {
      throw new Error("Invalid anime ID: must be a positive number");
    }

    // Generate token using crypto.getRandomValues
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    const randomValues = new Uint8Array(TOKEN_LENGTH);
    cryptoObj.getRandomValues(randomValues);
    
    let token = "";
    for (let i = 0; i < TOKEN_LENGTH; i++) {
      token += chars.charAt(randomValues[i] % chars.length);
    }

    // Check for collision
    const existing = await ctx.db
      .query("shareLinks")
      .withIndex("by_shareToken", (q: any) => q.eq("shareToken", token))
      .first();

    if (existing) {
      throw new Error("Failed to generate unique token");
    }

    const expiresAt = args.expiresInDays !== undefined
      ? Date.now() + args.expiresInDays * 24 * 60 * 60 * 1000
      : undefined;

    const shareId = await ctx.db.insert("shareLinks", {
      userId: requesterId,
      animeId: args.animeId,
      shareToken: token,
      createdAt: Date.now(),
      expiresAt,
      views: 0,
    });

    return {
      success: true,
      shareId,
      token,
      url: `https://aniswipe.app/share/${token}`,
      expiresAt,
    };
  },
});

export const getShareLink = query({
  args: { token: v.string() },
  handler: async (ctx: any, args: { token: string }) => {
    if (!args.token || args.token.length !== TOKEN_LENGTH) {
      return { error: "Invalid token", code: "INVALID_TOKEN" };
    }

    const shareLink = await ctx.db
      .query("shareLinks")
      .withIndex("by_shareToken", (q: any) => q.eq("shareToken", args.token))
      .first();

    if (!shareLink) {
      return { error: "Link not found", code: "NOT_FOUND" };
    }

    const isExpired = shareLink.expiresAt !== undefined && shareLink.expiresAt < Date.now();
    if (isExpired) {
      return { error: "Link expired", code: "EXPIRED", expired: true, expiredAt: shareLink.expiresAt };
    }

    // Get creator info
    const creator = await getUserByClerkId(ctx, shareLink.userId);

    return {
      _id: shareLink._id,
      animeId: shareLink.animeId,
      shareToken: shareLink.shareToken,
      createdAt: shareLink.createdAt,
      expiresAt: shareLink.expiresAt,
      views: shareLink.views,
      creator: creator
        ? {
            clerkId: creator.clerkId,
            displayName: creator.displayName,
            avatarUrl: creator.avatarUrl,
          }
        : null,
      expired: false,
    };
  },
});

export const incrementShareView = mutation({
  args: { shareId: v.id("shareLinks") },
  handler: async (ctx: any, args: { shareId: any }) => {
    await getAuthUserId(ctx);

    const shareLink = await ctx.db.get(args.shareId);
    if (!shareLink) {
      throw new ActionStatusError(SHARE_LINK_NOT_FOUND, "Share link not found");
    }

    await ctx.db.patch(args.shareId, { views: (shareLink.views ?? 0) + 1 });
    return { success: true };
  },
});

export const getUserShareLinks = query({
  args: {
    cursor: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  handler: async (ctx: any, args: { cursor?: string; limit?: number }) => {
    const requesterId = await getAuthUserId(ctx);
    const pageSize = Math.min(args.limit ?? MAX_SHARE_LINKS_PER_PAGE, MAX_SHARE_LINKS_PER_PAGE);

    let shareLinksQuery = ctx.db
      .query("shareLinks")
      .withIndex("by_userId", (q: any) => q.eq("userId", requesterId));

    const shareLinks = await shareLinksQuery.collect(pageSize + 1);
    const hasMore = shareLinks.length > pageSize;
    const paginatedLinks = hasMore ? shareLinks.slice(0, pageSize) : shareLinks;

    return {
      shareLinks: paginatedLinks.map((link: any) => ({
        _id: link._id,
        animeId: link.animeId,
        shareToken: link.shareToken,
        createdAt: link.createdAt,
        expiresAt: link.expiresAt,
        views: link.views,
        isExpired: link.expiresAt !== undefined && link.expiresAt < Date.now(),
      })),
      nextCursor: hasMore && paginatedLinks.length > 0 ? String(paginatedLinks[pageSize - 1]._id) : undefined,
    };
  },
});

export const deleteShareLink = mutation({
  args: { shareId: v.id("shareLinks") },
  handler: async (ctx: any, args: { shareId: any }) => {
    const requesterId = await getAuthUserId(ctx);

    const shareLink = await ctx.db.get(args.shareId);
    if (!shareLink) {
      throw new ActionStatusError(SHARE_LINK_NOT_FOUND, "Share link not found");
    }

    if (shareLink.userId !== requesterId) {
      throw new ActionStatusError(UNAUTHORIZED, "You can only delete your own share links");
    }

    await ctx.db.delete(args.shareId);
    return { success: true };
  },
});

// ============================================
// Cleanup Functions (for maintenance)
// ============================================

export const cleanupExpiredLinks = mutation({
  args: {},
  handler: async (ctx: any) => {
    const requesterId = await getAuthUserId(ctx);
    
    // Only allow cleanup via server/automation (check for special role)
    // This is a placeholder - in production, implement proper role-based access
    
    const expiredLinks = await ctx.db
      .query("shareLinks")
      .filter((q: any) => q.lt(q.field("expiresAt"), Date.now()))
      .collect();

    let deletedCount = 0;
    for (const link of expiredLinks) {
      await ctx.db.delete(link._id);
      deletedCount++;
    }

    return { deletedCount };
  },
});
