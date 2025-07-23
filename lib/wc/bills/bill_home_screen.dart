import 'package:flutter/material.dart';
import 'package:fyp/wc/bills/bill_payment_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Added import for DateFormat
import 'bill_repository.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'package:fyp/wc/bills/bill.dart';
import 'package:fyp/ch/settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final BillRepository _billRepository;
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    final notificationService = NotificationService();
    notificationService.initialize();
    _billRepository = BillRepository(FirebaseService(), notificationService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        title: const Text('Bills', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white70),
            onPressed: () {
              // Add date range filter logic if needed
            },
          ),
          IconButton(
            icon: const Icon(Icons.view_agenda, color: Colors.white70),
            onPressed: () {
              // Add view toggle logic if needed
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Bill>>(
        stream: _billRepository.getBills(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final bills = snapshot.data!;
          if (bills.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome! No bills added yet.',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BillPaymentScreen(userId: userId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Add Your First Bill'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: bills.length,
            itemBuilder: (context, index) {
              final bill = bills[index];
              return ListTile(
                title: Text(
                  bill.description,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  '${bill.category} - RM${bill.amount.toStringAsFixed(2)} - Due: ${DateFormat.yMMMd().format(bill.dueDate)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: bill.isPaid
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  // Navigate to bill details if needed
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillPaymentScreen(userId: userId),
            ),
          );
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromRGBO(28, 28, 28, 1),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.details), label: 'Details'),
          BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Trending'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Insights'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Mine'),
        ],
        currentIndex: 0,
        onTap: (index) {
          if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
        },
      ),
    );
  }
}