import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// Get user by email
export const getUserByEmail = query({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();
  },
});

// Get user by AI assistant email
export const getUserByAiEmail = query({
  args: { aiEmail: v.string() },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("users")
      .withIndex("by_ai_assistant_email", (q) => q.eq("aiAssistantEmail", args.aiEmail))
      .first();
  },
});

// Create new user
export const createUser = mutation({
  args: {
    email: v.string(),
    name: v.string(),
    aiAssistantName: v.string(),
    preferences: v.optional(v.object({
      timezone: v.string(),
      workingHours: v.object({
        start: v.string(),
        end: v.string(),
      }),
      bufferTime: v.number(),
      maxMeetingDuration: v.number(),
    })),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const aiAssistantEmail = `${args.aiAssistantName.toLowerCase()}@recloop.com`;

    // Check if user already exists
    const existingUser = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .first();

    if (existingUser) {
      throw new Error("User already exists");
    }

    // Check if AI assistant email is already taken
    const existingAi = await ctx.db
      .query("users")
      .withIndex("by_ai_assistant_email", (q) => q.eq("aiAssistantEmail", aiAssistantEmail))
      .first();

    if (existingAi) {
      throw new Error("AI assistant name already taken");
    }

    return await ctx.db.insert("users", {
      email: args.email,
      name: args.name,
      aiAssistantName: args.aiAssistantName,
      aiAssistantEmail,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      preferences: args.preferences,
    });
  },
});

// Update user preferences
export const updateUserPreferences = mutation({
  args: {
    userId: v.id("users"),
    preferences: v.object({
      timezone: v.string(),
      workingHours: v.object({
        start: v.string(),
        end: v.string(),
      }),
      bufferTime: v.number(),
      maxMeetingDuration: v.number(),
    }),
  },
  handler: async (ctx, args) => {
    return await ctx.db.patch(args.userId, {
      preferences: args.preferences,
      updatedAt: Date.now(),
    });
  },
});

// Deactivate user
export const deactivateUser = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db.patch(args.userId, {
      isActive: false,
      updatedAt: Date.now(),
    });
  },
});

// Get all active users
export const getActiveUsers = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("users")
      .filter((q) => q.eq(q.field("isActive"), true))
      .collect();
  },
});