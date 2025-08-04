import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Import this in your other files where you need ban checking:
// import 'ban_check_utility.dart';

class BanCheckUtility {
  /// Check if the current user is banned and handle accordingly
  static Future<bool> checkUserBanStatus(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['banned'] == true) {
          // User is banned, sign them out and redirect to login
          await FirebaseAuth.instance.signOut();

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your account has been suspended. Please contact support.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 5),
              ),
            );

            // Navigate to login screen
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
                  (route) => false,
            );
          }
          return true; // User is banned
        }
      }
    } catch (e) {
      print('Error checking ban status: $e');
    }

    return false; // User is not banned
  }

  /// Get a stream to listen for ban status changes in real-time
  static Stream<bool> getBanStatusStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(false);
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        final userData = doc.data() as Map<String, dynamic>;
        return userData['banned'] == true;
      }
      return false;
    });
  }

  /// Check ban status without UI interactions (for background checks)
  static Future<bool> checkUserBanStatusSilent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['banned'] == true;
      }
    } catch (e) {
      print('Error checking ban status: $e');
    }

    return false;
  }
}