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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isInitializing = true;
  
  final List<Widget> _screens = [
    TestScreen(),
    TheoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    
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
    });
  }

  @override
  Widget build(BuildContext context) {
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
