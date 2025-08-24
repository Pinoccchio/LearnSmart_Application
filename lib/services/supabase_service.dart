import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/user.dart' as app_user;

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  // Auth methods
  static User? get currentAuthUser => client.auth.currentUser;
  
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Profile methods
  static Future<app_user.User> createUserProfile({
    required String authUserId,
    required String name,
    required String email,
    String role = 'student',
    String? profilePicture,
  }) async {
    final response = await client
        .from('users')
        .insert({
          'id': authUserId,
          'name': name,
          'email': email,
          'role': role,
          'profile_picture': profilePicture,
        })
        .select()
        .single();

    return app_user.User.fromSupabase(response);
  }

  static Future<app_user.User?> getUserProfile(String userId) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .single();

      return app_user.User.fromSupabase(response);
    } catch (e) {
      return null;
    }
  }

  static Future<app_user.User> updateUserProfile({
    required String userId,
    String? name,
    String? role,
    String? profilePicture,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (role != null) updates['role'] = role;
    if (profilePicture != null) updates['profile_picture'] = profilePicture;
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await client
        .from('users')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return app_user.User.fromSupabase(response);
  }

  // Combined auth and profile creation for signup
  static Future<({AuthResponse authResponse, app_user.User? userProfile})> signUpWithProfile({
    required String email,
    required String password,
    required String name,
    String role = 'student',
  }) async {
    try {
      // Step 1: Create auth user
      final authResponse = await signUp(
        email: email,
        password: password,
      );

      // Step 2: Create user profile if auth was successful
      app_user.User? userProfile;
      if (authResponse.user != null) {
        try {
          userProfile = await createUserProfile(
            authUserId: authResponse.user!.id,
            name: name,
            email: email,
            role: role,
          );
        } catch (profileError) {
          // If profile creation fails, we should clean up the auth user
          // but for now, we'll just return the auth response
        }
      }

      return (authResponse: authResponse, userProfile: userProfile);
    } catch (e) {
      rethrow;
    }
  }

  // Combined auth and profile retrieval for signin
  static Future<({AuthResponse authResponse, app_user.User? userProfile})> signInWithProfile({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Sign in
      final authResponse = await signIn(
        email: email,
        password: password,
      );

      // Step 2: Get user profile
      app_user.User? userProfile;
      if (authResponse.user != null) {
        userProfile = await getUserProfile(authResponse.user!.id);
      }

      return (authResponse: authResponse, userProfile: userProfile);
    } catch (e) {
      rethrow;
    }
  }
}