import express from 'express';
import { Request, Response as ExpressResponse, NextFunction } from 'express';
import fetch, { Response as FetchResponse, RequestInit } from 'node-fetch';
import { z } from 'zod';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';
import dotenv from 'dotenv';

// Load environment variables from .env file
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Add these constants near the top of the file after other imports
const DB_DIR = fs.existsSync("/db") ? "/db" : path.join(__dirname, 'db');
const USERS_FILE = path.join(DB_DIR, 'users.json');
const TOKENS_FILE = path.join(DB_DIR, 'tokenToUserId.json');

// Cache interfaces and implementations
interface CacheEntry<T> {
    data: T;
    timestamp: number;
}

interface Cache {
    guilds: Record<string, CacheEntry<Guild[]>>;
    userGuilds: Record<string, CacheEntry<Guild>>;
}

const CACHE_TTL = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
const cache: Cache = {
    guilds: {},
    userGuilds: {}
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

// Zod Schemas
const LocationSchema = z.object({
    latitude: z.number(),
    longitude: z.number(),
    accuracy: z.number(), // meters; privacy radius is computed clientside
    lastUpdated: z.number() // Unix timestamp in milliseconds
});

const PrivacySettingsSchema = z.object({
    enabledGuilds: z.array(z.string()), // guilds sharing & viewing is enabled for
    blockedUsers: z.array(z.string()) // users who we shouldn't send location to
});

const DiscordUserSchema = z.object({
    id: z.string(),
    username: z.string(),
    avatar: z.string().nullable().optional()
});

const UserSchema = z.object({
    id: z.string(),
    location: LocationSchema.optional(),
    duser: DiscordUserSchema,
    privacy: PrivacySettingsSchema
});

const DiscordTokenResponseSchema = z.object({
    access_token: z.string(),
    token_type: z.string(),
    expires_in: z.number(),
    refresh_token: z.string(),
    scope: z.string()
});

// Guild schemas
const GuildSchema = z.object({
    id: z.string(),
    name: z.string(),
    icon: z.string().nullable()
});

// Demo data schema (defined after other schemas it depends on)
const DemoDataSchema = z.object({
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

type DemoData = z.infer<typeof DemoDataSchema>;
type DemoApiPath = keyof DemoData;

// Type inference from schemas
type Location = z.infer<typeof LocationSchema>;
type PrivacySettings = z.infer<typeof PrivacySettingsSchema>;
type DiscordUser = z.infer<typeof DiscordUserSchema>;
type User = z.infer<typeof UserSchema>;
type DiscordTokenResponse = z.infer<typeof DiscordTokenResponseSchema>;
type Guild = z.infer<typeof GuildSchema>;

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

// Load any existing data
loadPersistedData();

// Set up periodic saving
if (fs.existsSync(DB_DIR)) {
    setInterval(saveDataToDisk, 60000); // Save every minute
    console.log('Automatic data persistence enabled');
}

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
    console.log('verify: auth header:', authHeader);

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        console.error('verify: invalid auth header format');
        res.status(401).json({ error: 'Invalid authorization header format' });
        return;
    }

    const token = authHeader.split(' ')[1];
    console.log('verify: attempting to validate token with Discord');

    try {
        // First check our token cache
        const cachedUserId = tokenToUserId[token];
        if (cachedUserId && users[cachedUserId]) {
            console.log('verify: found cached user:', cachedUserId);
            req.user = users[cachedUserId];
            next();
            return;
        }

        // If not in cache, validate with Discord
        const userResponse = await discordFetch('users/@me', token);

        const responseText = await userResponse.text();
        console.log('verify: Discord response status:', userResponse.status);

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
            console.log('verify: got user data for:', userData.username);
        } catch (e) {
            console.error('verify: Failed to parse/validate user data:', e);
            console.error('verify: Raw response:', responseText);
            res.status(500).json({ error: 'Invalid response from Discord' });
            return;
        }

        // Create and validate new user object
        const user = UserSchema.parse({
            id: userData.id,
            duser: userData,
            privacy: users[userData.id]?.privacy || {
                enabledGuilds: [],
                blockedUsers: []
            },
            location: users[userData.id]?.location,
        });

        // Store the user and token mapping
        users[userData.id] = user;
        tokenToUserId[token] = userData.id;

        console.log('verify: stored new user in cache:', userData.id);
        req.user = user;
        next();
    } catch (error) {
        console.error('verify: Token verification error:', error);
        res.status(500).json({ error: 'Failed to verify token' });
    }
};

// Get all users we have access to see
app.get('/users', verifyToken, (req: Request, res: ExpressResponse): void => {
    const user = req.user!;

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
            return {
                ...otherUser,
                location: undefined
            };
        }
        return otherUser;
    });

    res.json(jiggleUsers(visibleUsers));
});

// Update user data (location, privacy settings, etc)
app.post('/users/me', verifyToken, (req: Request, res: ExpressResponse): void => {
    const currentUser = req.user!;

    try {
        // Add lastUpdated to location if present
        const body = req.body;
        if (body.location) {
            body.location.lastUpdated = Date.now();
        }

        // Validate the entire user object using Zod
        const updatedUser = UserSchema.parse(body);

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
            console.error('POST users/me: invalid user data:', error.errors);
            res.status(400).json({
                error: 'Invalid user data',
                details: error.errors
            });
        } else {
            res.status(500).json({ error: 'Internal server error' });
        }
    }
});

app.get('/users/me', verifyToken, (req: Request, res: ExpressResponse): void => {
    const user = req.user!;
    console.debug('users/me: user:', user);
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

// Start the server
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});

// Add explicit export to mark as ESM module
export default app;

function loadPersistedData() {
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
    } catch (error) {
        console.error('Error loading persisted data:', error);
    }
}

function saveDataToDisk() {
    if (!fs.existsSync(DB_DIR)) {
        return; // Don't save if db directory doesn't exist
    }

    try {
        fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
        fs.writeFileSync(TOKENS_FILE, JSON.stringify(tokenToUserId, null, 2));
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
    // Group users with a location by a 4km grid.
    const clusters: Record<string, User[]> = {};
    for (const user of users) {
        if (!user.location) continue;
        const { latitude, longitude } = user.location;
        const key = `${Math.round(latitude / 0.04) * 0.04}-${Math.round(longitude / 0.04) * 0.04}`;
        clusters[key] = clusters[key] || [];
        clusters[key].push(user);
    }

    // For each cluster, spread users evenly on a circle.
    const jiggledMap = new Map<string, User>();
    for (const key in clusters) {
        const cluster = clusters[key];
        const n = cluster.length;
        cluster.forEach((user, i) => {
            const { latitude, longitude, accuracy, lastUpdated } = user.location!;
            const angle = (2 * Math.PI * i) / n;
            // Use half the accuracy as the offset (in meters).
            const offset = accuracy / 2;
            // Convert meters to degrees. 1° latitude is roughly 111320m.
            const dLat = (offset * Math.cos(angle)) / 111320;
            const dLon = (offset * Math.sin(angle)) / (111320 * Math.cos(latitude * Math.PI / 180));
            const newLoc = {
                latitude: latitude + dLat,
                longitude: longitude + dLon,
                accuracy,
                lastUpdated,
            };
            jiggledMap.set(user.id, { ...user, location: newLoc });
        });
    }

    // Return a new list preserving original order.
    return users.map(user => user.location && jiggledMap.has(user.id) ? jiggledMap.get(user.id)! : user);
}
