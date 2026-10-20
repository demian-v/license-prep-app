import { initializeApp } from 'firebase/app';
import { connectAuthEmulator, getAuth } from 'firebase/auth';
import { connectFunctionsEmulator, getFunctions } from 'firebase/functions';

/**
 * P10a: the dashboard runs locally against the emulators only. The Hosting
 * site, the production web config and the owner's admins/{uid} doc are P11
 * (instructors plan v2 §18a, TODO «P11»). The Auth emulator accepts any API
 * key, so no real one is in this public repo.
 */
const LOCAL = ['localhost', '127.0.0.1', '[::1]'];
if (!LOCAL.includes(location.hostname)) {
  throw new Error('The DriveUSA admin panel runs locally against the emulators until P11.');
}

export const app = initializeApp({ apiKey: 'emulator-only', authDomain: 'localhost', projectId: 'licenseprepapp' });
export const auth = getAuth(app);
export const functions = getFunctions(app, 'us-central1');
connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
connectFunctionsEmulator(functions, '127.0.0.1', 5001);
