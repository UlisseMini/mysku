import { z } from 'zod';

// Zod Schemas
export const LocationSchema = z.object({
    latitude: z.number(),
    longitude: z.number(),
    accuracy: z.number(),      // Actual GPS accuracy in meters
    desiredAccuracy: z.number().optional(), // User's desired privacy-preserving accuracy in meters (optional for backward compatibility)
    lastUpdated: z.number()
});

export const PrivacySettingsSchema = z.object({
    enabledGuilds: z.array(z.string()), // guilds sharing & viewing is enabled for
    blockedUsers: z.array(z.string()) // users who we shouldn't send location to
});

export const DiscordUserSchema = z.object({
    id: z.string(),
    username: z.string(),
    avatar: z.string().nullable().optional()
});

export const UserSchema = z.object({
    id: z.string(),
    location: LocationSchema.optional(),
    duser: DiscordUserSchema,
    privacy: PrivacySettingsSchema,
    pushToken: z.string().optional(),
    receiveNearbyNotifications: z.boolean().optional(),
    allowNearbyNotifications: z.boolean().optional()
});

export const DiscordTokenResponseSchema = z.object({
    access_token: z.string(),
    token_type: z.string(),
    expires_in: z.number(),
    refresh_token: z.string(),
    scope: z.string()
});

// Guild schemas
export const GuildSchema = z.object({
    id: z.string(),
    name: z.string(),
    icon: z.string().nullable()
});

// Demo data schema (defined after other schemas it depends on)
export const DemoDataSchema = z.object({
    'users/@me': z.object({
        demo: DiscordUserSchema
    }),
    'users/@me/guilds': z.object({
        demo: z.array(GuildSchema)
    }),
    'db': z.object({
        users: z.record(UserSchema)
    })
});

export type DemoData = z.infer<typeof DemoDataSchema>;
export type DemoApiPath = keyof DemoData;

// Type inference from schemas
export type Location = z.infer<typeof LocationSchema>;
export type PrivacySettings = z.infer<typeof PrivacySettingsSchema>;
export type DiscordUser = z.infer<typeof DiscordUserSchema>;
export type User = z.infer<typeof UserSchema>;
export type DiscordTokenResponse = z.infer<typeof DiscordTokenResponseSchema>;
export type Guild = z.infer<typeof GuildSchema>;

// Add schema for recent notifications
export const RecentNotificationSchema = z.object({
    user1Id: z.string(),
    user2Id: z.string(),
    timestamp: z.number()
});

export type RecentNotification = z.infer<typeof RecentNotificationSchema>;