import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AchievementsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Define categories and their corresponding badges
  final Map<String, Map<String, String>> _categoryBadges = {
    'dining': {
      'id': 'dining_expenser',
      'name': 'The Dining Expenser',
      'description': 'Mastered all dining-related financial tips!',
      'icon': '🍽️',
    },
    'budgeting': {
      'id': 'budgeting_guru',
      'name': 'The Budgeting Guru',
      'description': 'Mastered all budgeting-related financial tips!',
      'icon': '📊',
    },
    'savings': {
      'id': 'savings_star',
      'name': 'The Savings Star',
      'description': 'Mastered all savings-related financial tips!',
      'icon': '💰',
    },
    'debt': {
      'id': 'debt_destroyer',
      'name': 'The Debt Destroyer',
      'description': 'Mastered all debt-related financial tips!',
      'icon': '🪓',
    },
    'shopping': {
      'id': 'shopping_savvy',
      'name': 'The Shopping Savvy',
      'description': 'Mastered all shopping-related financial tips!',
      'icon': '🛒',
    },
    'transport': {
      'id': 'transport_trailblazer',
      'name': 'The Transport Trailblazer',
      'description': 'Mastered all transport-related financial tips!',
      'icon': '🚍',
    },
    'subscription': {
      'id': 'subscription_specialist',
      'name': 'The Subscription Specialist',
      'description': 'Mastered all subscription-related financial tips!',
      'icon': '📺',
    },
  };

  Future<void> checkAndAwardCategoryBadges(String userId) async {
    try {
      // Fetch all tips
      final tipsSnapshot = await _firestore.collection('tips').get();
      final totalTips = tipsSnapshot.docs.length;
      print('Total tips: $totalTips');

      // Fetch user's tip feedback
      final feedbackSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tips_feedback')
          .get();
      final engagedTips = feedbackSnapshot.docs.length;
      print('Engaged tips: $engagedTips');

      // Group tips by category
      final Map<String, List<String>> categoryTips = {};
      for (var doc in tipsSnapshot.docs) {
        final category = doc.data()['category']?.toLowerCase() ?? 'unknown';
        categoryTips.putIfAbsent(category, () => []).add(doc.id);
      }
      print('Category tips: $categoryTips');

      // Check engagement for each category
      for (var category in _categoryBadges.keys) {
        final categoryTipIds = categoryTips[category] ?? [];
        final categoryFeedback = feedbackSnapshot.docs
            .where((doc) => categoryTipIds.contains(doc.data()['tipId']))
            .toList();
        print(
            'Category: $category, Total tips: ${categoryTipIds.length}, Engaged: ${categoryFeedback.length}');

        // Award badge if all tips in the category are engaged
        if (categoryFeedback.length >= categoryTipIds.length &&
            categoryTipIds.isNotEmpty) {
          final badgeDoc = await _firestore
              .collection('users')
              .doc(userId)
              .collection('badges')
              .doc(_categoryBadges[category]!['id'])
              .get();
          if (!badgeDoc.exists) {
            await _firestore
                .collection('users')
                .doc(userId)
                .collection('badges')
                .doc(_categoryBadges[category]!['id'])
                .set({
              'id': _categoryBadges[category]!['id'],
              'name': _categoryBadges[category]!['name'],
              'description': _categoryBadges[category]!['description'],
              'icon': _categoryBadges[category]!['icon'],
              'awardedAt': Timestamp.now(),
            });
            print('Awarded badge: ${_categoryBadges[category]!['name']}');
          }
        }
      }

      // Check for Ultimate Tips Collector badge
      if (engagedTips >= totalTips && totalTips > 0) {
        final badgeDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('badges')
            .doc('ultimate_tips_collector')
            .get();
        if (!badgeDoc.exists) {
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('badges')
              .doc('ultimate_tips_collector')
              .set({
            'id': 'ultimate_tips_collector',
            'name': 'The Ultimate Tips Collector',
            'description': 'Engaged with all available financial tips!',
            'icon': '🏆',
            'awardedAt': Timestamp.now(),
          });
          print('Awarded The Ultimate Tips Collector badge');
        }
      }
    } catch (e) {
      print('Error checking/awarding badges: $e');
      throw Exception('Failed to award badges: $e');
    }
  }
}