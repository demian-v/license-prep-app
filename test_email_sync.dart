import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple script to test the email sync and state preservation functionality
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Test saving state to shared preferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('last_user_state', 'ALASKA');
  await prefs.setString('last_user_language', 'uk');
  
  print('✅ Test: State and language saved to preferences successfully');
  
  // Verify data was saved
  final savedState = prefs.getString('last_user_state');
  final savedLanguage = prefs.getString('last_user_language');
  
  print('📊 Test: Retrieved state from preferences: $savedState');
  print('📊 Test: Retrieved language from preferences: $savedLanguage');
  
  // Clean up test data
  await prefs.remove('last_user_state');
  await prefs.remove('last_user_language');
  
  print('✅ Test: Preferences cleaned up successfully');
  
  // Simulate email verification process
  try {
    // Test Firestore operations with state preservation
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      // Create test document with email and state
      await FirebaseFirestore.instance.collection('test_users').doc(userId).set({
        'email': 'old_email@example.com',
        'state': 'ALASKA',
        'language': 'uk',
        'name': 'Test User',
      });
      
      print('✅ Test: Created test document with state and email');
      
      // Now update only the email field
      await FirebaseFirestore.instance.collection('test_users').doc(userId).update({
        'email': 'new_email@example.com',
      });
      
      print('✅ Test: Updated email field only');
      
      // Verify state was preserved
      final doc = await FirebaseFirestore.instance.collection('test_users').doc(userId).get();
      final data = doc.data();
      
      print('📊 Test: Document after update: $data');
      print('📊 Test: State field value: ${data?['state']}');
      print('📊 Test: Language field value: ${data?['language']}');
      
      if (data?['state'] == 'ALASKA' && data?['language'] == 'uk') {
        print('✅ TEST PASSED: State and language were preserved when updating only email!');
      } else {
        print('❌ TEST FAILED: State or language were lost during email update!');
      }
      
      // Clean up test document
      await FirebaseFirestore.instance.collection('test_users').doc(userId).delete();
      print('✅ Test: Cleaned up test document');
    } else {
      print('⚠️ Test: No authenticated user found for testing');
    }
  } catch (e) {
    print('❌ Test error: $e');
  }
  
  print('📋 All tests completed');
}
