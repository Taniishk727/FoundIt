import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AppRole {
  static final ValueNotifier<String?> role = ValueNotifier<String?>(null);

  static bool get isAdmin => role.value == 'admin';

  static Future<void> loadForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      role.value = null;
      return;
    }
    await loadForUid(user.uid);
  }

  static Future<void> loadForUid(String uid) async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data();
    final loadedRole = (data?['role'] ?? 'user').toString();
    role.value = loadedRole;
  }

  static Future<void> ensureUserDoc({
    required String uid,
    required String email,
    String roleValue = 'user',
  }) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': roleValue,
      'email': email,
    }, SetOptions(merge: true));
  }
}

