import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillingStartDatePage extends StatefulWidget {
  const BillingStartDatePage({super.key});

  @override
  _BillingStartDatePageState createState() => _BillingStartDatePageState();
}

class _BillingStartDatePageState extends State<BillingStartDatePage> {
  int selectedDay = 30;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentBillingStartDate();
  }

  Future<void> _loadCurrentBillingStartDate() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists && userDoc.data()!.containsKey('billStartDate')) {
          setState(() {
            selectedDay = userDoc.data()!['billStartDate'] ?? 23;
            isLoading = false;
          });
        } else {
          await _saveBillingStartDate(30);
          setState(() {
            selectedDay = 30;
            isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading billing start date: $e');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _saveBillingStartDate(int day) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'billStartDate': day});

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Billing start date updated to ${_getOrdinalNumber(day)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('Error saving billing start date: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update billing start date'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _getOrdinalNumber(int number) {
    if (number >= 11 && number <= 13) {
      return '${number}th';
    }
    switch (number % 10) {
      case 1:
        return '${number}st';
      case 2:
        return '${number}nd';
      case 3:
        return '${number}rd';
      default:
        return '${number}th';
    }
  }

  Widget _buildDayButton(int day) {
    final isSelected = day == selectedDay;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedDay = day;
        });
        _saveBillingStartDate(day);
      },
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color.fromRGBO(76, 175, 80, 1) // Green for selected
              : const Color.fromRGBO(66, 66, 66, 1), // Dark gray for unselected
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color.fromRGBO(76, 175, 80, 1), width: 2)
              : null,
        ),
        child: Center(
          child: Text(
            day.toString(),
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, selectedDay),
        ),
        title: const Text(
          'Monthly starting on',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        centerTitle: false,
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color.fromRGBO(76, 175, 80, 1),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date info row
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(50, 50, 50, 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Color.fromRGBO(76, 175, 80, 1),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Date',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Monthly ${_getOrdinalNumber(selectedDay)}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Day selection grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: 31,
              itemBuilder: (context, index) {
                return _buildDayButton(index + 1);
              },
            ),

            const SizedBox(height: 24),

            // Help text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(50, 50, 50, 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Billing Start Date',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This sets when your monthly budget period begins. Your budget and spending tracking will reset on this day each month.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}