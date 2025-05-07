/**
 * State ID Migration Script
 * 
 * This script fixes state values in Firestore user documents:
 * 1. Converts full state names to two-letter state codes
 * 2. Fixes "null" string values to actual null
 * 3. Ensures all state values are either null or valid two-letter codes
 * 
 * Run with: node state_id_migration.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // You'll need to provide this

// State mapping - full names to IDs
const stateMap = {
  'ALABAMA': 'AL',
  'ALASKA': 'AK',
  'ARIZONA': 'AZ',
  'ARKANSAS': 'AR',
  'CALIFORNIA': 'CA',
  'COLORADO': 'CO',
  'CONNECTICUT': 'CT',
  'DELAWARE': 'DE',
  'DISTRICT OF COLUMBIA': 'DC',
  'FLORIDA': 'FL',
  'GEORGIA': 'GA',
  'HAWAII': 'HI',
  'IDAHO': 'ID',
  'ILLINOIS': 'IL',
  'INDIANA': 'IN',
  'IOWA': 'IA',
  'KANSAS': 'KS',
  'KENTUCKY': 'KY',
  'LOUISIANA': 'LA',
  'MAINE': 'ME',
  'MARYLAND': 'MD',
  'MASSACHUSETTS': 'MA',
  'MICHIGAN': 'MI',
  'MINNESOTA': 'MN',
  'MISSISSIPPI': 'MS',
  'MISSOURI': 'MO',
  'MONTANA': 'MT',
  'NEBRASKA': 'NE',
  'NEVADA': 'NV',
  'NEW HAMPSHIRE': 'NH',
  'NEW JERSEY': 'NJ',
  'NEW MEXICO': 'NM',
  'NEW YORK': 'NY',
  'NORTH CAROLINA': 'NC',
  'NORTH DAKOTA': 'ND',
  'OHIO': 'OH',
  'OKLAHOMA': 'OK',
  'OREGON': 'OR',
  'PENNSYLVANIA': 'PA',
  'RHODE ISLAND': 'RI',
  'SOUTH CAROLINA': 'SC',
  'SOUTH DAKOTA': 'SD',
  'TENNESSEE': 'TN',
  'TEXAS': 'TX',
  'UTAH': 'UT',
  'VERMONT': 'VT',
  'VIRGINIA': 'VA',
  'WASHINGTON': 'WA',
  'WEST VIRGINIA': 'WV',
  'WISCONSIN': 'WI',
  'WYOMING': 'WY',
};

// Valid state IDs set for quick validation
const validStateIds = new Set(Object.values(stateMap));

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function migrateStateIds() {
  console.log('Starting state ID migration...');
  
  // Get all user documents
  const usersSnapshot = await db.collection('users').get();
  
  if (usersSnapshot.empty) {
    console.log('No users found');
    return;
  }
  
  console.log(`Found ${usersSnapshot.size} user documents to process`);
  
  let updatedCount = 0;
  let skippedCount = 0;
  let errorCount = 0;
  
  // Process each user document
  for (const doc of usersSnapshot.docs) {
    try {
      const userData = doc.data();
      const userId = doc.id;
      const currentState = userData.state;
      
      console.log(`Processing user ${userId} with state value: ${currentState}`);
      
      let needsUpdate = false;
      let newState = currentState;
      
      // Case 1: "null" string
      if (currentState === "null") {
        console.log(`  - Converting "null" string to actual null for user ${userId}`);
        newState = null;
        needsUpdate = true;
      }
      // Case 2: Full state name (longer than 2 chars)
      else if (currentState && typeof currentState === 'string' && currentState.length > 2) {
        const upperState = currentState.toUpperCase();
        if (stateMap[upperState]) {
          console.log(`  - Converting state name "${currentState}" to ID "${stateMap[upperState]}" for user ${userId}`);
          newState = stateMap[upperState];
          needsUpdate = true;
        } else {
          console.log(`  - Warning: Unknown state name "${currentState}" for user ${userId}, setting to null`);
          newState = null;
          needsUpdate = true;
        }
      }
      // Case 3: Invalid state ID
      else if (currentState && typeof currentState === 'string' && currentState.length === 2) {
        const upperState = currentState.toUpperCase();
        if (!validStateIds.has(upperState)) {
          console.log(`  - Warning: Invalid state ID "${currentState}" for user ${userId}, setting to null`);
          newState = null;
          needsUpdate = true;
        } else if (currentState !== upperState) {
          // Case 4: Lowercase state ID - normalize to uppercase
          console.log(`  - Normalizing state ID "${currentState}" to "${upperState}" for user ${userId}`);
          newState = upperState;
          needsUpdate = true;
        }
      }
      
      // Update the document if needed
      if (needsUpdate) {
        await db.collection('users').doc(userId).update({
          state: newState,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        });
        console.log(`  - Updated user ${userId} state to: ${newState}`);
        updatedCount++;
      } else {
        console.log(`  - No changes needed for user ${userId}`);
        skippedCount++;
      }
    } catch (error) {
      console.error(`Error processing user ${doc.id}:`, error);
      errorCount++;
    }
  }
  
  console.log('\nMigration complete:');
  console.log(`- Updated: ${updatedCount} users`);
  console.log(`- Skipped: ${skippedCount} users`);
  console.log(`- Errors: ${errorCount} users`);
}

migrateStateIds()
  .then(() => {
    console.log('State ID migration completed successfully');
    process.exit(0);
  })
  .catch(error => {
    console.error('Error during state ID migration:', error);
    process.exit(1);
  });
