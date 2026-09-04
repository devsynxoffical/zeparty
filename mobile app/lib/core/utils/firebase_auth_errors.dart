import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Please choose a stronger password.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Please check your internet connection.';
        case 'operation-not-allowed':
          return 'This sign in method is currently unavailable.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with the same email address using another sign in method.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }

    final errorString = error.toString().toLowerCase();
    if (errorString.contains('10:') || errorString.contains('developer_error')) {
      return 'Google Sign-In configuration error. Please ensure SHA-1 fingerprint & Google Sign-In are enabled in Firebase Console.';
    }
    if (errorString.contains('12500') || errorString.contains('sign_in_failed')) {
      return 'Google Sign-In failed. Please check Google Play Services or network connection.';
    }
    if (errorString.contains('cancelled') || errorString.contains('canceled') || errorString.contains('sign_in_canceled')) {
      return 'Sign in was cancelled.';
    }

    return 'Authentication failed: ${error is Exception ? error.toString().replaceAll('PlatformException', '').trim() : 'Please try again.'}';
  }
}
