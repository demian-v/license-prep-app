import 'package:flutter/material.dart';
import '../models/quiz_topic.dart';
import '../models/subscription.dart';
import '../services/api/api_implementation.dart';
import '../services/api/firebase_auth_api.dart';
import '../services/api/firebase_content_api.dart';
import '../services/api/firebase_functions_client.dart';
import '../services/api/firebase_progress_api.dart';
import '../services/api/firebase_subscription_api.dart';
import '../services/api_service_configurator.dart';

/// Example showing how to switch between REST and Firebase APIs
class ApiSwitcherExample extends StatefulWidget {
  const ApiSwitcherExample({Key? key}) : super(key: key);

  @override
  State<ApiSwitcherExample> createState() => _ApiSwitcherExampleState();
}

class _ApiSwitcherExampleState extends State<ApiSwitcherExample> {
  late ApiImplementation _currentImplementation;
  bool _isLoading = false;
  String _result = '';
  
  // Firebase client instances
  final _firebaseFunctionsClient = FirebaseFunctionsClient();
  late final FirebaseAuthApi _firebaseAuthApi;
  late final FirebaseContentApi _firebaseContentApi;
  late final FirebaseProgressApi _firebaseProgressApi;
  late final FirebaseSubscriptionApi _firebaseSubscriptionApi;
  
  @override
  void initState() {
    super.initState();
    // Get current implementation from the configurator
    _currentImplementation = apiServiceConfigurator.currentImplementation;
    
    _firebaseAuthApi = FirebaseAuthApi(_firebaseFunctionsClient);
    _firebaseContentApi = FirebaseContentApi(_firebaseFunctionsClient);
    _firebaseProgressApi = FirebaseProgressApi(_firebaseFunctionsClient);
    _firebaseSubscriptionApi = FirebaseSubscriptionApi(_firebaseFunctionsClient);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Implementation Switcher'),
      ),
      body: Column(
        children: [
          // API Implementation switcher
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Row(
              children: [
                const Text('API Implementation:'),
                const SizedBox(width: 20),
                DropdownButton<ApiImplementation>(
                  value: _currentImplementation,
                  onChanged: (value) async {
                    if (value != null) {
                      // Switch the global API implementation
                      await apiServiceConfigurator.switchImplementation(value);
                      setState(() {
                        _currentImplementation = value;
                      });
                      
                      // Show confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('API implementation switched to ${value == ApiImplementation.firebase ? 'Firebase' : 'REST'}'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ApiImplementation.rest,
                      child: Text('REST API'),
                    ),
                    DropdownMenuItem(
                      value: ApiImplementation.firebase,
                      child: Text('Firebase API'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Action buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton(
                onPressed: _fetchUserProfile,
                child: const Text('Fetch User Profile'),
              ),
              ElevatedButton(
                onPressed: _fetchQuizTopics,
                child: const Text('Fetch Quiz Topics'),
              ),
              ElevatedButton(
                onPressed: _updateProgress,
                child: const Text('Update Progress'),
              ),
              ElevatedButton(
                onPressed: _checkSubscription,
                child: const Text('Check Subscription'),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Loading indicator
          if (_isLoading)
            const CircularProgressIndicator(),
            
          const SizedBox(height: 20),
          
          // Results display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[200],
              width: double.infinity,
              child: SingleChildScrollView(
                child: Text(
                  _result,
                  style: const TextStyle(fontFamily: 'Courier'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Fetch user profile using either API
  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      if (_currentImplementation == ApiImplementation.firebase) {
        // Use Firebase Functions API
        final user = await _firebaseAuthApi.getCurrentUser();
        setState(() {
          _result = 'Firebase API Result:\n${user?.toString() ?? "No user logged in"}';
        });
      } else {
        // Use traditional REST API from service locator
        // This is simplified for the example
        setState(() {
          _result = 'REST API would be used here';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Fetch quiz topics using either API
  Future<void> _fetchQuizTopics() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      if (_currentImplementation == ApiImplementation.firebase) {
        // Use Firebase Functions API
        final topics = await _firebaseContentApi.getQuizTopics('drivers', 'en', 'IL');
        setState(() {
          _result = 'Firebase API Result:\n${topics.length} topics found\n\n';
          for (final topic in topics) {
            _result += '- ${topic.title} (${topic.questionCount} questions)\n';
          }
        });
      } else {
        // Use traditional REST API from service locator
        setState(() {
          _result = 'REST API would be used here';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Update progress using either API
  Future<void> _updateProgress() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      if (_currentImplementation == ApiImplementation.firebase) {
        // Use Firebase Functions API
        final moduleId = 'module123';
        final result = await _firebaseProgressApi.updateModuleProgress(moduleId, 0.75);
        setState(() {
          _result = 'Firebase API Result:\nProgress updated: ${result['success']}';
        });
      } else {
        // Use traditional REST API from service locator
        setState(() {
          _result = 'REST API would be used here';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Check subscription using either API
  Future<void> _checkSubscription() async {
    setState(() {
      _isLoading = true;
      _result = '';
    });
    
    try {
      if (_currentImplementation == ApiImplementation.firebase) {
        // Use Firebase Functions API
        final isActive = await _firebaseSubscriptionApi.isSubscriptionActive();
        setState(() {
          _result = 'Firebase API Result:\nSubscription active: $isActive';
        });
      } else {
        // Use traditional REST API from service locator
        setState(() {
          _result = 'REST API would be used here';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
