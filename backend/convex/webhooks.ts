import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

// Log webhook
export const logWebhook = mutation({
  args: {
    source: v.union(v.literal("gmail"), v.literal("calendar")),
    payload: v.string(),
    status: v.union(v.literal("success"), v.literal("error")),
    errorMessage: v.optional(v.string()),
    userId: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("webhookLogs", {
      source: args.source,
      payload: args.payload,
      status: args.status,
      errorMessage: args.errorMessage,
      processedAt: Date.now(),
      userId: args.userId,
    });
  },
});

// Get webhook logs
export const getWebhookLogs = query({
  args: {
    source: v.optional(v.union(v.literal("gmail"), v.literal("calendar"))),
    status: v.optional(v.union(v.literal("success"), v.literal("error"))),
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    let query = ctx.db.query("webhookLogs");

    if (args.source) {
      query = query.withIndex("by_source", (q) => q.eq("source", args.source));
    }

    if (args.status) {
      query = query.withIndex("by_status", (q) => q.eq("status", args.status));
    }

    return await query
      .order("desc")
      .take(args.limit || 50);
  },
});

// Get webhook stats
export const getWebhookStats = query({
  args: {
    timeRange: v.optional(v.number()), // milliseconds
  },
  handler: async (ctx, args) => {
    const timeRange = args.timeRange || 24 * 60 * 60 * 1000; // 24 hours default
    const since = Date.now() - timeRange;

    const logs = await ctx.db
      .query("webhookLogs")
      .withIndex("by_processed_at", (q) => q.gte("processedAt", since))
      .collect();

    const stats = {
      total: logs.length,
      success: logs.filter(log => log.status === "success").length,
      error: logs.filter(log => log.status === "error").length,
      bySource: {
        gmail: logs.filter(log => log.source === "gmail").length,
        calendar: logs.filter(log => log.source === "calendar").length,
      },
    };

    return stats;
  },
});

// Clean old webhook logs
export const cleanOldWebhookLogs = mutation({
  args: {
    olderThanDays: v.number(),
  },
  handler: async (ctx, args) => {
    const cutoffTime = Date.now() - (args.olderThanDays * 24 * 60 * 60 * 1000);
    
    const oldLogs = await ctx.db
      .query("webhookLogs")
      .withIndex("by_processed_at", (q) => q.lt("processedAt", cutoffTime))
      .collect();

    let deletedCount = 0;
    for (const log of oldLogs) {
      await ctx.db.delete(log._id);
      deletedCount++;
    }

    return { deletedCount };
  },
});