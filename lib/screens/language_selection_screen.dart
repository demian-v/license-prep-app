import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../localization/app_localizations.dart';
import 'state_selection_screen.dart';

class LanguageSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Language Selection', // This remains hardcoded in English as specified
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Select your language'), // This remains hardcoded in English as specified
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, _) => Column(
                  children: [
                    _buildLanguageButton(context, 'English', 'en'),
                    _buildLanguageButton(context, 'Spanish', 'es'),
                    _buildLanguageButton(context, 'Ukrainian', 'uk'),
                    _buildLanguageButton(context, 'Polish', 'pl'),
                    _buildLanguageButton(context, 'Russian', 'ru'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Divider(color: Colors.grey[300]),
          ),
        ],
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
    
    // Color scheme based on language (keeping these for the icon backgrounds)
    final Map<String, Color> languageColors = {
      'en': Color(0xFF3F51B5), // Indigo for English
      'es': Color(0xFFE91E63), // Pink for Spanish
      'uk': Color(0xFF2196F3), // Blue for Ukrainian
      'pl': Color(0xFF4CAF50), // Green for Polish
      'ru': Color(0xFFF44336), // Red for Russian
    };
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          // Visual feedback
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Setting UI language to $language...\nContent will remain in Ukrainian (IL)'), // This is feedback in English as specified
              duration: Duration(seconds: 2),
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
            
            // Wait for a short time to ensure the language is loaded properly
            await Future.delayed(Duration(milliseconds: 300));
            
            // Force a rebuild of MaterialApp with the new locale
            if (context.mounted) {
              // Use pushAndRemoveUntil to rebuild the navigation stack with the new locale
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (_) => StateSelectionScreen(),
                ),
                (route) => route.isFirst, // Keep only the first route
              );
            }
          } catch (e) {
            print('Error updating language: $e');
            // Show error snackbar
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error selecting language: $e'), // Error message in English as specified
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: languageColors[code]!.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Icon(
                  languageIcons[code],
                  color: languageColors[code],
                  size: 28,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  language,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
