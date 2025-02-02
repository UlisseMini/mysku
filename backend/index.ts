import express from 'express';
import type { Request, Response, NextFunction } from 'express';
import fetch from 'node-fetch';

const app = express();
const port = process.env.PORT || 3000;

// Logging middleware
app.use((req: Request, res: Response, next: NextFunction) => {
    console.log(`${new Date().toISOString()} ${req.method} ${req.url}`);
    next();
});

app.use(express.json());

interface Location {
    latitude: number;
    longitude: number;
    timestamp: number;
    accuracy?: number;
}

interface User {
    id: string;
    username?: string;
    location?: Location;
    privacyRadius: number;
    allowedGuilds: string[];
}

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

// Discord OAuth configuration
const DISCORD_CLIENT_ID = '1232840493696680038';
const DISCORD_CLIENT_SECRET = 'RJA8G9cEA4ggLAqG-fZ_GsFSTHqwzZmS';
const DISCORD_API = 'https://discord.com/api';

// In-memory store for demo
const users: Record<string, User> = {};

// Handle Discord OAuth login
app.post('/login/discord', async (req: Request, res: Response) => {
    const { code, code_verifier } = req.body;

    try {
        console.log({
            code, code_verifier
        })
        // Exchange code for token
        const tokenResponse = await fetch(`${DISCORD_API}/oauth2/token`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: new URLSearchParams({
                client_id: DISCORD_CLIENT_ID,
                client_secret: DISCORD_CLIENT_SECRET,
                code: code,
                code_verifier: code_verifier,
                grant_type: 'authorization_code',
                redirect_uri: 'miniworld://redirect'
            })
        });

        const tokenData = await tokenResponse.json() as DiscordTokenResponse;

        if (!tokenResponse.ok) {
            console.error('Token exchange failed:', tokenData);
            res.status(400).json({ error: 'Failed to exchange code for token' });
            return;
        }

        // Get user info using the access token
        const userResponse = await fetch(`${DISCORD_API}/users/@me`, {
            headers: {
                Authorization: `Bearer ${tokenData.access_token}`
            }
        });

        const userData = await userResponse.json() as DiscordUser;

        if (!userResponse.ok) {
            console.error('Failed to get user data:', userData);
            res.status(400).json({ error: 'Failed to get user data' });
            return;
        }

        // Store user info
        users[userData.id] = {
            id: userData.id,
            username: userData.username,
            privacyRadius: 1000,
            allowedGuilds: []
        };

        // Return session token (in this case, just using the Discord user ID as the session)
        res.json({
            session: userData.id,
            user: {
                id: userData.id,
                username: userData.username
            }
        });

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

// Middleware to verify Discord token
const verifyToken = (req: Request, res: Response, next: NextFunction): void => {
    const token = req.headers.authorization;
    if (!token) {
        res.status(401).json({ error: 'No token provided' });
        return;
    }
    // For now, just check if the user exists in our store
    const user = users[token];
    if (!user) {
        res.status(401).json({ error: 'Invalid token' });
        return;
    }
    req.headers['user-id'] = token;
    next();
};

// Get locations of all users we have access to see
app.get('/locations', verifyToken, (req: Request, res: Response): void => {
    const userId = req.headers['user-id'] as string;
    const user = users[userId];

    if (!user) {
        res.status(404).json({ error: 'User not found' });
        return;
    }

    // Filter users based on guild membership and privacy settings
    const visibleUsers = Object.values(users).filter(otherUser => {
        // Check if users share any guilds
        const sharedGuilds = user.allowedGuilds.filter(guild =>
            otherUser.allowedGuilds.includes(guild)
        );

        return sharedGuilds.length > 0;
    });

    res.json(visibleUsers);
});

// Update user's location
app.post('/location', verifyToken, (req: Request, res: Response): void => {
    const userId = req.headers['user-id'] as string;
    const location: Location = req.body;

    if (!users[userId]) {
        users[userId] = {
            id: userId,
            privacyRadius: 1000, // Default 1km
            allowedGuilds: [],
        };
    }

    users[userId].location = location;
    res.json({ success: true });
});

// Update privacy settings
app.post('/privacy', verifyToken, (req: Request, res: Response): void => {
    const userId = req.headers['user-id'] as string;
    const { privacyRadius, allowedGuilds } = req.body;

    if (!users[userId]) {
        res.status(404).json({ error: 'User not found' });
        return;
    }

    users[userId].privacyRadius = privacyRadius;
    users[userId].allowedGuilds = allowedGuilds;

    res.json({ success: true });
});

app.get('/', (req: Request, res: Response): void => {
    res.json({ message: 'Hello World!' });
});

app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
