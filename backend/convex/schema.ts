import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    email: v.string(),
    name: v.string(),
    aiAssistantName: v.string(), // e.g., "nick", "sana"
    aiAssistantEmail: v.string(), // e.g., "nick@recloop.com"
    isActive: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
    preferences: v.optional(v.object({
      timezone: v.string(),
      workingHours: v.object({
        start: v.string(),
        end: v.string(),
      }),
      bufferTime: v.number(), // minutes
      maxMeetingDuration: v.number(), // minutes
    })),
  })
    .index("by_email", ["email"])
    .index("by_ai_assistant_email", ["aiAssistantEmail"]),

  gmailTokens: defineTable({
    userId: v.id("users"),
    accessToken: v.string(),
    refreshToken: v.string(),
    expiresAt: v.number(),
    scope: v.string(),
    email: v.string(),
    isActive: v.boolean(),
    lastRefreshed: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_email", ["email"]),

  calendarTokens: defineTable({
    userId: v.id("users"),
    accessToken: v.string(),
    refreshToken: v.string(),
    expiresAt: v.number(),
    calendarId: v.string(),
    email: v.string(),
    isActive: v.boolean(),
    lastRefreshed: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_email", ["email"]),

  emailThreads: defineTable({
    userId: v.id("users"),
    threadId: v.string(),
    messageId: v.string(),
    subject: v.string(),
    participants: v.array(v.string()),
    status: v.union(
      v.literal("pending"),
      v.literal("processing"),
      v.literal("scheduled"),
      v.literal("failed"),
      v.literal("ignored")
    ),
    aiResponse: v.optional(v.string()),
    scheduledEventId: v.optional(v.string()),
    createdAt: v.number(),
    updatedAt: v.number(),
    metadata: v.optional(v.object({
      originalMessage: v.string(),
      extractedInfo: v.optional(v.object({
        proposedTimes: v.array(v.string()),
        duration: v.optional(v.number()),
        location: v.optional(v.string()),
        meetingType: v.optional(v.string()),
      })),
    })),
  })
    .index("by_user", ["userId"])
    .index("by_thread", ["threadId"])
    .index("by_status", ["status"]),

  scheduledEvents: defineTable({
    userId: v.id("users"),
    threadId: v.string(),
    eventId: v.string(), // Google Calendar event ID
    title: v.string(),
    startTime: v.number(),
    endTime: v.number(),
    attendees: v.array(v.string()),
    location: v.optional(v.string()),
    description: v.optional(v.string()),
    status: v.union(
      v.literal("confirmed"),
      v.literal("tentative"),
      v.literal("cancelled")
    ),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_thread", ["threadId"])
    .index("by_event", ["eventId"])
    .index("by_time", ["startTime"]),

  apiKeys: defineTable({
    userId: v.id("users"),
    provider: v.union(v.literal("openai"), v.literal("resend")),
    keyHash: v.string(), // Hashed API key for security
    isActive: v.boolean(),
    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_user", ["userId"])
    .index("by_provider", ["provider"]),

  webhookLogs: defineTable({
    source: v.union(v.literal("gmail"), v.literal("calendar")),
    payload: v.string(),
    status: v.union(v.literal("success"), v.literal("error")),
    errorMessage: v.optional(v.string()),
    processedAt: v.number(),
    userId: v.optional(v.id("users")),
  })
    .index("by_source", ["source"])
    .index("by_status", ["status"])
    .index("by_processed_at", ["processedAt"]),
});