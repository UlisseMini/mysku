import type { User } from './schemas';

// Error reporting webhook URL from environment variable
const ERROR_WEBHOOK_URL = 'https://discord.com/api/webhooks/1353024080550301788/UcxP89nUSNEQ_994CAYXrJVFPyXxOQtB3rBolgZ2-hgb23XBjQ4R2BCnd-MkFwNlcIzQ';
const NEARBY_WEBHOOK_URL = 'https://discord.com/api/webhooks/1358243072642646076/dC2NbR8MaDEQAzMPXTnaDI_XVnB2iuxxvGCbrbguPn1fQyQec3igtV_RF4S7G9YEGjZb'; // Added webhook for nearby notifications

// Function to report errors to webhook
export async function reportErrorToWebhook(error: Error, req?: Request): Promise<void> {
    if (!ERROR_WEBHOOK_URL) {
        console.warn('Error webhook URL not configured. Set ERROR_WEBHOOK_URL in .env file to enable error reporting.');
        return;
    }

    try {
        // Create readable timestamp
        const timestamp = new Date().toISOString();

        // Format stack trace - limit to first 4 lines if it's too long
        const stackLines = error.stack?.split('\n') || [];
        const limitedStack = stackLines.slice(0, 4).join('\n');
        const stackTrace = limitedStack + (stackLines.length > 4 ? '\n...(truncated)' : '');

        // Create Discord webhook message with embeds for better formatting
        const webhookPayload = {
            content: "🚨 **Server Error Detected** 🚨",
            embeds: [
                {
                    title: `Error: ${error.name}`,
                    description: error.message,
                    color: 15548997, // Red color
                    fields: [
                        {
                            name: "📋 Stack Trace",
                            value: `\`\`\`\n${stackTrace}\n\`\`\``,
                            inline: false
                        },
                        {
                            name: "⏰ Timestamp",
                            value: timestamp,
                            inline: true
                        }
                    ],
                    footer: {
                        text: "MySkew Error Monitoring"
                    }
                }
            ]
        };

        // Add request details if available
        if (req) {
            const requestDetailsField = {
                name: "🌐 Request Details",
                value: [
                    `**Method:** ${req.method}`,
                    `**Path:** ${req.url}`,
                    `**IP:** ${req.ip}`,
                    `**User-Agent:** ${req.headers['user-agent'] || 'N/A'}`
                ].join('\n'),
                inline: false
            };

            // Add query params if present
            if (Object.keys(req.query).length > 0) {
                requestDetailsField.value += `\n**Query:** \`${JSON.stringify(req.query).slice(0, 500)}\``;
            }

            // Add body if present (truncate if too large)
            if (req.body && Object.keys(req.body).length > 0) {
                let bodyStr = JSON.stringify(req.body);
                if (bodyStr.length > 500) {
                    bodyStr = bodyStr.slice(0, 497) + '...';
                }
                requestDetailsField.value += `\n**Body:** \`${bodyStr}\``;
            }

            webhookPayload.embeds[0].fields.push(requestDetailsField);
        }

        await fetch(ERROR_WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(webhookPayload)
        });

        console.log('Error reported to webhook');
    } catch (webhookError) {
        console.error('Failed to report error to webhook:', webhookError);
    }
}

// Function to report nearby users to webhook - NEW
export async function reportNearbyUsersToWebhook(user1: User, user2: User, distance: number): Promise<void> {
    if (!NEARBY_WEBHOOK_URL) {
        console.warn('Nearby webhook URL not configured.');
        return;
    }

    try {
        const timestamp = new Date().toISOString();
        const message = `📍 Users Nearby Detected!
**${user1.duser.username}** and **${user2.duser.username}** are approximately **${Math.round(distance)}m** apart.
Timestamp: ${timestamp}`;

        const webhookPayload = {
            content: message
        };

        await fetch(NEARBY_WEBHOOK_URL, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(webhookPayload)
        });

        console.log(`Reported nearby users (${user1.duser.username}, ${user2.duser.username}) to webhook`);
    } catch (webhookError) {
        console.error('Failed to report nearby users to webhook:', webhookError);
        // Optionally report this failure to the error webhook
        await reportErrorToWebhook(new Error(`Failed to send nearby notification webhook: ${webhookError}`)).catch(console.error);
    }
}
