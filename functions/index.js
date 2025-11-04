// The Firebase Admin SDK for accessing Firestore and FCM
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize the Firebase Admin SDK
admin.initializeApp();

// Access Firestore and Messaging services
const db = admin.firestore();
const messaging = admin.messaging();

/**
 * HTTPS Callable Function: Triggers a simulated FCM Data Message
 * containing two separate transaction entries (Expense and Income).
 * This function is called directly from your Flutter app's demo button.
 */
exports.simulateNotification = functions.https.onCall(async (data, context) => {
    // 1. Authentication Check
    const uid = context.auth?.uid;
    if (!uid) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be signed in to trigger the demo.');
    }

    // 2. Fetch the device token for the current user from Firestore
    const tokenDoc = await db.collection('users').doc(uid).get();

    // Check if data exists and safely access fcmToken (Fixes the parsing error)
    const userData = tokenDoc.data();
    const deviceToken = userData ? userData.fcmToken : null;

    if (!deviceToken) {
        throw new functions.https.HttpsError('failed-precondition', 'FCM token not found. Ensure your app has registered the token to Firestore.');
    }

    // 3. Define the two transaction payloads (Data Messages)
    const payloads = [
        {
            // Expense Transaction (Touch 'n Go)
            source: 'Touch \'n Go eWallet',
            text: 'Payment: You have paid RM13.50 for BOOST JUICEBARS - CITY JNCTN.',
            type: 'expense'
        },
        {
            // Income Transaction (Maybank2u)
            source: 'Maybank2u',
            text: "You've received money! COCO TEOH HUI HUI has transferred RM500.00 to you.",
            type: 'income'
        }
    ];

    // 4. Send both Data Messages via FCM
    const messages = payloads.map(payload => ({
        token: deviceToken,
        data: payload, // This is the payload your Flutter app's listener expects
        // Set high priority for immediate delivery
        android: { priority: 'high' },
        apns: { payload: { aps: { contcentAvailable: true } } },
    }));

    // Send all messages in parallel
    const response = await messaging.sendEach(messages);

    return {
        status: 'success',
        message: `${response.successCount} messages sent successfully.`
    };
});