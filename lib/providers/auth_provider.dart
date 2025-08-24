import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/user.dart';
import '../services/supabase_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;
  String? _lastError;
  bool _isInitialized = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  String? get lastError => _lastError;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initialize();
  }

  void _initialize() {
    // Listen for auth state changes
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session?.user != null) {
        // Only load profile if we don't already have one or if it's a different user
        if (_currentUser == null || _currentUser!.id != session!.user!.id) {
          _loadUserProfile(session!.user!.id);
        }
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _setInitialized();
        notifyListeners();
      }
    });

    // Check if user is already signed in
    final currentAuthUser = SupabaseService.currentAuthUser;
    if (currentAuthUser != null) {
      _loadUserProfile(currentAuthUser.id);
    } else {
      // No current user, mark as initialized
      _setInitialized();
    }
  }

  void _setInitialized() {
    if (!_isInitialized) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadUserProfile(String userId) async {
    try {
      final userProfile = await SupabaseService.getUserProfile(userId);
      if (userProfile != null) {
        _currentUser = userProfile;
        _isAuthenticated = true;
        _lastError = null;
      } else {
        _currentUser = null;
        _isAuthenticated = false;
        _lastError = 'User profile not found';
      }
    } catch (e) {
      _currentUser = null;
      _isAuthenticated = false;
      _lastError = 'Failed to load user profile: $e';
    }
    _setInitialized();
    notifyListeners();
  }

  // Real signup with Supabase
  Future<bool> signup(String name, String email, String password, String role) async {
    try {
      _lastError = null;
      notifyListeners();

      final result = await SupabaseService.signUpWithProfile(
        email: email,
        password: password,
        name: name,
        role: role,
      );

      if (result.authResponse.user != null && result.userProfile != null) {
        _currentUser = result.userProfile;
        _isAuthenticated = true;
        _lastError = null;
        notifyListeners();
        return true;
      } else if (result.authResponse.user != null) {
        // If auth user exists but profile creation failed, try to load it
        await _loadUserProfile(result.authResponse.user!.id);
        return _currentUser != null;
      } else {
        _lastError = 'Failed to create account';
        notifyListeners();
        return false;
      }
    } on supabase.AuthException catch (e) {
      _lastError = _getReadableAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  // Real login with Supabase
  Future<bool> login(String email, String password) async {
    try {
      _lastError = null;
      notifyListeners();

      final result = await SupabaseService.signInWithProfile(
        email: email,
        password: password,
      );

      if (result.authResponse.user != null && result.userProfile != null) {
        _currentUser = result.userProfile;
        _isAuthenticated = true;
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        _lastError = 'Failed to sign in';
        notifyListeners();
        return false;
      }
    } on supabase.AuthException catch (e) {
      _lastError = _getReadableAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await SupabaseService.signOut();
      _currentUser = null;
      _isAuthenticated = false;
      _lastError = null;
      _isInitialized = true; // Keep as initialized after logout
      notifyListeners();
    } catch (e) {
      _lastError = 'Failed to sign out: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  String _getReadableAuthError(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    } else if (error.contains('User already registered')) {
      return 'An account with this email already exists';
    } else if (error.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long';
    } else if (error.contains('Invalid email')) {
      return 'Please enter a valid email address';
    }
    return error;
  }
}