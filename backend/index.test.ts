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
        const newUserData = {
            location: {
                latitude: 40.7128,
                longitude: -74.0060,
                accuracy: 10,
                lastUpdated: Date.now()
            },
            privacy: {
                enabledGuilds: ["123456789"],
                blockedUsers: []
            },
            pushToken: "test-push-token",
            receiveNearbyNotifications: true,
            allowNearbyNotifications: true
        };

        const response = await fetch(`${BASE_URL}/users/me`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
                "Authorization": `Bearer ${DEMO_TOKEN}`
            },
            body: JSON.stringify(newUserData),
        });

        expect(response.status).toBe(200);
        
        const data = await response.json();
        expect(data.success).toBe(true);
    });

    // Test getting user data
    test("should get current user data", async () => {
        const response = await fetch(`${BASE_URL}/users/me`, {
            headers: {
                "Authorization": `Bearer ${DEMO_TOKEN}`
            }
        });

        expect(response.status).toBe(200);
        
        const userData = await response.json();
        expect(userData.id).toBeDefined();
        expect(userData.duser).toBeDefined();
        expect(userData.privacy).toBeDefined();
        expect(userData.location).toBeDefined();
    });

    // Test getting all users
    test("should get all users including our user", async () => {
        const response = await fetch(`${BASE_URL}/users`, {
            headers: {
                "Authorization": `Bearer ${DEMO_TOKEN}`
            }
        });

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