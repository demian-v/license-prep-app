import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/content_provider.dart';
import 'traffic_rules_topics_screen.dart';

class TheoryScreen extends StatefulWidget {
  @override
  _TheoryScreenState createState() => _TheoryScreenState();
}

class _TheoryScreenState extends State<TheoryScreen> {
  @override
  void initState() {
    super.initState();
    // We'll navigate to the traffic rules topics screen right away
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => TrafficRulesTopicsScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // This is just a placeholder that will never be shown
    // since we navigate away in initState
    return Scaffold(
      appBar: AppBar(
        title: Text('Теорія'),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
