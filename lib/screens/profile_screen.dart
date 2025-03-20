import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/subscription_provider.dart';
import '../providers/progress_provider.dart';
import '../examples/api_switcher_example.dart';
import '../examples/function_name_mapping_example.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Counter for the hidden developer menu
  int _versionTapCount = 0;
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final subscriptionProvider = Provider.of<SubscriptionProvider>(context);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: Text('User not logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Мій профіль',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.orange,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to edit profile screen
                        },
                        child: Text(
                          'Редагувати профіль',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildMenuCard(
                'Підтримка',
                'Відповіді на ваші питання',
                Icons.help_outline,
                Colors.green[50]!,
                Colors.green,
                () {},
              ),
              SizedBox(height: 16),
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, _) {
                  // Map language codes to display names
                  final Map<String, String> languageNames = {
                    'en': 'English',
                    'es': 'Spanish',
                    'uk': 'Українська',
                    'pl': 'Polish',
                    'ru': 'Russian',
                  };
                  
                  // Get current language display name
                  final String currentLanguage = 
                      languageNames[languageProvider.language] ?? 'Українська';
                  
                  return _buildMenuCard(
                    'Обрати мову:',
                    currentLanguage,
                    Icons.language,
                    Colors.teal[50]!,
                    Colors.teal,
                    () {
                      _showLanguageSelector(context);
                    },
                  );
                },
              ),
              SizedBox(height: 16),
              Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  // Get current state
                  final String currentState = authProvider.user?.state ?? 'Not selected';
                  
                  return _buildMenuCard(
                    'Штат:',
                    currentState,
                    Icons.location_on,
                    Colors.blue[50]!,
                    Colors.blue,
                    () {
                      _showStateSelector(context);
                    },
                  );
                },
              ),
              SizedBox(height: 16),
              _buildMenuCard(
                'Підписка:',
                subscriptionProvider.isSubscriptionActive ? 'Активна' : 'Спробуйте преміум',
                Icons.workspace_premium,
                Colors.amber[50]!,
                Colors.amber,
                () {
                  Navigator.pushNamed(context, '/subscription');
                },
              ),
              SizedBox(height: 16),
              _buildMenuCard(
                'Скинути статистику',
                'Повернути все як було раніше',
                Icons.restart_alt,
                Colors.red[50]!,
                Colors.red,
                () {
                  _showResetProgressConfirmation(context);
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await authProvider.logout();
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                },
                child: Text('Вийти з акаунта'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Hidden developer menu trigger
              SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _versionTapCount++;
                    if (_versionTapCount >= 5) {
                      _versionTapCount = 0;
                      _showDeveloperOptions(context);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    String title,
    String subtitle,
    IconData icon,
    Color backgroundColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: title == 'Моя Група:' ? Colors.green : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

void _showLanguageSelector(BuildContext context) {
  final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  // Map language codes to display names - using the same languages as language_selection_screen.dart
  final Map<String, String> languageNames = {
    'en': 'English',
    'es': 'Spanish',
    'uk': 'Українська',
    'pl': 'Polish',
    'ru': 'Russian',
  };
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Select Language'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildLanguageOption(context, 'English', 'en', languageProvider, authProvider),
          _buildLanguageOption(context, 'Spanish', 'es', languageProvider, authProvider),
          _buildLanguageOption(context, 'Українська', 'uk', languageProvider, authProvider),
          _buildLanguageOption(context, 'Polish', 'pl', languageProvider, authProvider),
          _buildLanguageOption(context, 'Russian', 'ru', languageProvider, authProvider),
        ],
      ),
    ),
  );
}

Widget _buildLanguageOption(BuildContext context, String language, String code, 
    LanguageProvider provider, AuthProvider authProvider) {
  return ListTile(
    title: Text(language),
    trailing: provider.language == code ? Icon(Icons.check, color: Colors.green) : null,
    onTap: () async {
      // Update both providers, just like in the language_selection_screen
      await provider.setLanguage(code);
      await authProvider.updateUserLanguage(code);
      Navigator.pop(context);
      
      // Visual feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Language changed to $language'),
          duration: Duration(seconds: 1),
        ),
      );
    },
  );
}

void _showStateSelector(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final currentState = authProvider.user?.state;
  
  // List of all US states from state_selection_screen.dart
  final List<String> allStates = [
    'ALABAMA',
    'ALASKA',
    'ARIZONA',
    'ARKANSAS',
    'CALIFORNIA',
    'COLORADO',
    'CONNECTICUT',
    'DELAWARE',
    'DISTRICT OF COLUMBIA',
    'FLORIDA',
    'GEORGIA',
    'HAWAII',
    'IDAHO',
    'ILLINOIS',
    'INDIANA',
    'IOWA',
    'KANSAS',
    'KENTUCKY',
    'LOUISIANA',
    'MAINE',
    'MARYLAND',
    'MASSACHUSETTS',
    'MICHIGAN',
    'MINNESOTA',
    'MISSISSIPPI',
    'MISSOURI',
    'MONTANA',
    'NEBRASKA',
    'NEVADA',
    'NEW HAMPSHIRE',
    'NEW JERSEY',
    'NEW MEXICO',
    'NEW YORK',
    'NORTH CAROLINA',
    'NORTH DAKOTA',
    'OHIO',
    'OKLAHOMA',
    'OREGON',
    'PENNSYLVANIA',
    'RHODE ISLAND',
    'SOUTH CAROLINA',
    'SOUTH DAKOTA',
    'TENNESSEE',
    'TEXAS',
    'UTAH',
    'VERMONT',
    'VIRGINIA',
    'WASHINGTON',
    'WEST VIRGINIA',
    'WISCONSIN',
    'WYOMING',
  ];
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Select State'),
      content: Container(
        width: double.maxFinite,
        height: 400, // Fixed height for scrollable content
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: allStates.length,
          itemBuilder: (context, index) {
            final state = allStates[index];
            final isSelected = state == currentState;
            
            return ListTile(
              title: Text(state),
              trailing: isSelected ? Icon(Icons.check, color: Colors.green) : null,
              onTap: () async {
                // Update state in auth provider
                await authProvider.updateUserState(state);
                Navigator.pop(context);
                
                // Visual feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('State changed to $state'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            );
          },
        ),
      ),
    ),
  );
}

/**
 * Show the developer options menu
 */
void _showDeveloperOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Developer Options',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Divider(),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  leading: Icon(Icons.api),
                  title: Text('API Implementation Switcher'),
                  subtitle: Text('Switch between REST and Firebase APIs'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ApiSwitcherExample(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.functions),
                  title: Text('Function Name Mapping'),
                  subtitle: Text('View function name mappings'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FunctionNameMappingExample(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void _showResetProgressConfirmation(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Скинути статистику'),
      content: Text('Ви впевнені, що хочете скинути всю вашу статистику? Це видалить весь ваш прогрес у тестах та темах. Цю дію неможливо скасувати.'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('Скасувати'),
        ),
        TextButton(
          onPressed: () async {
            final progressProvider = Provider.of<ProgressProvider>(context, listen: false);
            await progressProvider.resetProgress();
            Navigator.pop(context);
            
            // Show confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Статистику скинуто успішно'),
                backgroundColor: Colors.green,
              ),
            );
          },
          child: Text('Скинути'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      ],
    ),
  );
}
}
