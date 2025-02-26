import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  String? username;
  String? email;
  List<String> readPapers;
  List<String> likedPapers;
  List<String> bookmarkedPapers;
  Timestamp createdAt;

  AppUser({
    String? id,
    this.username,
    this.email,
    List<String>? readPapers,
    List<String>? likedPapers,
    List<String>? bookmarkedPapers,
    Timestamp? createdAt,
  })  : id = id ?? const Uuid().v4(),
        readPapers = readPapers ?? [],
        likedPapers = likedPapers ?? [],
        bookmarkedPapers = bookmarkedPapers ?? [],
        createdAt = createdAt ?? Timestamp.now();

  factory AppUser.fromFirestore(Map<String, dynamic> data, String id) {
    return AppUser(
      id: id,
      username: data['username'],
      email: data['email'],
      readPapers: List<String>.from(data['readPapers'] ?? []),
      likedPapers: List<String>.from(data['likedPapers'] ?? []),
      bookmarkedPapers: List<String>.from(data['bookmarkedPapers'] ?? []),
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'email': email,
      'readPapers': readPapers,
      'likedPapers': likedPapers,
      'bookmarkedPapers': bookmarkedPapers,
      'createdAt': createdAt,
    };
  }
}
