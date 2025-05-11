import express from 'express';
import type { Request, Response as ExpressResponse, NextFunction } from 'express';
import fetch, { Response as FetchResponse, type RequestInit } from 'node-fetch';
import { z } from 'zod';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import dotenv from 'dotenv';
import apn from 'node-apn';
import { RecentNotificationSchema, LocationSchema, DiscordUserSchema, UserSchema, DiscordTokenResponseSchema, GuildSchema, DemoDataSchema } from './src/schemas';
import type { Location, DiscordUser, User, Guild, DemoData, RecentNotification } from './src/schemas';
import { reportErrorToWebhook, reportNearbyUsersToWebhook } from './src/utils';

// Load environment variables from .env file
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Add these constants near the top of the file after other imports
const DB_DIR = fs.existsSync("/db") ? "/db" : path.join(__dirname, 'db');
const USERS_FILE = path.join(DB_DIR, 'users.json');
const TOKENS_FILE = path.join(DB_DIR, 'tokenToUserId.json');
const NOTIFICATIONS_FILE = path.join(DB_DIR, 'recentNotifications.json');

// APNs configuration
const APNS_KEY_ID = process.env.APNS_KEY_ID!;
const APNS_TEAM_ID = process.env.APNS_TEAM_ID!;
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID!;
const APNS_KEY_BASE64 = process.env.APNS_KEY_BASE64!;

// Validate APNs configuration
if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_BUNDLE_ID || !APNS_KEY_BASE64) {
    throw new Error('Missing required APNs environment variables. Please check your .env file.');
}

// Initialize APNs provider
let apnProvider: apn.Provider | null = null;

try {
    apnProvider = new apn.Provider({
        token: {
            key: Buffer.from(APNS_KEY_BASE64, 'base64'),
            keyId: APNS_KEY_ID,
            teamId: APNS_TEAM_ID
        },
        production: process.env.NODE_ENV === 'production'
    });
    console.log(`APNs provider initialized successfully for environment: "${process.env.NODE_ENV}"`);
} catch (error) {
    console.error('Failed to initialize APNs provider:', error);
    throw error;
}

// Cache interfaces and implementations
interface CacheEntry<T> {
    data: T;
    timestamp: number;
}

interface Cache {
    guilds: Record<string, CacheEntry<Guild[]>>;
    userGuilds: Record<string, CacheEntry<Guild>>;
    recentNotifications: RecentNotification[];
}

const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
const cache: Cache = {
    guilds: {},
    userGuilds: {},
    recentNotifications: []
};

function isCacheValid<T>(entry?: CacheEntry<T>): boolean {
    if (!entry) return false;
    return Date.now() - entry.timestamp < CACHE_TTL;
}

// Move HTML_REDIRECTS before app initialization
const HTML_REDIRECTS: Record<string, string> = {
    '/privacy-policy': '/privacy-policy.html',
    '/support': '/support.html'
};

const app = express();
const port = process.env.PORT || 3000;

// Add static file serving before other routes
app.use(express.static(path.join(__dirname, 'static')));

// Add redirect handler
app.use((req: Request, res: ExpressResponse, next: NextFunction) => {
    const redirect = HTML_REDIRECTS[req.path];
    if (redirect) {
        res.redirect(redirect);
        return;
    }
    next();
});

// Discord OAuth configuration
const DISCORD_CLIENT_ID = process.env.DISCORD_CLIENT_ID;
const DISCORD_CLIENT_SECRET = process.env.DISCORD_CLIENT_SECRET;
const DISCORD_API = 'https://discord.com/api';

if (!DISCORD_CLIENT_ID || !DISCORD_CLIENT_SECRET) {
    throw new Error('Missing required environment variables. Please check your .env file.');
}

// Add type declaration for the extended Request
declare global {
    namespace Express {
        interface Request {
            user?: User;
        }
    }
}

// Logging middleware
app.use((req: Request, res: ExpressResponse, next: NextFunction) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
    next();
});

app.use(express.json());

// Replace the existing users and tokenToUserId declarations with:
const users: Record<string, User> = {};
const tokenToUserId: Record<string, string> = {};

// The following data loading and interval setup will be moved to the main() function.
// // Load any existing data
// loadPersistedData();

// // Set up periodic saving
// if (fs.existsSync(DB_DIR)) {
//     setInterval(saveDataToDisk, 60000); // Save every minute
//     console.log('Automatic data persistence enabled');
// }

// Fetch demo data, validate it, merge demo users into the users store
const rawDemoData = JSON.parse(fs.readFileSync(path.join(__dirname, 'demo-mode.json'), 'utf-8'));
const demoData = DemoDataSchema.parse(rawDemoData);
Object.values(demoData.db.users).forEach(demoUser => {
    users[demoUser.id] = UserSchema.parse(demoUser);
});


// Demo mode constants
const DEMO_TOKEN_RESPONSE = {
    access_token: 'demo',
    token_type: 'Bearer',
    expires_in: 604800, // 7 days in seconds
    refresh_token: 'demo_refresh',
    scope: 'identify guilds'
};

// Initialize demo token mapping
tokenToUserId['demo'] = 'demo0';

// Utility function for Discord API calls with demo mode support
async function discordFetch(apiPath: string, token: string, options: RequestInit = {}): Promise<FetchResponse> {
    if (token === 'demo') {
        // Handle demo mode
        if (!isDemoApiPath(apiPath)) {
            throw new Error(`No demo data available for path: ${apiPath}`);
        }
        const demoResponse = demoData[apiPath]?.demo;
        if (!demoResponse) {
            throw new Error(`No demo data available for path: ${apiPath}`);
        }

        // Create a mock Response object that matches FetchResponse interface
        const mockResponse = new FetchResponse(JSON.stringify(demoResponse), {
            status: 200,
            statusText: 'OK'
        });

        return mockResponse;
    }

    // Real Discord API call
    const url = `${DISCORD_API}/${apiPath}`;
    const headers = {
        ...options.headers,
        Authorization: `Bearer ${token}`
    };

    return fetch(url, { ...options, headers });
}

// Type guard for demo API paths
function isDemoApiPath(path: string): path is keyof Pick<DemoData, 'users/@me' | 'users/@me/guilds'> {
    return path === 'users/@me' || path === 'users/@me/guilds';
}

// Middleware to verify Discord token
const verifyToken = async (req: Request, res: ExpressResponse, next: NextFunction): Promise<void> => {
    const authHeader = req.headers.authorization;
    // console.log('verify: auth header:', authHeader);

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        console.error('verify: invalid auth header format');
        res.status(401).json({ error: 'Invalid authorization header format' });
        return;
    }

    const token = authHeader.split(' ')[1];
    // console.log('verify: attempting to validate token with Discord');

    try {
        // First check our token cache
        const cachedUserId = tokenToUserId[token];
        if (cachedUserId && users[cachedUserId]) {
            // console.log('verify: found cached user:', cachedUserId);
            req.user = users[cachedUserId];
            next();
            return;
        }

        // If not in cache, validate with Discord
        const userResponse = await discordFetch('users/@me', token);

        const responseText = await userResponse.text();
        // console.log('verify: Discord response status:', userResponse.status);

        if (!userResponse.ok) {
            console.error('verify: Discord validation failed:', {
                status: userResponse.status,
                response: responseText
            });
            res.status(401).json({ error: 'Invalid token' });
            return;
        }

        let userData: DiscordUser;
        try {
            const rawUserData = JSON.parse(responseText);
            // Validate Discord user data
            userData = DiscordUserSchema.parse(rawUserData);
            // console.log('verify: got user data for:', userData.username);
        } catch (e) {
            console.error('verify: Failed to parse/validate user data:', e);
            console.error('verify: Raw response:', responseText);
            res.status(500).json({ error: 'Invalid response from Discord' });
            return;
        }

        // Check if user already exists to preserve settings
        const existingUser = users[userData.id];

        // Create and validate new user object
        const user = UserSchema.parse({
            id: userData.id,
            duser: userData,
            privacy: existingUser?.privacy || {
                enabledGuilds: [],
                blockedUsers: []
            },
            location: existingUser?.location,
            pushToken: existingUser?.pushToken,
            receiveNearbyNotifications: existingUser?.receiveNearbyNotifications ?? true,
            allowNearbyNotifications: existingUser?.allowNearbyNotifications ?? true
        });

        // Ensure desiredAccuracy defaults to 0 if location exists but desiredAccuracy doesn't
        if (user.location && user.location.desiredAccuracy === undefined) {
            user.location.desiredAccuracy = 0;
        }

        // Store the user and token mapping
        users[userData.id] = user;
        tokenToUserId[token] = userData.id;

        // console.log('verify: stored new user in cache:', userData.id);
        req.user = user;
        next();
    } catch (error) {
        console.error('verify: Token verification error:', error);
        await reportErrorToWebhook(error as Error, req);
        res.status(500).json({ error: 'Failed to verify token' });
    }
};

// Add rounding helper at the top with other utility functions
function roundCoordinates(location: Location): Location {
    // Handle cases where the location is undefined
    if (!location) {
        return location;
    }

    // Default to 3km (3000 meters) if desiredAccuracy isn't specified
    const desiredAccuracy = location.desiredAccuracy ?? 3000;

    // If desired accuracy is 0 or negative, return original location
    if (desiredAccuracy <= 0) {
        return location;
    }

    // Convert accuracy from meters to degrees (approximate)
    // 1 degree is roughly 111km at the equator
    const accuracyInDegrees = desiredAccuracy / 111000;

    return {
        ...location,
        // Ensure desiredAccuracy is included in the result
        desiredAccuracy,
        latitude: Math.round(location.latitude / accuracyInDegrees) * accuracyInDegrees,
        longitude: Math.round(location.longitude / accuracyInDegrees) * accuracyInDegrees,
        // Set accuracy to max of actual GPS accuracy and desired accuracy
        accuracy: Math.max(location.accuracy, desiredAccuracy)
    };
}

// Get all users we have access to see
app.get('/users', verifyToken, (req: Request, res: ExpressResponse): void => {
    const user = req.user!;
    // console.log('GET /users: Processing request for user:', user.id);

    // Filter users based on guild membership and privacy settings
    const visibleUsers: User[] = Object.values(users).filter(otherUser => {
        // Always include the current user
        if (otherUser.id === user.id) return true;

        // Check if users share any guilds
        const sharedGuilds = user.privacy.enabledGuilds.filter(guild =>
            otherUser.privacy.enabledGuilds.includes(guild)
        );

        return sharedGuilds.length > 0;
    }).map(otherUser => {
        // If either user has blocked the other, return user without location
        if (user.privacy.blockedUsers.includes(otherUser.id) ||
            otherUser.privacy.blockedUsers.includes(user.id)) {
            console.log(`GET /users: User ${otherUser.id} is blocked, removing location`);
            return {
                ...otherUser,
                location: undefined
            };
        }

        // Round coordinates based on the user's requested accuracy
        if (otherUser.location) {
            // Ensure desiredAccuracy exists for migration
            const location = {
                ...otherUser.location,
                desiredAccuracy: otherUser.location.desiredAccuracy ?? 0
            };

            // console.debug(`GET /users: Processing location for user ${otherUser.id}:`, {
            //     original: location,
            //     rounded: roundCoordinates(location)
            // });

            return {
                ...otherUser,
                location: roundCoordinates(location)
            };
        }

        return otherUser;
    });

    const jiggledUsers = jiggleUsers(visibleUsers);
    // console.log('GET /users: Final user count:', jiggledUsers.length);
    res.json(jiggledUsers);
});

// Update user data (location, privacy settings, etc)
app.post('/users/me', verifyToken, async (req: Request, res: ExpressResponse): Promise<void> => {
    const currentUser = req.user!;
    // console.log('POST /users/me: Received update request:', {
    //     userId: currentUser.id,
    //     body: req.body
    // });

    try {
        const { username, guild, location, privacy, pushToken,
            receiveNearbyNotifications, allowNearbyNotifications } = req.body;

        // Process location, ensuring desiredAccuracy defaults to 0
        let processedLocation: Location | undefined = undefined;
        if (location) {
            processedLocation = LocationSchema.parse({
                ...location,
                desiredAccuracy: location.desiredAccuracy ?? 0 // Default to 0 if not provided in request
            });
        }

        // Update user data
        const updatedUser = UserSchema.parse({
            id: currentUser.id,
            duser: currentUser.duser,
            privacy: privacy,
            location: processedLocation ? roundCoordinates(processedLocation) : currentUser.location,
            pushToken: pushToken || currentUser.pushToken,
            receiveNearbyNotifications: receiveNearbyNotifications ?? currentUser.receiveNearbyNotifications ?? true,
            allowNearbyNotifications: allowNearbyNotifications ?? currentUser.allowNearbyNotifications ?? true
        });

        // console.log('POST /users/me: Validated and processed user data:', {
        //     userId: updatedUser.id,
        //     location: updatedUser.location,
        //     pushToken: updatedUser.pushToken,
        //     receiveNearbyNotifications: updatedUser.receiveNearbyNotifications,
        //     allowNearbyNotifications: updatedUser.allowNearbyNotifications
        // });

        // Ensure the user can only update their own data
        if (currentUser.id !== updatedUser.id) {
            res.status(403).json({ error: 'Cannot update other users\' data' });
            return;
        }

        // Update the user in our store
        users[currentUser.id] = updatedUser;

        res.json({ success: true });
    } catch (error) {
        if (error instanceof z.ZodError) {
            console.error('POST /users/me: Validation error:', {
                errors: error.errors,
                receivedData: req.body
            });
            res.status(400).json({
                error: 'Invalid user data',
                details: error.errors
            });
        } else {
            console.error('POST /users/me: Unexpected error:', error);
            res.status(500).json({ error: 'Internal server error' });
        }
    }
});

app.get('/users/me', verifyToken, (req: Request, res: ExpressResponse): void => {
    const user = req.user!;
    // console.debug('users/me: user:', user);
    res.json(user);
});

// Token exchange endpoint
app.post('/token', async (req: Request, res: ExpressResponse): Promise<void> => {
    console.log('Token exchange request received:', {
        code: req.body.code ? '[REDACTED]' : undefined,
        code_verifier: req.body.code_verifier ? '[PRESENT]' : undefined,
        redirect_uri: req.body.redirect_uri
    });

    const { code, code_verifier, redirect_uri } = req.body;

    // Handle demo mode
    if (code === 'demo') {
        console.log('Demo mode token exchange');
        res.json(DEMO_TOKEN_RESPONSE);
        return;
    }

    if (!code || !code_verifier || !redirect_uri) {
        console.error('Missing required parameters:', { code: !!code, code_verifier: !!code_verifier, redirect_uri: !!redirect_uri });
        res.status(400).json({ error: 'Missing required parameters' });
        return;
    }

    try {
        // Exchange the code for a token with Discord
        const tokenResponse = await fetch(`${DISCORD_API}/oauth2/token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
                client_id: DISCORD_CLIENT_ID,
                client_secret: DISCORD_CLIENT_SECRET,
                grant_type: 'authorization_code',
                code,
                redirect_uri,
                code_verifier
            })
        });

        const tokenData = await tokenResponse.text();
        console.log('Discord token response status:', tokenResponse.status);

        if (!tokenResponse.ok) {
            console.error('Discord token exchange failed:', {
                status: tokenResponse.status,
                response: tokenData
            });
            res.status(tokenResponse.status).json({
                error: 'Failed to exchange token with Discord',
                details: tokenData
            });
            return;
        }

        try {
            // Parse and validate token response
            const rawTokenData = JSON.parse(tokenData);
            const parsedTokenData = DiscordTokenResponseSchema.parse(rawTokenData);
            console.log('Token exchange successful');
            res.json(parsedTokenData);
        } catch (error) {
            if (error instanceof z.ZodError) {
                console.error('Invalid token response format:', error.errors);
                res.status(500).json({
                    error: 'Invalid token response from Discord',
                    details: error.errors
                });
            } else {
                console.error('Failed to parse token response:', error);
                console.error('Raw token data:', tokenData);
                res.status(500).json({ error: 'Invalid token response from Discord' });
            }
        }
    } catch (error) {
        console.error('Token exchange error:', error);
        res.status(500).json({ error: 'Internal server error during token exchange' });
    }
});

// Token revocation endpoint
app.post('/revoke', async (req: Request, res: ExpressResponse): Promise<void> => {
    console.log('revoke: got request');
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
        console.error('No token provided for revocation');
        res.status(400).json({ error: 'No token provided' });
        return;
    }

    // Handle demo mode
    if (token === 'demo') {
        console.log('Demo mode token revocation - no action needed');
        res.json({ success: true });
        return;
    }

    try {
        console.log('Attempting to revoke token');
        const revokeResponse = await fetch(`${DISCORD_API}/oauth2/token/revoke`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: new URLSearchParams({
                token,
                client_id: DISCORD_CLIENT_ID,
                client_secret: DISCORD_CLIENT_SECRET
            })
        });

        if (!revokeResponse.ok) {
            const errorData = await revokeResponse.text();
            console.error('Token revocation failed:', {
                status: revokeResponse.status,
                response: errorData
            });
            res.status(revokeResponse.status).json({
                error: 'Failed to revoke token',
                details: errorData
            });
            return;
        }

        console.log('Token successfully revoked');
        res.json({ success: true });
    } catch (error) {
        console.error('Token revocation error:', error);
        res.status(500).json({ error: 'Internal server error during token revocation' });
    }
});

// Guild endpoints
app.get('/guilds', verifyToken, async (req: Request, res: ExpressResponse): Promise<void> => {
    const token = req.headers.authorization?.split(' ')[1];
    const user = req.user!;

    if (!token) {
        res.status(401).json({ error: 'No token provided' });
        return;
    }

    try {
        // Check cache first
        const cachedGuilds = cache.guilds[user.id];
        if (isCacheValid(cachedGuilds)) {
            console.log('Returning cached guilds for user:', user.id);
            res.json(cachedGuilds.data);
            return;
        }

        // Fetch guilds from Discord API if cache miss or expired
        const guildsResponse = await discordFetch('users/@me/guilds', token);

        if (!guildsResponse.ok) {
            const errorText = await guildsResponse.text();
            console.error('Failed to fetch guilds from Discord:', {
                status: guildsResponse.status,
                response: errorText
            });
            res.status(guildsResponse.status).json({
                error: 'Failed to fetch guilds from Discord',
                details: errorText
            });
            return;
        }

        const rawGuilds = await guildsResponse.json();
        const guilds = z.array(GuildSchema).parse(rawGuilds);

        // Update cache
        cache.guilds[user.id] = {
            data: guilds,
            timestamp: Date.now()
        };

        res.json(guilds);
    } catch (error) {
        console.error('Error fetching guilds:', error);
        if (error instanceof z.ZodError) {
            res.status(400).json({
                error: 'Invalid guild data from Discord',
                details: error.errors
            });
        } else {
            res.status(500).json({ error: 'Failed to fetch guilds' });
        }
    }
});

// Delete user data endpoint
app.delete('/delete-data', verifyToken, async (req: Request, res: ExpressResponse): Promise<void> => {
    const user = req.user!;

    try {
        // Remove user data
        delete users[user.id];

        // Remove from token cache
        Object.keys(tokenToUserId).forEach(token => {
            if (tokenToUserId[token] === user.id) {
                delete tokenToUserId[token];
            }
        });

        // Remove from guilds cache
        delete cache.guilds[user.id];

        console.log('Successfully deleted user data for:', user.id);
        res.json({ success: true });
    } catch (error) {
        console.error('Failed to delete user data:', error);
        res.status(500).json({ error: 'Failed to delete user data' });
    }
});

// Function to calculate distance between two points in meters using Haversine formula
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371e3; // Earth's radius in meters
    const φ1 = lat1 * Math.PI / 180;
    const φ2 = lat2 * Math.PI / 180;
    const Δφ = (lat2 - lat1) * Math.PI / 180;
    const Δλ = (lon2 - lon1) * Math.PI / 180;

    const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
        Math.cos(φ1) * Math.cos(φ2) *
        Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
}

// Function to check for nearby users and send notifications
async function checkNearbyUsers() {
    console.log('DEBUG: Running checkNearbyUsers'); // Log start

    if (!apnProvider) {
        console.error('Push notification service not configured');
        return;
    }

    const usersWithLocation = Object.values(users).filter(user => user.location && user.pushToken);
    const now = Date.now();
    const ONE_DAY = 24 * 60 * 60 * 1000;

    console.log(`DEBUG: Found ${usersWithLocation.length} users with location and push token.`); // Log count

    // Clean up old notifications
    const initialNotifCount = cache.recentNotifications.length;
    cache.recentNotifications = cache.recentNotifications.filter(notif =>
        now - notif.timestamp < ONE_DAY
    );

    for (let i = 0; i < usersWithLocation.length; i++) {
        for (let j = i + 1; j < usersWithLocation.length; j++) {
            const user1 = usersWithLocation[i];
            const user2 = usersWithLocation[j];

            console.log(`DEBUG: Checking pair: ${user1.duser.username}(${user1.id}) and ${user2.duser.username}(${user2.id})`); // Log pair

            // Skip if either user has blocked the other
            if (user1.privacy.blockedUsers.includes(user2.id) ||
                user2.privacy.blockedUsers.includes(user1.id)) {
                console.log(`DEBUG: Skipping pair - blocked.`); // Log block
                continue;
            }

            // Skip if users don't share any guilds
            const sharedGuilds = user1.privacy.enabledGuilds.filter(guild =>
                user2.privacy.enabledGuilds.includes(guild)
            );
            if (sharedGuilds.length === 0) {
                console.log(`DEBUG: Skipping pair - no shared guilds.`); // Log no shared guilds
                continue;
            }
            console.log(`DEBUG: Shared guilds found: ${sharedGuilds.join(', ')}`); // Log shared guilds

            // Check if we've notified this pair recently
            const recentNotifKey = [user1.id, user2.id].sort().join('-'); // Consistent key
            const hasRecentNotification = cache.recentNotifications.some(notif =>
            ((notif.user1Id === user1.id && notif.user2Id === user2.id) ||
                (notif.user1Id === user2.id && notif.user2Id === user1.id))
            );
            if (hasRecentNotification) {
                console.log(`DEBUG: Skipping pair - recent notification exists.`); // Log recent notification
                continue;
            }

            const distance = calculateDistance(
                user1.location!.latitude,
                user1.location!.longitude,
                user2.location!.latitude, // Corrected: Use latitude for user2
                user2.location!.longitude
            );
            console.log(`DEBUG: Calculated distance: ${distance}m`); // Log distance

            if (distance <= 500) {
                console.log(`DEBUG: Distance <= 500m - Potential notification.`); // Log distance threshold met
                // Report to webhook - ADDED
                reportNearbyUsersToWebhook(user1, user2, distance).catch(console.error);

                // Send notification to user1 about user2
                const canNotifyUser1 = (user1.receiveNearbyNotifications ?? true) && (user2.allowNearbyNotifications ?? true);
                console.log(`DEBUG: Can notify ${user1.duser.username} about ${user2.duser.username}? ${canNotifyUser1} (receive: ${user1.receiveNearbyNotifications ?? true}, allow: ${user2.allowNearbyNotifications ?? true})`); // Log notification decision factors
                if (canNotifyUser1) {
                    try {
                        const notification1 = new apn.Notification();
                        notification1.alert = {
                            title: 'Nearby User!',
                            body: `${user2.duser.username} is ~${Math.round(distance)}m away! Text them to meet up!`
                        };
                        notification1.sound = 'default';
                        notification1.topic = APNS_BUNDLE_ID;
                        await apnProvider.send(notification1, user1.pushToken as string);
                        console.log(`Sent nearby notification to ${user1.duser.username} about ${user2.duser.username}`);
                    } catch (error) {
                        console.error(`Failed to send notification to ${user1.id}:`, error);
                    }
                } else {
                    console.log(`Nearby check: Skipped notification to ${user1.duser.username} about ${user2.duser.username} due to settings.`);
                }

                // Send notification to user2 about user1
                const canNotifyUser2 = (user2.receiveNearbyNotifications ?? true) && (user1.allowNearbyNotifications ?? true);
                console.log(`DEBUG: Can notify ${user2.duser.username} about ${user1.duser.username}? ${canNotifyUser2} (receive: ${user2.receiveNearbyNotifications ?? true}, allow: ${user1.allowNearbyNotifications ?? true})`); // Log notification decision factors
                if (canNotifyUser2) {
                    try {
                        const notification2 = new apn.Notification();
                        notification2.alert = {
                            title: 'Nearby User!',
                            body: `${user1.duser.username} is ~${Math.round(distance)}m away! Text them to meet up!`
                        };
                        notification2.sound = 'default';
                        notification2.topic = APNS_BUNDLE_ID;
                        await apnProvider.send(notification2, user2.pushToken as string);
                        console.log(`Sent nearby notification to ${user2.duser.username} about ${user1.duser.username}`);
                    } catch (error) {
                        console.error(`Failed to send notification to ${user2.id}:`, error);
                    }
                } else {
                    console.log(`Nearby check: Skipped notification to ${user2.duser.username} about ${user1.duser.username} due to settings.`);
                }

                // Record the notification interaction if *either* notification could have been sent
                const shouldRecordInteraction = canNotifyUser1 || canNotifyUser2;
                console.log(`DEBUG: Should record interaction? ${shouldRecordInteraction}`); // Log interaction recording decision
                if (shouldRecordInteraction) {
                    cache.recentNotifications.push({
                        user1Id: user1.id,
                        user2Id: user2.id,
                        timestamp: now
                    });
                }
            }
        }
    }
}

// The following interval setup will be moved to the main() function.
// // Set up periodic check for nearby users
// setInterval(checkNearbyUsers, 6000); // Check every 6s (for now)

async function main() {
    console.log('Executing main application function...');

    // Load any existing data
    loadPersistedData();

    // Set up periodic saving
    if (fs.existsSync(DB_DIR)) {
        setInterval(saveDataToDisk, 60000); // Save every minute
        console.log('Automatic data persistence enabled');
    } else {
        console.log('DB_DIR does not exist, automatic data persistence disabled.');
    }

    // Set up periodic check for nearby users
    setInterval(checkNearbyUsers, 6000); // Check every 6s

    // Start the server
    console.log(`Attempting to start server on port ${port}...`);
    const server = app.listen(port, () => {
        console.log(`Server running on port ${port}`);
    });

    server.on('error', (err: Error) => {
        console.error('Failed to start server:', err);
        process.exit(1);
    });

    // Handle graceful shutdown
    const shutdown = () => {
        console.log('\nReceived shutdown signal. Closing server...');

        server.close((err?: Error) => {
            if (err) {
                console.error('Error during server close:', err);
            } else {
                console.log('Server closed');
            }

            if (apnProvider) {
                apnProvider.shutdown();
                console.log('APNs provider closed');
            }

            // Save any pending data
            saveDataToDisk();

            console.log('Cleanup complete. Exiting...');
            process.exit(err ? 1 : 0);
        });
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);

    console.log('Application main function finished setup. Server is running and periodic tasks scheduled.');
}

// Global error handling middleware - add before the export
app.use((err: Error, req: Request, res: ExpressResponse, next: NextFunction) => {
    console.error('Unhandled error:', err);

    // Report error to webhook
    reportErrorToWebhook(err, req).catch(webhookError => {
        console.error('Failed to report error to webhook:', webhookError);
    });

    // Send error response to client
    if (!res.headersSent) {
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Handle uncaught exceptions and promise rejections
process.on('uncaughtException', (error) => {
    console.error('Uncaught Exception:', error);
    reportErrorToWebhook(error).catch(console.error);
});

process.on('unhandledRejection', (reason) => {
    const error = reason instanceof Error ? reason : new Error(String(reason));
    console.error('Unhandled Rejection:', error);
    reportErrorToWebhook(error).catch(console.error);
});

// Run main function if this script is executed directly
if (import.meta.main) {
    main().catch(err => {
        console.error("Failed to execute main application logic:", err);
        process.exit(1);
    });
}

// Add explicit export to mark as ESM module
export default app;

function loadPersistedData() {
    if (!import.meta.main) {
        console.log('Not in main module, skipping data load');
        return;
    }
    if (!fs.existsSync(DB_DIR)) {
        console.log('No db directory found, skipping data load');
        return;
    }

    try {
        if (fs.existsSync(USERS_FILE)) {
            const userData = JSON.parse(fs.readFileSync(USERS_FILE, 'utf-8'));
            Object.assign(users, userData);
            console.log(`Loaded ${Object.keys(userData).length} users from disk`);
        }

        if (fs.existsSync(TOKENS_FILE)) {
            const tokenData = JSON.parse(fs.readFileSync(TOKENS_FILE, 'utf-8'));
            Object.assign(tokenToUserId, tokenData);
            console.log(`Loaded ${Object.keys(tokenData).length} tokens from disk`);
        }

        if (fs.existsSync(NOTIFICATIONS_FILE)) {
            const notificationData = JSON.parse(fs.readFileSync(NOTIFICATIONS_FILE, 'utf-8'));
            cache.recentNotifications = z.array(RecentNotificationSchema).parse(notificationData);
            console.log(`Loaded ${notificationData.length} recent notifications from disk`);
        }
    } catch (error) {
        console.error('Error loading persisted data:', error);
    }
}

function saveDataToDisk() {
    if (!import.meta.main) {
        console.log('Not in main module, skipping data persistence');
        return;
    }
    if (!fs.existsSync(DB_DIR)) {
        return; // Don't save if db directory doesn't exist
    }

    try {
        fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
        fs.writeFileSync(TOKENS_FILE, JSON.stringify(tokenToUserId, null, 2));
        fs.writeFileSync(NOTIFICATIONS_FILE, JSON.stringify(cache.recentNotifications, null, 2));
        console.log('Data persisted to disk');
    } catch (error) {
        console.error('Error saving data to disk:', error);
    }
}

// Incredibly cursed bullshit
// Basically: When we round to a grid people end up in the exact same spot,
// so we spread them out a bit. This doesn't compromise privacy at all since we
// round before this. a statistical attack just finds the grid-cell-center.
//
// This solves the problem when map is zoomed in, when zoomed out we 

function jiggleUsers(users: User[]): User[] {
    return users;
}

/*
function jiggleUsers(users: User[]): User[] {
    // console.log('jiggleUsers: Starting with', users.length, 'users');

    // Group users with a location by a 4km grid.
    const clusters: Record<string, User[]> = {};
    for (const user of users) {
        if (!user.location) continue;
        const { latitude, longitude } = user.location;
        const key = `${Math.round(latitude / 0.04) * 0.04}-${Math.round(longitude / 0.04) * 0.04}`;
        clusters[key] = clusters[key] || [];
        clusters[key].push(user);
    }
    // console.log('jiggleUsers: Found', Object.keys(clusters).length, 'clusters');

    // For each cluster, spread users evenly on a circle.
    const jiggledMap = new Map<string, User>();
    for (const key in clusters) {
        const cluster = clusters[key];
        const n = cluster.length;
        // console.log(`jiggleUsers: Processing cluster ${key} with ${n} users`);

        cluster.forEach((user, i) => {
            const { latitude, longitude, accuracy, lastUpdated } = user.location!;
            // Default desiredAccuracy to 3000 meters if not present
            const desiredAccuracy = user.location!.desiredAccuracy || 3000;
            const angle = (2 * Math.PI * i) / n;
            const offset = accuracy / 2;
            const dLat = (offset * Math.cos(angle)) / 111320;
            const dLon = (offset * Math.sin(angle)) / (111320 * Math.cos(latitude * Math.PI / 180));

            const newLoc = {
                latitude: latitude + dLat,
                longitude: longitude + dLon,
                accuracy,
                desiredAccuracy,
                lastUpdated,
            };

            // console.log(`jiggleUsers: User ${user.id} location:`, {
            //     original: user.location,
            //     jiggled: newLoc
            // });

            jiggledMap.set(user.id, { ...user, location: newLoc });
        });
    }

    const result = users.map(user => user.location && jiggledMap.has(user.id) ? jiggledMap.get(user.id)! : user);
    // console.log('jiggleUsers: Returning', result.length, 'users');
    return result;
}

*/