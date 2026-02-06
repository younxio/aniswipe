import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const JIKAN_API_BASE = "https://api.jikan.moe/v4";

/**
 * Anime management functions
 * Handles fetching anime from Jikan API, caching, favorites, and watch later
 */

// Fetch anime from Jikan API with caching
// Note: Changed to mutation because it writes to cache
export const fetchAnime = mutation({
  args: {
    page: v.optional(v.number()),
    limit: v.optional(v.number()),
    q: v.optional(v.string()),
    genre: v.optional(v.string()),
    type: v.optional(v.string()),
    minScore: v.optional(v.number()),
    year: v.optional(v.number()),
    status: v.optional(v.string()),
    orderBy: v.optional(v.string()),
    sort: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Build query parameters
    const params = new URLSearchParams();
    if (args.page) params.set("page", args.page.toString());
    if (args.limit) params.set("limit", args.limit.toString());
    if (args.q) params.set("q", args.q);
    if (args.genre) params.set("genre", args.genre);
    if (args.type) params.set("type", args.type);
    if (args.minScore) params.set("min_score", args.minScore.toString());
    if (args.year) params.set("year", args.year.toString());
    if (args.status) params.set("status", args.status);
    if (args.orderBy) params.set("order_by", args.orderBy);
    if (args.sort) params.set("sort", args.sort);

    const url = `${JIKAN_API_BASE}/anime?${params.toString()}`;

    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`Jikan API error: ${response.status}`);
      }
      const data = await response.json();
      return data;
    } catch (error) {
      console.error("Error fetching anime:", error);
      throw error;
    }
  },
});

// Fetch anime details by ID with caching
// Note: Changed to mutation because it writes to cache
export const getAnimeDetails = mutation({
  args: { animeId: v.number() },
  handler: async (ctx, args) => {
    // Check cache first
    const cached = await ctx.db
      .query("animeCache")
      .withIndex("by_animeId", (q) => q.eq("animeId", args.animeId))
      .first();

    if (cached && cached.expiresAt > Date.now()) {
      return { cached: true, data: cached.data };
    }

    // Fetch from Jikan API
    try {
      const response = await fetch(`${JIKAN_API_BASE}/anime/${args.animeId}`);
      if (!response.ok) {
        throw new Error(`Jikan API error: ${response.status}`);
      }
      const data = await response.json();

      // Cache the response for 1 hour
      await ctx.db.insert("animeCache", {
        animeId: args.animeId,
        data,
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60 * 60 * 1000, // 1 hour
      });

      return { cached: false, data };
    } catch (error) {
      console.error("Error fetching anime details:", error);
      throw error;
    }
  },
});

// Fetch anime recommendations based on user's favorites
export const getRecommendations = query({
  args: {
    userId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    // Get user's favorite genres from favorites
    const favorites = await ctx.db
      .query("favorites")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    if (favorites.length === 0) {
      // Return popular anime if no favorites
      const response = await fetch(
        `${JIKAN_API_BASE}/anime?order_by=rating&sort=desc&limit=${args.limit || 10}`
      );
      const data = await response.json();
      return data.data || [];
    }

    // Get most common genres from favorites
    const genreCounts: Record<string, number> = {};
    for (const fav of favorites) {
      if (fav.animeGenres) {
        for (const genre of fav.animeGenres) {
          genreCounts[genre] = (genreCounts[genre] || 0) + 1;
        }
      }
    }

    // Get top genres
    const topGenres = Object.entries(genreCounts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([genre]) => genre);

    // Fetch anime with these genres
    const genreParam = topGenres.join(",");
    const response = await fetch(
      `${JIKAN_API_BASE}/anime?genres=${genreParam}&order_by=score&sort=desc&limit=${args.limit || 20}`
    );
    const data = await response.json();

    // Filter out already favorited anime
    const favoritedIds = new Set(favorites.map((f) => f.animeId));
    const recommendations = (data.data || []).filter(
      (anime: any) => !favoritedIds.has(anime.mal_id)
    );

    return recommendations.slice(0, args.limit || 10);
  },
});

// Get similar anime
export const getSimilarAnime = query({
  args: {
    animeId: v.number(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    try {
      const response = await fetch(
        `${JIKAN_API_BASE}/anime/${args.animeId}/recommendations`
      );
      const data = await response.json();
      return (data.data || []).slice(0, args.limit || 10);
    } catch (error) {
      console.error("Error fetching similar anime:", error);
      return [];
    }
  },
});

// ============================================
// Favorites Operations
// ============================================

// Add anime to favorites
export const addFavorite = mutation({
  args: {
    userId: v.string(),
    anime: v.object({
      malId: v.number(),
      title: v.string(),
      imageUrl: v.optional(v.string()),
      score: v.optional(v.number()),
      type: v.optional(v.string()),
      episodes: v.optional(v.number()),
      genres: v.optional(v.array(v.string())),
    }),
    notes: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    // Check if already favorited
    const existing = await ctx.db
      .query("favorites")
      .withIndex("by_userId_animeId", (q) =>
        q.eq("userId", args.userId).eq("animeId", args.anime.malId)
      )
      .first();

    if (existing) {
      throw new Error("Anime already in favorites");
    }

    // Add to favorites
    const favoriteId = await ctx.db.insert("favorites", {
      userId: args.userId,
      animeId: args.anime.malId,
      animeTitle: args.anime.title,
      animePoster: args.anime.imageUrl,
      animeScore: args.anime.score,
      animeType: args.anime.type,
      animeEpisodes: args.anime.episodes,
      animeGenres: args.anime.genres,
      addedAt: Date.now(),
      notes: args.notes,
    });

    // Add to activity feed
    await ctx.db.insert("activityFeed", {
      userId: args.userId,
      actionType: "favorite",
      animeId: args.anime.malId,
      animeTitle: args.anime.title,
      createdAt: Date.now(),
    });

    return favoriteId;
  },
});

// Remove from favorites
export const removeFavorite = mutation({
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

    if (!existing) {
      throw new Error("Favorite not found");
    }

    await ctx.db.delete(existing._id);
    return { success: true };
  },
});

// Get all favorites
export const getFavorites = query({
  args: {
    userId: v.string(),
    limit: v.optional(v.number()),
    cursor: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const favorites = await ctx.db
      .query("favorites")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    // Sort by addedAt descending
    favorites.sort((a, b) => b.addedAt - a.addedAt);

    return favorites;
  },
});

// Check if anime is favorited
export const isFavorited = query({
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

// ============================================
// Watch Later Operations
// ============================================

// Add to watch later
export const addToWatchLater = mutation({
  args: {
    userId: v.string(),
    anime: v.object({
      malId: v.number(),
      title: v.string(),
      imageUrl: v.optional(v.string()),
    }),
  },
  handler: async (ctx, args) => {
    // Check if already in watch later
    const existing = await ctx.db
      .query("watchLater")
      .withIndex("by_userId_animeId", (q) =>
        q.eq("userId", args.userId).eq("animeId", args.anime.malId)
      )
      .first();

    if (existing) {
      throw new Error("Anime already in watch later");
    }

    // Get the highest order to append to end
    const allWatchLater = await ctx.db
      .query("watchLater")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    const maxOrder = allWatchLater.reduce(
      (max, item) => Math.max(max, item.order),
      -1
    );

    const watchLaterId = await ctx.db.insert("watchLater", {
      userId: args.userId,
      animeId: args.anime.malId,
      animeTitle: args.anime.title,
      animePoster: args.anime.imageUrl,
      status: "planned",
      order: maxOrder + 1,
      addedAt: Date.now(),
    });

    return watchLaterId;
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

    if (!existing) {
      throw new Error("Watch later item not found");
    }

    await ctx.db.delete(existing._id);
    return { success: true };
  },
});

// Reorder watch later
export const reorderWatchLater = mutation({
  args: {
    userId: v.string(),
    animeId: v.number(),
    newOrder: v.number(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("watchLater")
      .withIndex("by_userId_animeId", (q) =>
        q.eq("userId", args.userId).eq("animeId", args.animeId)
      )
      .first();

    if (!existing) {
      throw new Error("Watch later item not found");
    }

    await ctx.db.patch(existing._id, {
      order: args.newOrder,
      updatedAt: Date.now(),
    });

    return { success: true };
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

    if (!existing) {
      throw new Error("Watch later item not found");
    }

    await ctx.db.patch(existing._id, {
      status: args.status,
      updatedAt: Date.now(),
    });

    return { success: true };
  },
});

// Get watch later list
export const getWatchLater = query({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    const watchLater = await ctx.db
      .query("watchLater")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    // Sort by order
    watchLater.sort((a, b) => a.order - b.order);

    return watchLater;
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
