const admin = require('firebase-admin');
const path = require('path');
const logger = require('./logger'); // Assuming a logger exists, fallback to console

let isFirebaseInitialized = false;

/**
 * Initializes Firebase Admin SDK with a dummy service account JSON if real one doesn't exist.
 */
const initializeFirebase = () => {
    if (isFirebaseInitialized) return;

    try {
        const serviceAccountPath = path.join(__dirname, '..', 'config', 'service-account.json');

        let serviceAccount = require(serviceAccountPath);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });

        isFirebaseInitialized = true;
        (logger.info || console.log)('✅ Firebase Admin initialized successfully.');
    } catch (error) {
        (logger.error || console.error)('❌ Failed to initialize Firebase Admin:', error);
    }
};

/**
 * Sends a notification to a specific device via FCM token.
 * @param {string} token - The FCM registration token of the device.
 * @param {object} payload - The notification payload ({ title, body, data }).
 */
const sendNotification = async (token, payload) => {
    if (!token) {
        console.error('❌ Cannot send notification: No FCM token provided.');
        return false;
    }

    if (!isFirebaseInitialized) {
        initializeFirebase();
    }

    const message = {
        token: token,
        notification: {
            title: payload.title || 'Notification',
            body: payload.body || '',
        },
        data: payload.data || {},
        android: {
            priority: 'high',
            notification: {
                sound: 'default'
            }
        },
        apns: {
            payload: {
                aps: {
                    sound: 'default'
                }
            }
        }
    };

    try {
        const response = await admin.messaging().send(message);
        (logger.info || console.log)(`✅ Successfully sent notification to token ending in ${token.substring(token.length - 6)}:`, response);
        return true;
    } catch (error) {
        (logger.error || console.error)('❌ Error sending notification:', error);

        // Handle mock scenario
        if (error.message && error.message.includes('MOCK_KEY')) {
            console.log('Mock Firebase: Notification "sent" successfully in development mode.');
            return true;
        }

        return false;
    }
};

/**
 * Sends a notification to an array of tokens (Multicast)
 * @param {string[]} tokens - Array of FCM registration tokens.
 * @param {object} payload - The notification payload ({ title, body, data }).
 */
const sendMulticastNotification = async (tokens, payload) => {
    if (!tokens || tokens.length === 0) return false;

    if (!isFirebaseInitialized) {
        initializeFirebase();
    }

    const message = {
        tokens: tokens,
        notification: {
            title: payload.title || 'Notification',
            body: payload.body || '',
        },
        data: payload.data || {}
    };

    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        (logger.info || console.log)(`✅ Successfully sent multicast notification. Success: ${response.successCount}, Failure: ${response.failureCount}`);
        return true;
    } catch (error) {
        (logger.error || console.error)('❌ Error sending multicast notification:', error);
        return false;
    }
};

module.exports = {
    initializeFirebase,
    sendNotification,
    sendMulticastNotification,
    admin
};
