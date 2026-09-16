// Point every Firebase SDK at the local emulators BEFORE any module loads.
// `demo-` project ids are offline-only: the SDK cannot reach production.
process.env.GCLOUD_PROJECT = 'demo-driveusa';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-driveusa' });
process.env.FIRESTORE_EMULATOR_HOST = '127.0.0.1:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';
process.env.PUBSUB_EMULATOR_HOST = '127.0.0.1:8085';
// defineSecret() values, local dummies only
process.env.APPLE_SHARED_SECRET = '0000000000000000000000000000dead';
process.env.GOOGLE_CREDENTIALS = '{"type":"service_account","project_id":"demo-driveusa"}';
