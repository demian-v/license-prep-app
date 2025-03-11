import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import 'state_selection_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Language Selection'),
        elevation: 0,
        backgroundColor: Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Language selection area
            Expanded(
              flex: 4,
              child: Container(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 16),
                    Text(
                      'Select your language',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 40),
                    _buildLanguageButton(
                      context, 
                      'English', 
                      'en',
                    ),
                    SizedBox(height: 16),
                    _buildLanguageButton(
                      context, 
                      'Spanish', 
                      'es',
                    ),
                    SizedBox(height: 16),
                    _buildLanguageButton(
                      context, 
                      'Ukrainian', 
                      'uk',
                    ),
                    SizedBox(height: 16),
                    _buildLanguageButton(
                      context, 
                      'Polish', 
                      'pl',
                    ),
                    SizedBox(height: 16),
                    _buildLanguageButton(
                      context, 
                      'Russian', 
                      'ru',
                    ),
                  ],
                ),
              ),
            ),
            // Progress indicator
            Container(
              padding: EdgeInsets.only(bottom: 24),
              child: Center(
                child: Container(
                  width: 100,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context, String language, String code) {
    // Beautiful language icons/flags mapping with distinctive icons for each language
    final Map<String, IconData> languageIcons = {
      'en': Icons.flag_circle,
      'es': Icons.language,
      'uk': Icons.emoji_flags,
      'pl': Icons.flag,
      'ru': Icons.flag_outlined,
    };
    
    // Color scheme based on language
    final Map<String, Color> languageColors = {
      'en': Color(0xFF3F51B5), // Indigo for English
      'es': Color(0xFFE91E63), // Pink for Spanish
      'uk': Color(0xFF2196F3), // Blue for Ukrainian
      'pl': Color(0xFF4CAF50), // Green for Polish
      'ru': Color(0xFFF44336), // Red for Russian
    };
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: languageColors[code]!.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(32.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            languageColors[code]!,
            languageColors[code]!.withOpacity(0.8),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32.0),
          onTap: () async {
            // Visual feedback
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Setting language to $language...'),
                duration: Duration(seconds: 1),
                backgroundColor: languageColors[code],
              ),
            );
            
            // Update the language in both providers - using a try-catch to handle any errors
            try {
              // Update language provider
              final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
              await languageProvider.setLanguage(code);
              
              // Update auth provider
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.updateUserLanguage(code);
              
              // Use push instead of pushReplacement to maintain navigation history
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => StateSelectionScreen(),
                ),
              );
            } catch (e) {
              print('Error updating language: $e');
              // Show error snackbar
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error selecting language: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Icon(
                        languageIcons[code], 
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      language,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
