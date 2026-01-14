# 📱 iOS App Deployment & Sandbox Testing Checklist
**Drive USA - License Prep App**  
**Version:** 1.0.2 (Build 3)  
**Date:** January 13, 2026

---

## ✅ COMPLETED - Phase 1: Code Updates

- [x] Updated product IDs from `monthly_subscription`/`yearly_subscription` to `monthly`/`yearly`
- [x] Bumped version from 1.0.1+2 to 1.0.2+3
- [x] Ran `flutter pub get`
- [x] Cleaned project with `flutter clean`
- [x] Built iOS release version successfully

**Build Output:** `build/ios/iphoneos/Runner.app` (60.2MB)

---

## 📋 Phase 2: Xcode Archive & Upload

### Step 1: Open Project in Xcode
```bash
cd /Users/demianvyrozub/projects/license-prep-app
open ios/Runner.xcworkspace
```

⚠️ **IMPORTANT:** Open `.xcworkspace`, NOT `.xcodeproj`

---

### Step 2: Select Target Device
- [ ] In Xcode toolbar, click on device dropdown
- [ ] Select **"Any iOS Device (arm64)"**
- [ ] Do NOT select a simulator

---

### Step 3: Clean Build Folder (Optional but Recommended)
- [ ] Menu: **Product → Clean Build Folder** (⇧⌘K)
- [ ] Wait for cleaning to complete

---

### Step 4: Build Project First
- [ ] Menu: **Product → Build** (⌘B)
- [ ] Wait for build to succeed
- [ ] Check for any warnings or errors
- [ ] Fix any issues before proceeding

---

### Step 5: Archive the App
- [ ] Menu: **Product → Archive** (⌃⌘A)
- [ ] Wait 5-10 minutes for archive process
- [ ] Xcode Organizer window will open automatically

**What this does:**
- Compiles app in release mode
- Signs with your distribution certificate
- Creates archive ready for App Store

---

### Step 6: Validate Archive
Before uploading, validate to catch errors:

- [ ] In Organizer, select your new archive (should be at top)
- [ ] Click **"Validate App"** button
- [ ] Distribution options screen appears:
  - [ ] Select **"App Store Connect"**
  - [ ] Click **"Next"**
- [ ] App Store Connect settings:
  - [ ] Keep **"Upload your app's symbols"** checked ✅
  - [ ] Keep **"Manage version and build number"** checked ✅
  - [ ] Click **"Next"**
- [ ] Signing options:
  - [ ] Select **"Automatically manage signing"** (recommended)
  - [ ] Click **"Next"**
- [ ] Review and click **"Validate"**
- [ ] Wait for validation (2-5 minutes)

**Expected Result:** ✅ "Validation Successful"

**If validation fails:**
- Read error message carefully
- Common issues:
  - Missing entitlements
  - Provisioning profile issues
  - Missing in-app purchase capability
- Fix issues and try again

---

### Step 7: Distribute Archive to App Store Connect
- [ ] In Organizer, with archive selected, click **"Distribute App"**
- [ ] Distribution method:
  - [ ] Select **"App Store Connect"**
  - [ ] Click **"Next"**
- [ ] Destination:
  - [ ] Select **"Upload"**
  - [ ] Click **"Next"**
- [ ] App Store Connect options:
  - [ ] Keep **"Upload your app's symbols"** checked ✅
  - [ ] Keep **"Manage version and build number"** checked ✅
  - [ ] Click **"Next"**
- [ ] Signing:
  - [ ] Select **"Automatically manage signing"**
  - [ ] Click **"Next"**
- [ ] Review summary:
  - [ ] Verify app name: **Drive USA**
  - [ ] Verify bundle ID: **com.driveusa.app**
  - [ ] Verify version: **1.0.2 (3)**
  - [ ] Click **"Upload"**
- [ ] Wait for upload (10-30 minutes depending on connection)

**Upload Status Messages:**
1. "Uploading..." (progress bar)
2. "Upload Complete"
3. Email from Apple: "App Store Connect: Build processed"

---

### Step 8: Verify Upload in App Store Connect
- [ ] Open browser to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Sign in with your Apple Developer account
- [ ] Go to **My Apps → Drive USA Theory and Practice**
- [ ] Click **TestFlight** tab at top
- [ ] Look for **iOS Builds** section
- [ ] Verify build **1.0.2 (3)** appears with status:
  - **"Processing"** - Wait 10-60 minutes ⏳
  - **"Ready to Submit"** - Processing complete! ✅

⚠️ **Don't proceed until build shows "Ready to Submit"**

Check your email for confirmation from Apple.

---

## 📱 Phase 3: App Store Connect Configuration

### Step 9: Verify/Complete Subscription Products

#### Check Product IDs Match
- [ ] Go to App Store Connect → Your App → **Subscriptions**
- [ ] Verify you have TWO subscriptions in "premium_access" group:

**Subscription 1: Monthly Premium Access**
- [ ] Product ID: **`monthly`** (exactly, case-sensitive)
- [ ] Reference Name: "Monthly Premium Access"
- [ ] Subscription Duration: **1 month**
- [ ] Status: Not "Missing Metadata"

**Subscription 2: Yearly Premium Access**
- [ ] Product ID: **`yearly`** (exactly, case-sensitive)
- [ ] Reference Name: "Yearly Premium Access"  
- [ ] Subscription Duration: **1 year**
- [ ] Status: Not "Missing Metadata"

⚠️ **CRITICAL:** Product IDs MUST be exactly `monthly` and `yearly`

**If Product IDs are wrong:**
- You cannot change product IDs after creation
- Delete incorrect subscriptions
- Create new ones with correct IDs
- Wait 24-48 hours for them to propagate

---

#### Complete Monthly Subscription
- [ ] Click on **Monthly Premium Access**
- [ ] **Subscription Duration:** Select **1 month**
- [ ] **Subscription Prices:**
  - [ ] Click **"All Prices and Currencies"**
  - [ ] Set base price (e.g., $9.99/month)
  - [ ] Review auto-calculated international prices
  - [ ] Click **"Next"**
  - [ ] Review and click **"Apply Prices"**
- [ ] **Availability:**
  - [ ] Click **"Set Up Availability"**
  - [ ] Choose countries/regions:
    - [ ] At minimum: United States (for testing)
    - [ ] Or: All countries
  - [ ] Click **"Save"**
- [ ] **Subscription Display Name:** "Monthly Premium Access" (confirm)
- [ ] **Description:** Add clear description of benefits
  ```
  Get unlimited access to all 50 state DMV practice tests, theory modules, 
  and road sign questions. Perfect for preparing for your driver's license exam!
  ```
- [ ] **Family Sharing:** Turn On (recommended) or leave off
- [ ] Click **"Save"** in top right

---

#### Complete Yearly Subscription
- [ ] Click on **Yearly Premium Access**
- [ ] **Subscription Duration:** Select **1 year**
- [ ] **Subscription Prices:**
  - [ ] Click **"All Prices and Currencies"**
  - [ ] Set base price (e.g., $79.99/year - ~33% discount)
  - [ ] Review auto-calculated international prices
  - [ ] Click **"Next"**
  - [ ] Review and click **"Apply Prices"**
- [ ] **Availability:**
  - [ ] Click **"Set Up Availability"**
  - [ ] Choose same countries as monthly
  - [ ] Click **"Save"**
- [ ] **Subscription Display Name:** "Yearly Premium Access" (confirm)
- [ ] **Description:** Add clear description of benefits
  ```
  Get unlimited access to all 50 state DMV practice tests, theory modules, 
  and road sign questions for a full year. Best value - save 33% compared to monthly!
  ```
- [ ] **Family Sharing:** Match monthly setting
- [ ] Click **"Save"**

---

### Step 10: Link Subscriptions to App Version

⚠️ **Critical Step:** Apple requires subscriptions to be submitted with an app version

- [ ] Go to **Distribution** tab (or **App Store** tab)
- [ ] Click on version **1.0.2** (or create new version if needed)
- [ ] Scroll down to **"In-App Purchases and Subscriptions"** section
- [ ] Click **"+"** button to add subscriptions
- [ ] In popup, select:
  - [ ] ✅ Monthly Premium Access
  - [ ] ✅ Yearly Premium Access
- [ ] Click **"Done"**
- [ ] Verify both appear in the list
- [ ] Click **"Save"** at top right

---

### Step 11: Complete App Version Metadata (if not done)

Before submitting for review, ensure these are complete:

- [ ] **App Description:** Clear description of app features
- [ ] **Keywords:** Relevant search keywords
- [ ] **Screenshots:** All required device sizes
  - iPhone 6.9" Display
  - iPhone 6.7" Display
  - iPhone 6.5" Display
  - iPhone 5.5" Display (optional but recommended)
- [ ] **App Icon:** 1024x1024px icon uploaded
- [ ] **Age Rating:** Appropriate rating selected
- [ ] **Privacy Policy URL:** Valid URL to privacy policy

---

### Step 12: Add Build to App Version
- [ ] In version 1.0.2 settings, scroll to **"Build"** section
- [ ] Click **"Select a build before you submit your app"**
- [ ] Select build **1.0.2 (3)** from list
- [ ] Click **"Done"**
- [ ] Verify build appears

---

### Step 13: Submit App for Review (Optional - for Production)

⚠️ **Note:** You can test in sandbox WITHOUT submitting for review!

If you want to submit now:

- [ ] Scroll to top of app version page
- [ ] Click **"Add for Review"** button
- [ ] Fill out **App Review Information:**
  - [ ] Sign-in credentials (test account)
  - [ ] Contact information
  - [ ] Notes for reviewer:
  ```
  This version includes in-app purchase subscriptions for premium content access.
  
  Test Account:
  Email: [provide test account email]
  Password: [provide test account password]
  
  Subscription Products:
  - Monthly Premium Access ($9.99/month)
  - Yearly Premium Access ($79.99/year)
  
  To test subscriptions, purchase either option after signing in. 
  All DMV practice tests and study materials will be unlocked.
  ```
- [ ] Review all information
- [ ] Click **"Submit for Review"**

**Review Timeline:** Typically 1-3 business days

---

## 🧪 Phase 4: TestFlight Setup & Sandbox Testing

### Step 14: Create Sandbox Test Account

- [ ] Go to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Click **Users and Access** in top right
- [ ] Click **Sandbox Testers** in left sidebar
- [ ] Click **"+"** to add new tester
- [ ] Fill in details:
  - **First Name:** Test
  - **Last Name:** User
  - **Email:** **MUST be unique** (never used for real Apple ID)
    - Example: `driveusa.test1@icloud.com` (use + trick)
    - Or: Create new email just for testing
  - **Password:** Strong password (save it!)
  - **Confirm Password:** Same password
  - **Territory:** United States
  - **App Store Territory:** United States
- [ ] Click **"Invite"**
- [ ] **IMPORTANT:** Do NOT verify this email address!

⚠️ **Sandbox Email Rules:**
- Must be unique (not used anywhere else)
- Don't need to be real/accessible email
- Can create multiple for testing different scenarios
- Common pattern: `yourapp.test1@example.com`

**Save Credentials:**
```
Sandbox Test Account #1
Email: _______________________
Password: _____________________
```

---

### Step 15: Add Internal TestFlight Testers

- [ ] Go to App Store Connect → Your App → **TestFlight** tab
- [ ] Click **Internal Testing** in left sidebar
- [ ] If no group exists, click **"+"** to create one:
  - [ ] Name it "Internal Testers" or "Development Team"
  - [ ] Check **"Enable automatic distribution"** ✅
  - [ ] Click **"Create"**
- [ ] Click on your internal group
- [ ] Click **"+"** next to Testers
- [ ] Add your Apple ID email (the one you use for development)
- [ ] Click **"Add"**
- [ ] Verify build 1.0.2 (3) is added to this group
- [ ] If not, click **"+"** next to builds and add it

**You'll receive email:** "You're Invited to Test Drive USA Theory and Practice"

---

### Step 16: Install TestFlight on Test Device

**On your iPhone/iPad:**
- [ ] Go to App Store
- [ ] Search for "TestFlight"
- [ ] Download and install TestFlight app (free, by Apple)
- [ ] Open TestFlight app
- [ ] Accept invite (either via email link or code)
- [ ] Download "Drive USA Theory and Practice" beta
- [ ] Install the app

---

### Step 17: Prepare Test Device for Sandbox

⚠️ **CRITICAL:** Must sign out of App Store BEFORE testing

**On your test device:**
- [ ] Go to **Settings**
- [ ] Tap your name at top
- [ ] Scroll down to **"Media & Purchases"**
- [ ] Tap **"Sign Out"**
- [ ] Confirm sign out

**Alternative path:**
- [ ] Settings → App Store
- [ ] Tap on your Apple ID at top
- [ ] Tap **"Sign Out"**

⚠️ **DO NOT:**
- Sign in with sandbox account yet
- Sign out of iCloud (only App Store)
- Delete existing app installations yet

---

### Step 18: Test In-App Purchase Flow (Sandbox)

#### First Purchase Test: Monthly Subscription

- [ ] **Delete app if previously installed** (to start fresh)
- [ ] Open TestFlight app
- [ ] Install Drive USA app from TestFlight
- [ ] Launch Drive USA app
- [ ] Sign in with your regular user account (or create new test user)
- [ ] Navigate to subscription/payment screen in app
- [ ] Tap to purchase **Monthly** subscription
- [ ] App Store purchase dialog appears
- [ ] **NOW sign in with sandbox account**
  - [ ] When prompted for Apple ID, enter sandbox email
  - [ ] Enter sandbox password
  - [ ] May see "This Apple ID is only for testing"
- [ ] Confirm purchase
- [ ] **Purchase is FREE in sandbox** - no money charged

**Verify in App:**
- [ ] App shows purchase success message
- [ ] Premium features are now unlocked
- [ ] User can access all content

**Expected Debug Logs (if debugging):**
```
🛒 Starting purchase for monthly
✅ Purchase successful: monthly
🔐 Validating receipt for monthly
📡 Calling Firebase function: validatePurchaseReceipt
✅ Receipt validated successfully!
📦 Subscription ID: [firestore-doc-id]
⏰ Expires at: [date-5-minutes-from-now]
```

---

#### Verify Backend Receipt Validation

- [ ] Open Firebase Console
- [ ] Go to **Firestore Database**
- [ ] Open **subscriptions** collection
- [ ] Find document for your test user
- [ ] Verify fields:
  ```
  {
    userId: "your-test-user-id",
    planType: "monthly",      ✅ Should be "monthly" not "monthly_subscription"
    platform: "ios",
    isActive: true,
    status: "active",
    productId: "monthly",
    transactionId: "1000000...",  // Apple transaction ID
    nextBillingDate: [timestamp 5 minutes from now],
    duration: 30,
    price: 9.99,
    createdAt: [timestamp],
    updatedAt: [timestamp],
    transactions: [{
      transactionId: "1000000...",
      platform: "ios",
      date: [timestamp],
      productId: "monthly",
      amount: 9.99
    }]
  }
  ```

- [ ] Open **subscriptionLogs** collection
- [ ] Find latest log for your user
- [ ] Verify success entry:
  ```
  {
    userId: "your-test-user-id",
    action: "receipt_validated",
    platform: "ios",
    productId: "monthly",
    subscriptionId: "[doc-id]",
    transactionId: "1000000...",
    expiresAt: [timestamp],
    timestamp: [timestamp],
    success: true
  }
  ```

- [ ] Go to **Functions → Logs**
- [ ] Filter by function name: `validatePurchaseReceipt`
- [ ] Look for success logs:
  ```
  🍎 Validating Apple receipt...
  ✅ Receipt validation successful
  ✅ Subscription created/updated
  ```

---

#### Test Subscription Renewal (Sandbox Accelerated Time)

**Sandbox Subscription Timescales:**
- 1 week subscription → 3 minutes
- 1 month subscription → 5 minutes
- 2 months subscription → 10 minutes
- 3 months subscription → 15 minutes
- 6 months subscription → 30 minutes
- 1 year subscription → 1 hour

**Your monthly subscription will renew in 5 minutes!**

- [ ] Wait 5 minutes after purchase
- [ ] **Auto-renewal should occur**
- [ ] Check Firestore `subscriptions` document:
  - [ ] `nextBillingDate` updated to +5 minutes again
  - [ ] New transaction added to `transactions` array
- [ ] Sandbox allows 6 renewals max per account
- [ ] After 6 renewals, subscription expires

**Test renewal by:**
- [ ] Keeping app open for 5+ minutes
- [ ] Checking if premium access still works
- [ ] Verifying in Firestore that renewal happened

---

#### Test Subscription Cancellation

- [ ] On test device, go to **Settings**
- [ ] Tap your name at top
- [ ] Tap **Subscriptions**
- [ ] Find "Drive USA" subscription
- [ ] Tap to open details
- [ ] Tap **"Cancel Subscription"**
- [ ] Confirm cancellation
- [ ] Subscription will remain active until expiry
- [ ] Will not auto-renew after current period

**Verify:**
- [ ] Subscription still active until expiry
- [ ] After expiry (5 minutes in sandbox), access removed
- [ ] Check Firestore: `status` changes to "cancelled" or "expired"

---

#### Test Yearly Subscription

- [ ] Create NEW sandbox test account (or use different device)
- [ ] Repeat purchase flow with **Yearly** subscription
- [ ] Verify:
  - [ ] Purchase succeeds
  - [ ] Receipt validated
  - [ ] Firestore shows `planType: "yearly"`
  - [ ] `duration: 365`
  - [ ] Renewal in 1 hour (sandbox time)

---

#### Test Restore Purchases (iOS)

- [ ] Delete app from device
- [ ] Reinstall from TestFlight
- [ ] Sign in to app with same user account
- [ ] Navigate to subscription screen
- [ ] Tap **"Restore Purchases"** button (if you have one)
- [ ] Or just try to purchase again
- [ ] Should receive message: "You're already subscribed"
- [ ] Premium features should unlock

---

#### Test Upgrade from Monthly to Yearly

- [ ] Have active monthly subscription
- [ ] Try to purchase yearly subscription
- [ ] Should upgrade immediately
- [ ] Prorated credit applied in real store (not visible in sandbox)
- [ ] Verify in Firestore:
  - [ ] `planType` changed from "monthly" to "yearly"
  - [ ] New transaction added with `upgradeFrom: "monthly"`

---

### Step 19: Test Edge Cases & Error Scenarios

#### Test: Product IDs Not Found
- [ ] Temporarily change product IDs in App Store Connect
- [ ] Try to make purchase in app
- [ ] Should see error: "Products not available"
- [ ] Revert product IDs back

#### Test: Network Failure During Validation
- [ ] Enable Airplane Mode after purchase completes
- [ ] Purchase will complete with Apple
- [ ] Receipt validation may fail
- [ ] Disable Airplane Mode
- [ ] App should retry validation on next launch

#### Test: Rate Limiting
Your backend allows 10 validation attempts per hour
- [ ] Make 11+ purchase attempts in one hour
- [ ] Should see error: "Rate limit exceeded"
- [ ] Wait 1 hour or clear logs in Firestore

#### Test: Invalid Receipt
This is hard to test without modifying code, but backend handles it:
- Backend returns `valid: false` with error message
- App shows user-friendly error

---

## ✅ Phase 5: Production Deployment (After Testing)

### Step 20: Verify Everything Works
- [ ] All sandbox purchases succeeded
- [ ] Receipt validation working
- [ ] Firestore data correct
- [ ] Auto-renewal working
- [ ] Cancellation working
- [ ] Restore purchases working
- [ ] No crashes or errors

### Step 21: Submit for App Review (if not done already)
- [ ] Follow Step 13 above
- [ ] Wait for Apple's review (1-3 days)
- [ ] Respond to any feedback from Apple

### Step 22: Release to App Store
Once approved:
- [ ] Go to App Store Connect → Your App → Distribution
- [ ] Version status shows "Pending Developer Release"
- [ ] Click **"Release this Version"**
- [ ] Or set up automatic release
- [ ] App goes live on App Store

### Step 23: Monitor Real Purchases
After release:
- [ ] Monitor Firestore for real purchases
- [ ] Check Firebase Functions logs for errors
- [ ] Monitor subscription renewals
- [ ] Track any failed validations
- [ ] Respond to user reports

---

## 🔍 Troubleshooting Guide

### Issue: Build Fails to Upload
**Symptoms:** Upload hangs or fails
**Solutions:**
- Check internet connection
- Try uploading via Xcode Organizer instead
- Use Application Loader (legacy tool)
- Check Apple's system status page

### Issue: Products Not Loading in App
**Symptoms:** App shows "No products available"
**Solutions:**
- Verify product IDs match exactly (`monthly` and `yearly`)
- Wait 2-4 hours after creating products
- Check products are in "Ready to Submit" status
- Clear app data and reinstall
- Check App Store Connect API is enabled

### Issue: Receipt Validation Fails
**Symptoms:** Purchase succeeds but backend returns error
**Check:**
- Firebase Functions logs for specific error
- Apple shared secret is configured correctly:
  ```bash
  firebase functions:config:get apple.shared_secret
  ```
- Product ID matches database (`monthly` not `monthly_subscription`)
- Receipt is being sent to correct environment (sandbox vs production)

### Issue: Sandbox Account Not Working
**Symptoms:** Can't sign in or purchases fail
**Solutions:**
- Make sure you signed OUT of real App Store first
- Use completely new email address for sandbox account
- Don't verify sandbox email address
- Delete sandbox account and create new one
- Try on different device

### Issue: Auto-Renewal Not Happening
**Symptoms:** Subscription doesn't renew after 5 minutes
**Check:**
- Sandbox subscriptions renew max 6 times
- Device has internet connection
- App is running or has run recently
- Check Firebase scheduler jobs are running

### Issue: Firebase Function Timeout
**Symptoms:** "Deadline exceeded" error
**Solutions:**
- Check internet connectivity to Apple/Google servers
- Increase function timeout in Firebase
- Retry logic should handle this automatically

---

## 📊 Success Criteria Checklist

### Before Marking Complete:
- [ ] iOS build created successfully
- [ ] Uploaded to App Store Connect
- [ ] Product IDs verified as `monthly` and `yearly`
- [ ] Subscriptions configured with pricing and availability
- [ ] Subscriptions linked to app version
- [ ] Sandbox test account created
- [ ] TestFlight installation successful
- [ ] Monthly subscription purchase successful in sandbox
- [ ] Receipt validated by backend
- [ ] Firestore subscription record created correctly
- [ ] Auto-renewal tested and working
- [ ] Cancellation tested and working
- [ ] Yearly subscription tested
- [ ] No errors in Firebase Functions logs
- [ ] App behavior matches expected flow

---

## 📞 Support & Resources

### Apple Documentation
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [TestFlight Help](https://help.apple.com/app-store-connect/#/devdc42b26b8)
- [In-App Purchase Guide](https://developer.apple.com/in-app-purchase/)
- [Sandbox Testing](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)

### Firebase Documentation
- [Cloud Functions](https://firebase.google.com/docs/functions)
- [Firestore Database](https://firebase.google.com/docs/firestore)

### Your Implementation Docs
- `PAYMENT_SYSTEM_IMPLEMENTATION.md` - Complete system documentation
- Firebase Console: https://console.firebase.google.com/project/licenseprepapp

---

## ✅ Final Notes

**What Changed:**
- Product IDs: `monthly_subscription` → `monthly`
- Product IDs: `yearly_subscription` → `yearly`
- Version: 1.0.1+2 → 1.0.2+3
- Build created and ready for upload

**What's Ready:**
- ✅ Code updated and tested
- ✅ iOS build created
- ✅ Backend already configured
- ✅ Firebase Functions deployed
- ✅ Database structure correct

**Next Steps:**
1. Archive in Xcode (Step 5)
2. Upload to App Store Connect (Step 7)
3. Configure subscriptions (Step 9)
4. Test in sandbox (Step 18)
5. Submit for review when ready (Step 13)

---

**Good luck with your deployment! 🚀**

**Questions?** Review the troubleshooting section or check Firebase logs for detailed error messages.
