import 'package:flutter/material.dart';
import '../screens/test_screen.dart';
import '../screens/theory_screen.dart';
import '../screens/profile_screen.dart';
import '../widgets/super_enhanced_footer.dart';
import '../services/service_locator_extensions.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  // Static variable to persist tab selection across widget rebuilds
  static int _persistentCurrentIndex = 0;
  
  late int _currentIndex;
  bool _isInitializing = true;
  
  // Keep the widget alive to preserve state during parent rebuilds
  @override
  bool get wantKeepAlive => true;
  
  final List<Widget> _screens = [
    TestScreen(),
    TheoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
    // Restore the persistent tab index to maintain tab selection across rebuilds
    _currentIndex = _persistentCurrentIndex;
    
    print('🏠 HomeScreen: Initializing with saved tab index: $_currentIndex');
    
    // Initialize content after the screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeContent();
    });
  }
  
  // Initialize content using ContentLoadingManager
  Future<void> _initializeContent() async {
    setState(() {
      _isInitializing = true;
    });
    
    try {
      // Get the content loading manager and initialize content
      final contentLoadingManager = ServiceLocatorExtensions.contentLoadingManager;
      await contentLoadingManager.initializeContent();
    } catch (e) {
      print('Error initializing content: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      // Persist the tab selection to survive widget rebuilds (like during language changes)
      _persistentCurrentIndex = index;
    });
    
    print('🏠 HomeScreen: Tab changed to index $index, persisted for future rebuilds');
  }

  @override
  Widget build(BuildContext context) {
    // Call super.build to maintain AutomaticKeepAliveClientMixin functionality
    super.build(context);
    
    // Show loading indicator while initializing content
    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading content...'),
            ],
          ),
        ),
      );
    }
    
    // Show the regular home screen once content is loaded
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: SuperEnhancedFooter(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}
