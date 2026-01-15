import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://hztxuukoahwkkpqantyz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6dHh1dWtvYWh3a2twcWFudHl6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU0MTk1MzMsImV4cCI6MjA4MDk5NTUzM30.j8AOXcSJMr1tU_tLU2FOkxrxXwNIysVVv434NWaqXLo';

  static Future<void> initialize() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: null,
    );
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<bool> signInWithGoogle() async {
    try {
      final logFile = File(
        '/home/kushna/Desktop/class/flutter/app/.cursor/debug.log',
      );
      logFile.writeAsStringSync(
        '${logFile.existsSync() ? logFile.readAsStringSync() : ""}{"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":${DateTime.now().millisecondsSinceEpoch},"location":"supabase_service.dart:signInWithGoogle","message":"Before signInWithOAuth","data":{},"sessionId":"debug-session","runId":"run1","hypothesisId":"5"}\n',
        mode: FileMode.append,
      );
    } catch (_) {}
    try {
      final response = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.example.app://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      try {
        final logFile = File(
          '/home/kushna/Desktop/class/flutter/app/.cursor/debug.log',
        );
        logFile.writeAsStringSync(
          '${logFile.existsSync() ? logFile.readAsStringSync() : ""}{"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":${DateTime.now().millisecondsSinceEpoch},"location":"supabase_service.dart:signInWithGoogle","message":"After signInWithOAuth","data":{"response":$response},"sessionId":"debug-session","runId":"run1","hypothesisId":"5"}\n',
          mode: FileMode.append,
        );
      } catch (_) {}
      return response;
    } catch (e) {
      try {
        final logFile = File(
          '/home/kushna/Desktop/class/flutter/app/.cursor/debug.log',
        );
        logFile.writeAsStringSync(
          '${logFile.existsSync() ? logFile.readAsStringSync() : ""}{"id":"log_${DateTime.now().millisecondsSinceEpoch}","timestamp":${DateTime.now().millisecondsSinceEpoch},"location":"supabase_service.dart:signInWithGoogle","message":"Error in signInWithOAuth","data":{"error":"$e"},"sessionId":"debug-session","runId":"run1","hypothesisId":"5"}\n',
          mode: FileMode.append,
        );
      } catch (_) {}
      rethrow;
    }
  }

  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;
}
