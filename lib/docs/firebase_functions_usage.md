# Firebase Functions Client Usage Guide

This document provides guidance on using the Firebase Functions Client in the License Prep App. The Firebase implementation offers an alternative to the traditional REST API, allowing the app to directly interact with Firebase Cloud Functions.

## Table of Contents
1. [Overview](#overview)
2. [Structure](#structure)
3. [Setting Up](#setting-up)
4. [Switching Implementations](#switching-implementations)
5. [Using the Firebase Functions Client](#using-the-firebase-functions-client)
6. [Function Name Mapping](#function-name-mapping)
7. [API Examples](#api-examples)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

## Overview

The Firebase Functions Client is a wrapper around the Firebase Cloud Functions API, allowing you to call backend functions directly from your Flutter app. This implementation leverages Firebase's serverless architecture, providing a simpler alternative to the traditional REST API.

## Structure

The implementation follows a clean architecture pattern with interfaces and concrete implementations:

```
lib/services/api/
├── base/
│   ├── auth_api_interface.dart
│   ├── content_api_interface.dart
│   ├── progress_api_interface.dart
│   └── subscription_api_interface.dart
├── api_implementation.dart
├── firebase_functions_client.dart
├── firebase_auth_api.dart
├── firebase_content_api.dart
├── firebase_progress_api.dart
└── firebase_subscription_api.dart
```

- The `base/` directory contains interfaces that both REST and Firebase implementations must conform to
- `firebase_functions_client.dart` provides a generic client for calling any Firebase Function
- Domain-specific API classes (auth, content, etc.) provide specialized wrappers for common functions

## Setting Up

The app is configured to use either the REST API or Firebase Functions API through the service locator. By default, the REST API is used. To switch to the Firebase implementation, use the `ApiServiceConfigurator`:

```dart
import '../services/api_service_configurator.dart';
import '../services/api/api_implementation.dart';

// Switch to Firebase implementation
await apiServiceConfigurator.switchImplementation(ApiImplementation.firebase);

// Switch back to REST implementation
await apiServiceConfigurator.switchImplementation(ApiImplementation.rest);
```

## Switching Implementations

You can toggle between REST and Firebase implementations at runtime:

1. Use the Service Locator's interface-based getters:
   ```dart
   // This will use whichever implementation is currently active
   final user = await serviceLocator.auth.getCurrentUser();
   final topics = await serviceLocator.content.getQuizTopics('drivers', 'en', 'IL');
   ```

2. For existing code using the direct API getters, the ServiceLocator will return the appropriate implementation:
   ```dart
   // This will continue to work with either implementation
   final user = await serviceLocator.authApi.getCurrentUser();
   ```

## Using the Firebase Functions Client

The `FirebaseFunctionsClient` provides a generic way to call any Firebase Cloud Function:

```dart
final functionsClient = serviceLocator.firebaseFunctionsClient;

// Call a function with parameters
final result = await functionsClient.callFunction<Map<String, dynamic>>(
  'updateUserProfile',
  data: {
    'name': 'John Doe',
    'language': 'en',
  },
);

// Call a function without parameters
final userData = await functionsClient.callFunction<Map<String, dynamic>>(
  'getUserData',
);
```

When calling functions, you don't need to worry about the exact Cloud Function name - the client automatically maps your function name to the correct Cloud Function name using the `FunctionNameMapper` (see next section).

## Function Name Mapping

To solve the mismatch between client-side function names and actual Cloud Function names, we've implemented a function name mapping mechanism. This allows the app code to use consistent function names while correctly mapping to the deployed Cloud Functions.

### How it Works

The `FunctionNameMapper` class in `firebase_functions_client.dart` contains a mapping between client-side function names and Cloud Function names:

```dart
static const Map<String, String> _nameMap = {
  // Auth functions
  'loginUser': 'getUserData',
  'registerUser': 'createUserRecord',
  
  // Content functions
  'getQuizTopics': 'content-getQuizTopics',
  // ... more mappings
};
```

When you call a function through the `FirebaseFunctionsClient`:

1. The client-side function name (e.g., 'loginUser') is passed to `callFunction()`
2. The `FunctionNameMapper` translates it to the actual Cloud Function name (e.g., 'getUserData')
3. The Firebase SDK calls the correct Cloud Function

This mapping is completely transparent to the caller, allowing you to maintain a consistent API in your code regardless of the actual Cloud Function names.

### Benefits

- **Decoupling**: Client code is decoupled from server-side function names
- **Flexibility**: Server-side function names can change without requiring client code changes
- **Modularity**: Makes it easier to organize and prefix Cloud Functions by domain (auth, content, etc.)
- **Migration**: Facilitates gradual migration between different backend implementations

## API Examples

### Authentication

```dart
// Get current user
final user = await serviceLocator.firebaseAuthApi.getCurrentUser();

// Update user profile
final updatedUser = await serviceLocator.firebaseAuthApi.updateProfile(
  userId,
  name: 'John Doe',
  language: 'en',
  state: 'IL',
);
```

### Content

```dart
// Get quiz topics
final topics = await serviceLocator.firebaseContentApi.getQuizTopics(
  'drivers',
  'en',
  'IL',
);

// Get theory modules
final modules = await serviceLocator.firebaseContentApi.getTheoryModules(
  'drivers',
  'en',
  'IL',
);
```

### Progress

```dart
// Update module progress
final result = await serviceLocator.firebaseProgressApi.updateModuleProgress(
  'module-123',
  0.75,
);

// Save test score
final scoreResult = await serviceLocator.firebaseProgressApi.saveTestScore(
  'test-123',
  85.5,
  'practice',
);
```

### Subscription

```dart
// Check subscription status
final isActive = await serviceLocator.firebaseSubscriptionApi.isSubscriptionActive();

// Subscribe to a plan
final subscription = await serviceLocator.firebaseSubscriptionApi.subscribeToPlan(
  'premium-monthly',
);
```

## Best Practices

1. **Use Interface-Based Access**: Whenever possible, use the interface-based getters from the service locator:
   ```dart
   // Good - works with any implementation
   final user = await serviceLocator.auth.getCurrentUser();
   
   // Avoid - tied to specific implementation
   final user = await serviceLocator.firebaseAuthApi.getCurrentUser();
   ```

2. **Gradual Migration**: If migrating an existing app, you can switch one feature at a time to the Firebase implementation.

3. **Error Handling**: All Firebase function calls include proper error handling. Make sure to catch and handle these errors appropriately in your UI.

4. **Function Naming**: When adding new functions, follow the established naming convention and update the `FunctionNameMapper` if needed.

5. **Testing**: You can use the `ApiServiceConfigurator` to switch between implementations during testing to ensure both work correctly.

## Troubleshooting

### Common Issues

1. **Authentication Errors**: Make sure the user is properly authenticated before calling secured Firebase functions.

2. **Missing Data**: The Firebase functions expect specific parameters. Check that you're providing all required parameters in the correct format.

3. **Type Errors**: When using `callFunction<T>()`, ensure the generic type parameter matches the actual return type of the function.

4. **Network Issues**: Firebase functions require an internet connection. Add appropriate offline handling in your app.

5. **Function Name Mismatches**: If you're getting "Function not found" errors, check that the function name is correctly mapped in the `FunctionNameMapper`. The error message will show which function name was actually called.
