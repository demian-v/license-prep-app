# Theory Module Analytics Implementation

## Overview

This document describes the complete analytics implementation for theory module learning flow in the License Prep App. The implementation tracks user engagement across the 2-screen theory learning journey: **TheoryScreen** → **TrafficRuleContentScreen**.

## Analytics Events Implemented

### 1. Module Discovery & Selection Events (4 events)

#### `theory_module_list_viewed`
**Trigger**: When TheoryScreen loads successfully with modules
**Purpose**: Track successful module list views
**Parameters**:
- `module_count` (int) - Number of modules available
- `state` (string) - User's selected state 
- `language` (string) - Current language setting
- `license_type` (string) - License type (default: 'driver')
- `timestamp` (int) - Event timestamp

#### `theory_module_list_empty`
**Trigger**: When TheoryScreen shows empty state (no modules found)
**Purpose**: Track empty states for content optimization with loading context
**Parameters**:
- `empty_reason` (string) - Reason for empty state ('loading', 'language', 'state', 'language_and_state', 'no_content', 'unknown')
- `requested_state` (string) - State that was requested
- `requested_language` (string) - Language that was requested  
- `requested_license_type` (string) - License type that was requested
- `loading_duration_ms` (int) - Loading time in milliseconds (only for 'loading' events)
- `timestamp` (int) - Event timestamp

#### `theory_module_selected`
**Trigger**: When user taps on a module card
**Purpose**: Track module selection patterns and engagement timing
**Parameters**:
- `module_id` (string) - Theory module identifier
- `module_title` (string) - Human-readable module name
- `time_on_list_seconds` (int) - Time spent browsing module list
- `state` (string) - User's selected state
- `language` (string) - Current language setting
- `license_type` (string) - License type
- `timestamp` (int) - Event timestamp

#### `theory_module_list_failed`
**Trigger**: When TheoryScreen fails to load modules (technical error)
**Purpose**: Track technical failures for debugging
**Parameters**:
- `error_type` (string) - Categorized error type
- `error_message` (string) - Truncated error details (max 100 chars)
- `state` (string) - User's selected state
- `language` (string) - Current language setting
- `license_type` (string) - License type
- `timestamp` (int) - Event timestamp

### 2. Content Reading Events (3 events)

#### `theory_content_viewed`
**Trigger**: When TrafficRuleContentScreen loads successfully
**Purpose**: Track successful content views and reading patterns
**Parameters**:
- `module_id` (string) - Module identifier (null - not available in topic model)
- `module_title` (string) - Module title (null - not available in topic model)
- `topic_id` (string) - Topic identifier
- `topic_title` (string) - Human-readable topic name
- `state` (string) - User's selected state
- `language` (string) - Current language setting
- `license_type` (string) - License type
- `timestamp` (int) - Event timestamp

#### `theory_content_view_failed`
**Trigger**: When TrafficRuleContentScreen fails to render content
**Purpose**: Track content rendering failures for technical debugging
**Parameters**:
- `module_id` (string) - Module identifier (null)
- `module_title` (string) - Module title (null)
- `topic_id` (string) - Topic identifier
- `topic_title` (string) - Topic name
- `error_type` (string) - Categorized error ('network_error', 'content_load_error', 'render_error', 'database_error', 'unknown_error')
- `error_message` (string) - Truncated error details (max 100 chars)
- `state` (string) - User's selected state
- `language` (string) - Current language setting
- `timestamp` (int) - Event timestamp

#### `theory_content_completed`
**Trigger**: When user clicks "Back to Theory" button
**Purpose**: Track content completion and reading time
**Parameters**:
- `module_id` (string) - Module identifier (null)
- `module_title` (string) - Module title (null)
- `topic_id` (string) - Topic identifier
- `topic_title` (string) - Topic name
- `time_spent_reading_seconds` (int) - Total time spent reading content
- `state` (string) - User's selected state
- `language` (string) - Current language setting
- `license_type` (string) - License type
- `timestamp` (int) - Event timestamp

## Implementation Details

### TheoryScreen Analytics

**Location**: `lib/screens/theory_screen.dart`

**Tracking Points**:
1. **Module List Viewed**: Triggered after successful module load in Consumer<ContentProvider> builder
2. **Module List Empty**: Triggered when shouldShowEmptyState is true
3. **Module Selected**: Triggered in ModuleCard onSelect callback
4. **List Load Failed**: Would be triggered on ContentProvider errors (not currently implemented)

**Key Implementation Details**:
- Uses `_screenLoadTime` to track time spent browsing modules
- Implements `_hasTrackedListViewed` and `_hasTrackedEmptyState` flags to prevent duplicate events
- Gets user state from multiple sources (AuthProvider priority, then StateProvider)

### TrafficRuleContentScreen Analytics

**Location**: `lib/screens/traffic_rule_content_screen.dart`

**Tracking Points**:
1. **Content Viewed**: Triggered in initState after animations start
2. **Content View Failed**: Triggered in Builder catch block when content rendering fails
3. **Content Completed**: Triggered when user clicks either the "Back to Theory" button OR the back arrow button in AppBar

**Key Implementation Details**:
- Uses `_contentViewStartTime` to track reading time
- Implements `_hasTrackedContentViewed` and `_hasTrackedViewFailed` flags to prevent duplicate events
- Error classification through `_getErrorType()` helper method
- Module info set to null as TrafficRuleTopic model doesn't include module references

## Error Classification

The implementation includes automatic error type classification:

```dart
String _getErrorType(String errorMessage) {
  if (errorMessage.contains('network') || errorMessage.contains('connection')) {
    return 'network_error';
  } else if (errorMessage.contains('content') || errorMessage.contains('load')) {
    return 'content_load_error';
  } else if (errorMessage.contains('render') || errorMessage.contains('display')) {
    return 'render_error';
  } else if (errorMessage.contains('firestore') || errorMessage.contains('firebase')) {
    return 'database_error';
  } else {
    return 'unknown_error';
  }
}
```

## Debug Console Output

When analytics events are logged, you'll see debug output like:

```
📊 Analytics: theory_module_list_viewed logged (modules: 5, state: IL, language: en)
📊 Analytics: theory_module_selected logged (module: General Provisions, time_on_list: 12s)
📊 Analytics: theory_content_viewed logged (topic: Types of licenses)
📊 Analytics: theory_content_completed logged (topic: Types of licenses, reading_time: 180s)
📊 Analytics: theory_module_list_empty logged (reason: language, state: IL, language: es)
```

## Analytics Insights Available

### Content Discovery Patterns
- Which theory modules are most popular
- Time spent browsing module lists
- Module selection patterns by state/language

### Learning Engagement
- Content completion rates
- Average reading times per topic
- Drop-off points in the theory learning flow

### Content Performance
- Which theory topics engage users longest
- Most/least popular content by state and language
- Content rendering error rates

### Technical Monitoring
- Module loading failure rates
- Content rendering error types
- Empty state frequency by language/state combinations

## Future Enhancements

### Potential Additional Events
1. **theory_module_search** - If search functionality is added
2. **theory_content_scrolled** - Track scroll depth if needed
3. **theory_content_bookmarked** - If bookmarking is added

### Enhanced Parameters
1. **Module hierarchy data** - If TrafficRuleTopic model is enhanced to include module references
2. **Content section engagement** - Track which sections users spend most time on
3. **Reading comprehension metrics** - If quiz integration is added after theory reading

## Testing the Implementation

1. **Module List View**: Navigate to Theory tab, verify `theory_module_list_viewed` event
2. **Empty State**: Test with unsupported language/state combination
3. **Module Selection**: Tap any module, verify `theory_module_selected` with timing
4. **Content View**: Verify `theory_content_viewed` fires on content load
5. **Content Completion**: Click "Back to Theory", verify `theory_content_completed` with reading time
6. **Error Handling**: Test error scenarios to verify failure events

## Integration with Firebase Analytics

All events are automatically sent to Firebase Analytics through the `AnalyticsService.logEvent()` method, making them available in:
- Firebase Console Analytics Dashboard
- GA4 Reports
- Firebase DebugView (during development)
- Custom Analytics Reports

The implementation follows GA4 best practices with appropriate parameter naming and event structure for optimal reporting and analysis.
