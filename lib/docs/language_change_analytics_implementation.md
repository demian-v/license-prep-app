# Language Change Analytics Implementation

## Overview
This document describes the implementation of language change analytics events that track user language selection in both signup and profile contexts, following the same pattern as signup and password reset events.

## Analytics Events Implemented

### 1. `language_selection_started`
**Contexts**: Signup flow, Profile screen
**Triggered**: When user opens language selection interface
**Parameters**:
- `selection_context`: "signup" | "profile"
- `current_language`: Current language before change
- `timestamp`: Current time in milliseconds

### 2. `language_changed`
**Contexts**: Signup flow, Profile screen
**Triggered**: When language is successfully changed
**Parameters**:
- `selection_context`: "signup" | "profile"
- `previous_language`: Language before change
- `new_language`: Language after change
- `language_name`: Human-readable name (e.g., "English", "Spanish")
- `time_spent_seconds`: Time spent in selection UI
- `timestamp`: Current time in milliseconds

### 3. `language_change_failed`
**Contexts**: Signup flow, Profile screen
**Triggered**: When language change fails
**Parameters**:
- `selection_context`: "signup" | "profile"
- `target_language`: Language user tried to change to
- `error_type`: Categorized error type
- `error_message`: Error details
- `timestamp`: Current time in milliseconds

## Implementation Details

### Files Modified:
1. `lib/services/analytics_service.dart` - Added 3 new analytics methods
2. `lib/screens/language_selection_screen.dart` - Signup context tracking
3. `lib/screens/profile_screen.dart` - Profile context tracking

### Key Features:
- **Context-Aware Tracking**: Distinguishes between signup and profile contexts
- **Comprehensive Timing**: Tracks time spent in selection interfaces
- **Detailed Error Categorization**: Specific error types for debugging
- **User Behavior Insights**: Previous/new language combinations
- **Privacy Compliant**: No personal data tracked

### Analytics Flow:
```
language_selection_started → language_changed ✅
language_selection_started → language_change_failed ❌
```

## Error Types

### Categorized Error Types:
- `provider_error`: Language provider update failed
- `auth_error`: Authentication provider update failed
- `network_error`: Network connectivity issues
- `unknown_error`: Unclassified errors

## Context-Specific Implementation

### Signup Context (`language_selection_screen.dart`):
- **Full-screen experience**: Dedicated language selection screen
- **Navigation flow**: Proceeds to state selection after language change
- **Timing tracking**: From screen load to language selection
- **Error handling**: Shows error snackbar, remains on screen

### Profile Context (`profile_screen.dart`):
- **Dialog-based experience**: Modal dialog for language selection
- **In-place update**: Updates profile screen immediately
- **Timing tracking**: From dialog open to language selection
- **Error handling**: Closes dialog, shows error snackbar

## Debug Output

Each analytics event includes debug logging for verification:
- `📊 Analytics: language_selection_started logged (context: signup)`
- `📊 Analytics: language_changed logged (signup: en → es)`
- `📊 Analytics: language_selection_started logged (context: profile)`
- `📊 Analytics: language_changed logged (profile: es → uk)`
- `📊 Analytics: language_change_failed logged (profile: ru)`

## Usage in Firebase Analytics Dashboard

These events will appear in Firebase Analytics and can be used to:

### 1. **Language Popularity Analysis**
- Track which languages are most popular
- Identify regional language preferences
- Monitor adoption rates of new language additions

### 2. **Context Comparison**
- Compare language selection behavior between signup and profile
- Identify if users change languages more during onboarding or later
- Understand context-specific preferences

### 3. **User Journey Analysis**
- Track complete language selection funnels
- Identify drop-off points in language selection
- Measure time spent making language decisions

### 4. **Error Monitoring**
- Monitor language change failure rates
- Identify problematic language combinations
- Track provider-specific errors for debugging

### 5. **Timing Analysis**
- Measure decision-making time for language selection
- Compare timing between contexts
- Identify users who switch languages frequently

## Analytics Insights You'll Get

### User Behavior:
- **Language switching patterns**: Do users change languages often?
- **Context preferences**: Signup vs profile language changes
- **Decision timing**: How long users spend choosing languages
- **Error patterns**: Which languages fail most often?

### Product Insights:
- **Popular languages**: Usage frequency by language
- **Conversion impact**: Does language selection affect signup completion?
- **User satisfaction**: Error rates as satisfaction indicator
- **Feature usage**: How often language selection is used

### Technical Insights:
- **Provider reliability**: Auth vs language provider error rates
- **Network issues**: Network-related language change failures
- **Performance metrics**: Time spent in language selection UIs

## Testing

### Manual Testing:
1. **Signup Flow**: Go through signup → language selection → verify events
2. **Profile Flow**: Profile → language selection → verify events
3. **Error Simulation**: Disconnect network during language change
4. **Timing Verification**: Check time calculations are accurate

### Expected Debug Output:
```
📊 Analytics: language_selection_started logged (context: signup)
📊 Analytics: language_changed logged (signup: en → es)
📊 Analytics: language_selection_started logged (context: profile)
📊 Analytics: language_changed logged (profile: es → uk)
📊 Analytics: language_change_failed logged (profile: ru)
```

### Firebase Analytics DebugView:
1. Enable Firebase Analytics debug mode
2. Run the app and perform language changes
3. Check DebugView for real-time event tracking
4. Verify all parameters are correctly sent

## Advanced Analytics Queries

### Popular Languages:
```sql
SELECT 
  new_language,
  COUNT(*) as changes
FROM language_changed
GROUP BY new_language
ORDER BY changes DESC
```

### Context Performance:
```sql
SELECT 
  selection_context,
  AVG(time_spent_seconds) as avg_time,
  COUNT(*) as total_changes
FROM language_changed
GROUP BY selection_context
```

### Error Analysis:
```sql
SELECT 
  error_type,
  selection_context,
  COUNT(*) as error_count
FROM language_change_failed
GROUP BY error_type, selection_context
```

## Future Enhancements

### Potential Additions:
- **Language retention tracking**: How long users keep selected languages
- **Multilingual usage patterns**: Users who switch between multiple languages
- **Regional language preferences**: Geographic analysis of language choices
- **Accessibility improvements**: Screen reader usage during language selection
- **Performance optimization**: Language loading time tracking

### Advanced Features:
- **A/B testing**: Different language selection UIs
- **Personalization**: Language recommendations based on usage
- **Smart defaults**: Auto-detect preferred language
- **Usage analytics**: Most used features per language

## Implementation Notes

### Code Organization:
- Analytics methods follow existing patterns in `analytics_service.dart`
- Error handling is consistent across both contexts
- Debug logging provides clear context and parameter information
- Timing calculations handle edge cases (null timestamps)

### Performance Considerations:
- Analytics calls are fire-and-forget (don't block UI)
- Error tracking doesn't impact user experience
- Timing calculations are efficient and accurate
- Debug logging can be disabled in production

### Privacy Compliance:
- No personal identifiable information is tracked
- Language preferences are anonymous
- Error messages are sanitized for privacy
- User consent is respected for analytics collection

This implementation provides comprehensive language change analytics that will help understand user behavior, improve the language selection experience, and identify areas for optimization.
