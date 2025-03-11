import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  User? user;

  AuthProvider(this.user);

  Future<bool> login(String email, String password) async {
    // In a real app, this would be an API call
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        final mockUser = User(
          id: '123',
          name: email.split('@')[0],
          email: email,
        );
        
        user = mockUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(mockUser.toJson()));
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    // In a real app, this would be an API call
    try {
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        final mockUser = User(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          email: email,
        );
        
        user = mockUser;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(mockUser.toJson()));
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('Signup error: $e');
      return false;
    }
  }
  
  Future<void> updateUserLanguage(String language) async {
    if (user != null) {
      final updatedUser = user!.copyWith(language: language);
      user = updatedUser;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(updatedUser.toJson()));
      
      notifyListeners();
    }
  }
  
  Future<void> updateUserState(String state) async {
    if (user != null) {
      final updatedUser = user!.copyWith(state: state);
      user = updatedUser;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(updatedUser.toJson()));
      
      notifyListeners();
    }
  }

  Future<void> updateProfile(String name) async {
    if (user != null) {
      final updatedUser = user!.copyWith(name: name);
      user = updatedUser;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user', jsonEncode(updatedUser.toJson()));
      
      notifyListeners();
    }
  }

  Future<void> logout() async {
    user = null;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    
    notifyListeners();
  }
}
