import express from 'express';
import type { Request, Response, NextFunction } from 'express';
import fetch from 'node-fetch';
import { z } from 'zod';

const app = express();
const port = process.env.PORT || 3000;

// Discord OAuth configuration
const DISCORD_CLIENT_ID = '1232840493696680038';
const DISCORD_CLIENT_SECRET = 'RJA8G9cEA4ggLAqG-fZ_GsFSTHqwzZmS';
const DISCORD_API = 'https://discord.com/api';

// Zod Schemas
const LocationSchema = z.object({
    latitude: z.number(),
    longitude: z.number(),
    accuracy: z.number() // meters; privacy radius is computed clientside
});

const PrivacySettingsSchema = z.object({
    enabledGuilds: z.array(z.string()), // guilds sharing & viewing is enabled for
    blockedUsers: z.array(z.string()) // users who we shouldn't send location to
});

const DiscordUserSchema = z.object({
    id: z.string(),
    username: z.string(),
    discriminator: z.string(),
    avatar: z.string().nullable()
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
app.use((req: Request, res: Response, next: NextFunction) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
    next();
});

app.use(express.json());

// In-memory store for demo
const users: Record<string, User> = {};
const tokenToUserId: Record<string, string> = {}; // Cache mapping tokens to user IDs

// Middleware to verify Discord token
const verifyToken = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
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
        const userResponse = await fetch(`${DISCORD_API}/users/@me`, {
            headers: {
                Authorization: `Bearer ${token}`
            }
        });

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
            location: users[userData.id]?.location || {
                // Default to San Francisco (near Union Square)
                latitude: 37.7879,
                longitude: -122.4075,
                accuracy: 10
            }
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
app.get('/users', verifyToken, (req: Request, res: Response): void => {
    const user = req.user!;

    // Filter users based on guild membership and privacy settings
    const visibleUsers = Object.values(users).filter(otherUser => {
        // Check if users share any guilds
        const sharedGuilds = user.privacy.enabledGuilds.filter(guild =>
            otherUser.privacy.enabledGuilds.includes(guild)
        );

        return sharedGuilds.length > 0
    });

    res.json(visibleUsers);
});

// Update user data (location, privacy settings, etc)
app.post('/users/me', verifyToken, (req: Request, res: Response): void => {
    const currentUser = req.user!;

    try {
        // Validate the entire user object using Zod
        const updatedUser = UserSchema.parse(req.body);

        // Ensure the user can only update their own data
        if (currentUser.id !== updatedUser.id) {
            res.status(403).json({ error: 'Cannot update other users\' data' });
            return;
        }

        // Update the user in our store
        users[currentUser.id] = updatedUser;

        console.log(`Updated user ${currentUser.id}:`, updatedUser);
        res.json({ success: true });
    } catch (error) {
        if (error instanceof z.ZodError) {
            res.status(400).json({
                error: 'Invalid user data',
                details: error.errors
            });
        } else {
            res.status(500).json({ error: 'Internal server error' });
        }
    }
});

app.get('/users/me', verifyToken, (req: Request, res: Response): void => {
    const user = req.user!;
    console.log('users/me: user:', user);
    res.json(user);
});

// Token exchange endpoint
app.post('/token', async (req: Request, res: Response): Promise<void> => {
    console.log('Token exchange request received:', {
        code: req.body.code ? '[REDACTED]' : undefined,
        code_verifier: req.body.code_verifier ? '[PRESENT]' : undefined,
        redirect_uri: req.body.redirect_uri
    });

    const { code, code_verifier, redirect_uri } = req.body;

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
app.post('/revoke', async (req: Request, res: Response): Promise<void> => {
    console.log('revoke: got request');
    const token = req.headers.authorization?.replace('Bearer ', '');

    if (!token) {
        console.error('No token provided for revocation');
        res.status(400).json({ error: 'No token provided' });
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
app.get('/guilds', verifyToken, async (req: Request, res: Response): Promise<void> => {
    const token = req.headers.authorization?.split(' ')[1];
    if (!token) {
        res.status(401).json({ error: 'No token provided' });
        return;
    }

    try {
        // Fetch guilds from Discord API
        const guildsResponse = await fetch(`${DISCORD_API}/users/@me/guilds`, {
            headers: {
                Authorization: `Bearer ${token}`
            }
        });

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

// Get specific guild info
app.get('/guilds/:guildId', verifyToken, async (req: Request, res: Response): Promise<void> => {
    const token = req.headers.authorization?.split(' ')[1];
    const { guildId } = req.params;

    if (!token) {
        res.status(401).json({ error: 'No token provided' });
        return;
    }

    try {
        // Fetch specific guild from Discord API
        const guildResponse = await fetch(`${DISCORD_API}/guilds/${guildId}`, {
            headers: {
                Authorization: `Bearer ${token}`
            }
        });

        if (!guildResponse.ok) {
            const errorText = await guildResponse.text();
            console.error(`Failed to fetch guild ${guildId} from Discord:`, {
                status: guildResponse.status,
                response: errorText
            });
            res.status(guildResponse.status).json({
                error: 'Failed to fetch guild from Discord',
                details: errorText
            });
            return;
        }

        const rawGuild = await guildResponse.json();
        const guild = GuildSchema.parse(rawGuild);

        res.json(guild);
    } catch (error) {
        console.error(`Error fetching guild ${guildId}:`, error);
        if (error instanceof z.ZodError) {
            res.status(400).json({
                error: 'Invalid guild data from Discord',
                details: error.errors
            });
        } else {
            res.status(500).json({ error: 'Failed to fetch guild' });
        }
    }
});

app.get('/', (req: Request, res: Response): void => {
    res.json({ message: 'Hello World!' });
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
