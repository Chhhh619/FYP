import 'package:cloud_firestore/cloud_firestore.dart';

class InitializeCommunityChallenges {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeChallenges() async {
    final challenges = [
      {
        'title': 'Community Income Milestone',
        'description': 'Help the community record a total of RM50,000 in income transactions across all users.',
        'type': 'collective_income',
        'targetAmount': 50000.0,
        'totalIncome': 0.0,
        'participants': [],
        'points': 20,
        'badge': {
          'name': 'Community Earner',
          'description': 'Contributed to RM50,000 community income',
          'icon': '🤝',
        },
        'createdAt': Timestamp.now(),
      },
      {
        'title': 'Category Income Competition',
        'description': 'Earn the most income in the dining category this month!',
        'type': 'income_category_competition',
        'targetAmount': 1,
        'participants': [],
        'points': 15,
        'badge': {
          'name': 'Dining Champion',
          'description': 'Top earner in dining category',
          'icon': '🍽️',
        },
        'createdAt': Timestamp.now(),
      },
      {
        'title': 'Big Income Leader',
        'description': 'Record the largest single income transaction this month!',
        'type': 'big_income_leader',
        'targetAmount': 1,
        'participants': [],
        'points': 25,
        'badge': {
          'name': 'Big Earner',
          'description': 'Largest single income transaction',
          'icon': '💰',
        },
        'createdAt': Timestamp.now(),
      },
    ];

    for (var challenge in challenges) {
      final challengeRef = _firestore.collection('community_challenges').doc();
      final challengeId = challengeRef.id;
      challenge['id'] = challengeId;
      (challenge['badge'] as Map<String, dynamic>)['id'] = 'badge_$challengeId';
      await challengeRef.set(challenge);
    }
  }
}