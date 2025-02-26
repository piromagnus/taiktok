import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final String collectionName = 'users';

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
    try {
      // Check if username is already taken
      final usernameQuery = await _firestore
          .collection(collectionName)
          .where('username', isEqualTo: username)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw AuthException('Username is already taken');
      }

      try {
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
        return true;
      } on auth.FirebaseAuthException catch (e) {
        print(e);
        switch (e.code) {
          case 'weak-password':
            throw AuthException('The password provided is too weak');
          case 'email-already-in-use':
            throw AuthException('An account already exists for that email');
          case 'invalid-email':
            throw AuthException('The email address is not valid');
          default:
            throw AuthException(
                'An error occurred during registration: ${e.message}');
        }
      }
    } catch (e) {
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('An unexpected error occurred');
    }
  }

  Future<AppUser?> login(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // print('userCredential: $userCredential');
      return await getUser(userCredential.user!.uid);
    } on auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          print('user not found');
          throw AuthException('No user found for that email');
        case 'wrong-password':
          print('wrong password');
          throw AuthException('Wrong password provided');
        case 'user-disabled':
          print('user disabled');
          throw AuthException('This account has been disabled');
        case 'invalid-email':
          print('invalid email');
          throw AuthException('The email address is not valid');
        default:
          print('default error : ${e.message}');
          throw AuthException('An error occurred during login: ${e.message}');
      }
    } catch (e) {
      print('unexpected error ${e.toString()}');
      throw AuthException('An unexpected error occurred during login');
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Error signing out');
    }
  }

  // get Read Papers
  Future<List<String>> getReadPapers(String userId) async {
    final userDoc =
        await _firestore.collection(collectionName).doc(userId).get();
    if (!userDoc.exists) return [];
    final userData = userDoc.data() as Map<String, dynamic>;
    return List<String>.from(userData['readPapers'] ?? []);
  }

  Future<void> markPaperAsRead(String userId, String paperId) async {
    await _firestore.collection(collectionName).doc(userId).update({
      'readPapers': FieldValue.arrayUnion([paperId])
    });
  }

  Future<void> togglePaperLike(String userId, String paperId) async {
    final user = await getUser(userId);
    if (user == null) return;

    if (user.likedPapers.contains(paperId)) {
      await _firestore.collection(collectionName).doc(userId).update({
        'likedPapers': FieldValue.arrayRemove([paperId])
      });
    } else {
      await _firestore.collection(collectionName).doc(userId).update({
        'likedPapers': FieldValue.arrayUnion([paperId])
      });
    }
  }

  Future<bool> toggleBookmark(String paperId, bool isBookmarked) async {
    try {
      final currentUser = _auth.currentUser;

      // If no user is signed in, prompt for sign up
      if (currentUser == null) {
        return false;
      }

      final userDoc =
          _firestore.collection(collectionName).doc(currentUser.uid);

      if (isBookmarked) {
        await userDoc.update({
          'bookmarkedPapers': FieldValue.arrayUnion([paperId])
        });
      } else {
        await userDoc.update({
          'bookmarkedPapers': FieldValue.arrayRemove([paperId])
        });
      }
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
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final userDoc = await _firestore
          .collection(collectionName)
          .doc(currentUser.uid)
          .get();
      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>;
      final bookmarkedPapers =
          List<String>.from(userData['bookmarkedPapers'] ?? []);
      return bookmarkedPapers.contains(paperId);
    } catch (e) {
      print('Error checking bookmark status: $e');
      return false;
    }
  }

  Future<String?> getCurrentUserId() async {
    return _auth.currentUser?.uid;
  }

  Stream<AppUser?> get currentUserStream {
    return _auth.authStateChanges().asyncMap((auth.User? firebaseUser) async {
      if (firebaseUser == null) return null;
      return await getUser(firebaseUser.uid);
    });
  }

  Future<AppUser?> initializeUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      return await getUser(currentUser.uid);
    }
    return null;
  }

  // Alias for initializeUser
  Future<AppUser?> getCurrentUser() async {
    return initializeUser();
  }

  // Alias for login
  Future<AppUser?> signIn(String email, String password) async {
    return login(email, password);
  }

  // Alias for markPaperAsRead
  Future<void> recordPaperView(String paperId) async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await markPaperAsRead(currentUser.uid, paperId);
    }
  }

  Future<AppUser?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

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
      if (user == null) return null;

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

      return appUser;
    } catch (e) {
      print('Error signing in with Google: $e');
      throw AuthException('Failed to sign in with Google');
    }
  }
}
