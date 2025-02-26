import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class UserProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final String collectionName = 'users';

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _error;

  // Getters
  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _currentUser != null;

  // Initialize user on app startup
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        _currentUser = await getUser(currentUser.uid);
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
      print('Error initializing user: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveUser(AppUser user) async {
    await _firestore
        .collection(collectionName)
        .doc(user.id)
        .set(user.toFirestore());
  }

  Future<AppUser?> getUser(String id) async {
    final doc = await _firestore.collection(collectionName).doc(id).get();
    if (!doc.exists) return null;
    return AppUser.fromFirestore(doc.data()!, doc.id);
  }

  Future<bool> createAccount(
      String email, String password, String username) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if username is already taken
      final usernameQuery = await _firestore
          .collection(collectionName)
          .where('username', isEqualTo: username)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw AuthException('Username is already taken');
      }

      // Create Firebase Auth account
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user profile in Firestore
      final newUser = AppUser(
        id: userCredential.user!.uid,
        email: email,
        username: username,
      );
      await saveUser(newUser);

      // Update current user
      _currentUser = newUser;
      return true;
    } on auth.FirebaseAuthException catch (e) {
      print(e);
      switch (e.code) {
        case 'weak-password':
          _error = 'The password provided is too weak';
          break;
        case 'email-already-in-use':
          _error = 'An account already exists for that email';
          break;
        case 'invalid-email':
          _error = 'The email address is not valid';
          break;
        default:
          _error = 'An error occurred during registration: ${e.message}';
      }
      return false;
    } catch (e) {
      if (e is AuthException) {
        _error = e.message;
      } else {
        _error = 'An unexpected error occurred';
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _currentUser = await getUser(userCredential.user!.uid);
      return _currentUser != null;
    } on auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          _error = 'No user found for that email';
          break;
        case 'wrong-password':
          _error = 'Wrong password provided';
          break;
        case 'user-disabled':
          _error = 'This account has been disabled';
          break;
        case 'invalid-email':
          _error = 'The email address is not valid';
          break;
        default:
          _error = 'An error occurred during login: ${e.message}';
      }
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred during login';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      _error = 'Error signing out';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // get Read Papers
  Future<List<String>> getReadPapers() async {
    if (_currentUser == null) return [];
    return _currentUser!.readPapers;
  }

  Future<void> markPaperAsRead(String paperId) async {
    if (_currentUser == null) return;

    await _firestore.collection(collectionName).doc(_currentUser!.id).update({
      'readPapers': FieldValue.arrayUnion([paperId])
    });

    // Update local user object
    _currentUser!.readPapers.add(paperId);
    notifyListeners();
  }

  Future<void> togglePaperLike(String paperId) async {
    if (_currentUser == null) return;

    if (_currentUser!.likedPapers.contains(paperId)) {
      await _firestore.collection(collectionName).doc(_currentUser!.id).update({
        'likedPapers': FieldValue.arrayRemove([paperId])
      });
      _currentUser!.likedPapers.remove(paperId);
    } else {
      await _firestore.collection(collectionName).doc(_currentUser!.id).update({
        'likedPapers': FieldValue.arrayUnion([paperId])
      });
      _currentUser!.likedPapers.add(paperId);
    }
    notifyListeners();
  }

  Future<bool> toggleBookmark(String paperId) async {
    if (_currentUser == null) return false;

    try {
      bool isCurrentlyBookmarked =
          _currentUser!.bookmarkedPapers.contains(paperId);

      if (!isCurrentlyBookmarked) {
        await _firestore
            .collection(collectionName)
            .doc(_currentUser!.id)
            .update({
          'bookmarkedPapers': FieldValue.arrayUnion([paperId])
        });
        _currentUser!.bookmarkedPapers.add(paperId);
      } else {
        await _firestore
            .collection(collectionName)
            .doc(_currentUser!.id)
            .update({
          'bookmarkedPapers': FieldValue.arrayRemove([paperId])
        });
        _currentUser!.bookmarkedPapers.remove(paperId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      print('Error toggling bookmark: $e');
      return false;
    }
  }

  Future<bool> isAnonymous() async {
    return _auth.currentUser?.isAnonymous ?? true;
  }

  Future<bool> isPaperBookmarked(String paperId) async {
    if (_currentUser == null) return false;
    return _currentUser!.bookmarkedPapers.contains(paperId);
  }

  Future<String?> getCurrentUserId() async {
    return _currentUser?.id;
  }

  // For the Google Sign in functionality
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if user exists in Firestore
      AppUser? appUser = await getUser(user.uid);

      // If user doesn't exist, create a new profile
      if (appUser == null) {
        appUser = AppUser(
          id: user.uid,
          email: user.email!,
          username: user.displayName ?? user.email!.split('@')[0],
        );
        await saveUser(appUser);
      }

      _currentUser = appUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('Error signing in with Google: $e');
      _error = 'Failed to sign in with Google';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
