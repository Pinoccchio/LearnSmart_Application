import 'package:flutter/material.dart';
import '../models/user.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;

  // Mock login
  Future<bool> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call
    
    _currentUser = User(
      id: '1',
      name: 'UserName',
      email: email,
      role: 'student',
    );
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  // Mock signup
  Future<bool> signup(String name, String email, String password, String role) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call
    
    _currentUser = User(
      id: '1',
      name: name,
      email: email,
      role: role,
    );
    _isAuthenticated = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}