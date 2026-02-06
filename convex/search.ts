import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const JIKAN_API_BASE = "https://api.jikan.moe/v4";

/**
 * Advanced search functionality with filtering and search history
 */

// Search anime with filters
export const searchAnime = query({
  args: {
    query: v.optional(v.string()),
    page: v.optional(v.number()),
    limit: v.optional(v.number()),
    filters: v.optional(v.object({
      genre: v.optional(v.string()),
      genreExclude: v.optional(v.boolean()),
      type: v.optional(v.string()),
      minScore: v.optional(v.number()),
      maxScore: v.optional(v.number()),
      year: v.optional(v.string()),
      season: v.optional(v.string()),
      status: v.optional(v.string()),
      rating: v.optional(v.string()),
      orderBy: v.optional(v.string()),
      sort: v.optional(v.string()),
    })),
  },
  handler: async (ctx, args) => {
    const params = new URLSearchParams();

    if (args.query) params.set("q", args.query);
    if (args.page) params.set("page", args.page.toString());
    if (args.limit) params.set("limit", args.limit.toString());
    if (args.filters) {
      const f = args.filters;

      if (f.genre) {
        if (f.genreExclude) {
          params.set("genre_exclude", f.genre);
        } else {
          params.set("genre", f.genre);
        }
      }
      if (f.type) params.set("type", f.type);
      if (f.minScore) params.set("min_score", f.minScore.toString());
      if (f.maxScore) params.set("max_score", f.maxScore.toString());
      if (f.year) params.set("year", f.year);
      if (f.season) params.set("season", f.season);
      if (f.status) params.set("status", f.status);
      if (f.rating) params.set("rating", f.rating);
      if (f.orderBy) params.set("order_by", f.orderBy);
      if (f.sort) params.set("sort", f.sort);
    }

    try {
      const response = await fetch(
        `${JIKAN_API_BASE}/anime?${params.toString()}`
      );

      if (!response.ok) {
        throw new Error(`Jikan API error: ${response.status}`);
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error("Error searching anime:", error);
      throw error;
    }
  },
});

// Get available genres
export const getGenres = query({
  args: {},
  handler: async (ctx) => {
    try {
      const response = await fetch(`${JIKAN_API_BASE}/genres/anime`);
      if (!response.ok) {
        throw new Error(`Jikan API error: ${response.status}`);
      }
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error("Error fetching genres:", error);
      return [];
    }
  },
});

// Get anime seasons
export const getSeasons = query({
  args: {
    year: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    try {
      const year = args.year || new Date().getFullYear();
      const response = await fetch(`${JIKAN_API_BASE}/seasons/${year}`);
      if (!response.ok) {
        throw new Error(`Jikan API error: ${response.status}`);
      }
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error("Error fetching seasons:", error);
      return [];
    }
  },
});

// Get upcoming anime
export const getUpcoming = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    try {
      const response = await fetch(
        `${JIKAN_API_BASE}/seasons/upcoming?limit=${args.limit || 20}`
      );
      if (!response.ok) {
        throw new Error(`Jikan API error: ${response.status}`);
      }
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error("Error fetching upcoming anime:", error);
      return [];
    }
  },
});

// Get current season anime
export const getCurrentSeason = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    try {
      const response = await fetch(
        `${JIKAN_API_BASE}/seasons/now?limit=${args.limit || 20}`
      );
      if (!response.ok) {
        throw new Error(`Jikan API error: ${response.status}`);
      }
      const data = await response.json();
      return data.data || [];
    } catch (error) {
      console.error("Error fetching current season:", error);
      return [];
    }
  },
});

// ============================================
// Search History Operations
// ============================================

// Save search to history
export const saveSearchHistory = mutation({
  args: {
    userId: v.string(),
    query: v.string(),
    filters: v.optional(v.object({
      genre: v.optional(v.string()),
      type: v.optional(v.string()),
      minScore: v.optional(v.number()),
      year: v.optional(v.number()),
      status: v.optional(v.string()),
    })),
    resultCount: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const searchId = await ctx.db.insert("searchHistory", {
      userId: args.userId,
      query: args.query,
      filters: args.filters,
      timestamp: Date.now(),
      resultCount: args.resultCount,
    });

    return searchId;
  },
});

// Get user's search history
export const getSearchHistory = query({
  args: {
    userId: v.string(),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const history = await ctx.db
      .query("searchHistory")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    // Sort by timestamp descending
    history.sort((a, b) => b.timestamp - a.timestamp);

    return history.slice(0, args.limit || 20);
  },
});

// Clear user's search history
export const clearSearchHistory = mutation({
  args: { userId: v.string() },
  handler: async (ctx, args) => {
    const history = await ctx.db
      .query("searchHistory")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    for (const item of history) {
      await ctx.db.delete(item._id);
    }

    return { success: true };
  },
});

// Remove single search from history
export const removeSearchHistory = mutation({
  args: {
    userId: v.string(),
    searchId: v.id("searchHistory"),
  },
  handler: async (ctx, args) => {
    const search = await ctx.db.get(args.searchId);

    if (!search || search.userId !== args.userId) {
      throw new Error("Search history item not found");
    }

    await ctx.db.delete(args.searchId);
    return { success: true };
  },
});

// Get popular searches
export const getPopularSearches = query({
  args: {},
  handler: async (ctx) => {
    // In production, this would aggregate search counts
    // For now, return some defaults
    return [
      "Naruto",
      "One Piece",
      "Attack on Titan",
      "Demon Slayer",
      "My Hero Academia",
      "Dragon Ball",
      "Fullmetal Alchemist",
      "Death Note",
      "Tokyo Revengers",
      "Jujutsu Kaisen",
    ];
  },
});

// ============================================
// Advanced Filtering Options
// ============================================

// Get anime types
export const getAnimeTypes = query({
  args: {},
  handler: async (ctx) => {
    return ["tv", "movie", "ova", "ona", "special", "music"];
  },
});

// Get anime statuses
export const getAnimeStatuses = query({
  args: {},
  handler: async (ctx) => {
    return [
      { value: "airing", label: "Airing" },
      { value: "complete", label: "Complete" },
      { value: "upcoming", label: "Upcoming" },
    ];
  },
});

// Get anime ratings
export const getAnimeRatings = query({
  args: {},
  handler: async (ctx) => {
    return ["g", "pg", "pg13", "r17", "r", "rx"];
  },
});

// Get sort options
export const getSortOptions = query({
  args: {},
  handler: async (ctx) => {
    return [
      { value: "mal_id", label: "Default" },
      { value: "title", label: "Title" },
      { value: "start_date", label: "Start Date" },
      { value: "end_date", label: "End Date" },
      { value: "score", label: "Score" },
      { value: "popularity", label: "Popularity" },
      { value: "favorites", label: "Favorites" },
    ];
  },
});
