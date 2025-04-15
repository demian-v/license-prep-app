# Firebase Authentication Configuration Guide

This guide will help you configure Firebase Authentication to use your custom password reset flow instead of the default Firebase UI.

## Step 1: Deploy the Auth Redirect Page

The first step is to deploy the auth-redirect.html page we've created. This page will handle the redirection from Firebase to your app.

1. Make sure your Firebase project has hosting enabled
2. Deploy the auth-redirect.html page to your Firebase hosting

```bash
firebase deploy --only hosting:web/auth-redirect.html
```

## Step 2: Configure Firebase Authentication Email Templates

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. In the left sidebar, click on "Authentication"
4. Navigate to the "Templates" tab
5. Select "Password reset" from the template list
6. Edit the template:
   - Customize the email content as needed
   - Set the "Action URL" to your redirect page URL:
     ```
     https://licenseprepapp.firebaseapp.com/auth-redirect.html?mode=resetPassword&oobCode={oobCode}
     ```
   - Make sure to include `?mode=resetPassword&oobCode={oobCode}` at the end of the URL
   - The `{oobCode}` parameter will be automatically filled by Firebase

7. Save the changes

## Step 3: Test the Password Reset Flow

1. Go to your app's login screen
2. Click "Forgot Password"
3. Enter your email and request a reset link
4. Check your email for the reset link
5. Click the link in the email
6. You should be redirected to your custom app's password reset screen with both password fields

## Troubleshooting

If the redirect doesn't work properly:

1. Check that your app's deep link configuration is correct in AndroidManifest.xml and Info.plist
2. Verify that the auth-redirect.html page is correctly deployed and accessible
3. Check the Firebase Authentication template settings to ensure the Action URL is correctly set
4. Test on both Android and iOS devices to ensure cross-platform compatibility

## Firebase Console Authentication Setup Screenshots

### Password Reset Template Configuration
![Password Reset Template](https://example.com/password_reset_template.png)

### Action URL Configuration
![Action URL Configuration](https://example.com/action_url_config.png)

Note: Replace the example screenshot URLs with actual screenshots when available.
