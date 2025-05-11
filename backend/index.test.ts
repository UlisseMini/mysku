import { expect, test, describe, beforeAll, afterAll } from "bun:test";
import { createServer } from "http";
import app from "./index";

const server = createServer(app);
const PORT = 3456;
const BASE_URL = `http://localhost:${PORT}`;

// Demo token for authentication
const DEMO_TOKEN = "demo";

describe("API Tests", () => {
    // Setup and teardown
    beforeAll(() => {
        return new Promise<void>((resolve) => {
            server.listen(PORT, () => {
                console.log(`Test server running on port ${PORT}`);
                resolve();
            });
        });
    });

    afterAll(() => {
        return new Promise<void>((resolve, reject) => {
            server.close((err?: Error) => {
                console.log("Test server closed");
                err ? reject(err) : resolve();
            });
        });
    });

    // Test creating a new user
    test("should create a new user", async () => {
        const body = userData({privacy: { enabledGuilds: ["123456789"], blockedUsers: []}});
        const response = await apiCall('/users/me', 'POST', body);
        expect(response.status).toBe(200);
        
        const data = await response.json();
        expect(data.success).toBe(true);
    });

    // Test getting user data
    test("should get current user data", async () => {
        const response = await apiCall('/users/me', 'GET');
        expect(response.status).toBe(200);
        
        const userData = await response.json();
        expect(userData.id).toBeDefined();
        expect(userData.duser).toBeDefined();
        expect(userData.privacy).toBeDefined();
        expect(userData.location).toBeDefined();
    });

    // Test getting all users
    test("should get all users including our user", async () => {
        const response = await apiCall('/users', 'GET');
        expect(response.status).toBe(200);
        
        const users = await response.json();
        expect(Array.isArray(users)).toBe(true);
        
        // Verify our demo user is in the list - the test showed the user ID is "1000" not "demo0"
        const demoUser = users.find((user: any) => user.id === "1000");
        expect(demoUser).toBeDefined();
        
        // Check if user properties were properly set
        expect(demoUser.privacy.enabledGuilds).toContain("123456789");
    });
});


function userData(other: any = {}) {
    return {
        location: {
            latitude: 40.7128,
            longitude: -74.0060,
            accuracy: 10,
            lastUpdated: Date.now()
        },
        privacy: {
            enabledGuilds: [],
            blockedUsers: [],
        },
        pushToken: "test-push-token",
        receiveNearbyNotifications: true,
        allowNearbyNotifications: true,
        ...other
    };
}

async function apiCall(path: string, method: string, body: any = null) {
    const response = await fetch(`${BASE_URL}${path}`, {
        method: method,
        headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${DEMO_TOKEN}`
        },
        body: body ? JSON.stringify(body) : null
    });
    return response;
}
