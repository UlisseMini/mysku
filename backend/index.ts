import express from 'express';
import type { Request, Response, NextFunction } from 'express';
import fetch from 'node-fetch';

const app = express();
const port = process.env.PORT || 3000;

// Discord OAuth configuration
const DISCORD_CLIENT_ID = '1232840493696680038';
const DISCORD_CLIENT_SECRET = 'RJA8G9cEA4ggLAqG-fZ_GsFSTHqwzZmS';
const DISCORD_API = 'https://discord.com/api';

// Logging middleware
app.use((req: Request, res: Response, next: NextFunction) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
    next();
});

app.use(express.json());

// Add type declaration for the extended Request
declare global {
    namespace Express {
        interface Request {
            user?: User;
        }
    }
}

// API types. Could change. Ideally only by adding stuff and
// staying backwards compatible.
interface Location {
    latitude: number;
    longitude: number;
    accuracy: number; // meters; privacy radius is computed clientside
}

// Privacy settings for a user. Depending on these
interface PrivacySettings {
    enabledGuilds: string[]; // guilds sharing & viewing is enabled for
    blockedUsers: string[]; // users who we shouldn't send location to
}

interface User {
    id: string;
    location?: Location; // last location, if we have it
    duser: DiscordUser;
    privacy: PrivacySettings;
}

// Discord stuff. Unchanging
interface DiscordTokenResponse {
    access_token: string;
    token_type: string;
    expires_in: number;
    refresh_token: string;
    scope: string;
}

interface DiscordUser {
    id: string;
    username: string;
    discriminator: string;
    avatar: string | null;
}

// All discord login is handled clientside so we don't need these <3
// const DISCORD_CLIENT_ID = '...';
// const DISCORD_CLIENT_SECRET = '...';

// In-memory store for demo
const users: Record<string, User> = {};

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
        // First check our in-memory cache using the token as key
        const cachedUser = users[token];
        if (cachedUser) {
            console.log('verify: found cached user:', cachedUser.id);
            req.user = cachedUser;
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
            userData = JSON.parse(responseText);
            console.log('verify: got user data for:', userData.username);
        } catch (e) {
            console.error('verify: Failed to parse user data:', e);
            console.error('verify: Raw response:', responseText);
            res.status(500).json({ error: 'Invalid response from Discord' });
            return;
        }

        // Store user in our cache using the token as key
        const user = {
            id: userData.id,
            duser: userData,
            privacy: {
                enabledGuilds: [],
                blockedUsers: []
            }
        };

        // Store the user both by token and by ID for different lookup needs
        users[token] = user;
        users[userData.id] = user;

        console.log('verify: stored new user in cache:', userData.id);
        req.user = user;
        next();
    } catch (error) {
        console.error('verify: Token verification error:', error);
        res.status(500).json({ error: 'Failed to verify token' });
    }
};

// Get locations of all users we have access to see
app.get('/locations', verifyToken, (req: Request, res: Response): void => {
    const user = req.user!;

    // Filter users based on guild membership and privacy settings
    const visibleUsers = Object.values(users).filter(otherUser => {
        // Check if users share any guilds
        const sharedGuilds = user.privacy.enabledGuilds.filter(guild =>
            otherUser.privacy.enabledGuilds.includes(guild)
        );

        return sharedGuilds.length > 0;
    });

    res.json(visibleUsers);
});

// Update user's location
app.post('/locations', verifyToken, (req: Request, res: Response): void => {
    const user = req.user!;
    const location: Location = req.body;

    user.location = location;
    res.json({ success: true });
});

// Update privacy settings
app.post('/privacy', verifyToken, (req: Request, res: Response): void => {
    console.log('privacy: got request');
    const user = req.user!;
    const { enabledGuilds, blockedUsers } = req.body;

    user.privacy = {
        enabledGuilds,
        blockedUsers
    };
    console.log(`Updated privacy for ${user.id}:`, user.privacy);

    res.json({ success: true });
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

        // Parse the token response
        let parsedTokenData: DiscordTokenResponse;
        try {
            parsedTokenData = JSON.parse(tokenData);
        } catch (e) {
            console.error('Failed to parse token response:', e);
            console.error('Raw token data:', tokenData);
            res.status(500).json({ error: 'Invalid token response from Discord' });
            return;
        }

        console.log('Token exchange successful');
        res.json(parsedTokenData);
    } catch (error) {
        console.error('Token exchange error:', error);
        res.status(500).json({ error: 'Internal server error during token exchange' });
    }
});

// Token revocation endpoint
app.post('/revoke', async (req: Request, res: Response): Promise<void> => {
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

app.get('/', (req: Request, res: Response): void => {
    res.json({ message: 'Hello World!' });
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
