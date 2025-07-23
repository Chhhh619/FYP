import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../bills/bill.dart';

class BillService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final User? _user = FirebaseAuth.instance.currentUser;

  // Add a new bill
  Future<void> addBill(Bill bill) async {
    if (_user == null) throw Exception('User not logged in');
    await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('bills')
        .doc(bill.id)
        .set(bill.toMap());
    _scheduleReminder(bill);
  }

  // Update a bill (e.g., mark as paid)
  Future<void> updateBill(Bill bill) async {
    if (_user == null) throw Exception('User not logged in');
    await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('bills')
        .doc(bill.id)
        .update(bill.toMap());
  }

  // Delete a bill
  Future<void> deleteBill(String billId) async {
    if (_user == null) throw Exception('User not logged in');
    await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('bills')
        .doc(billId)
        .delete();
  }

  // Get all bills for the user
  Stream<List<Bill>> getBills() {
    if (_user == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('bills')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Bill.fromMap(doc.id, doc.data()))
        .toList());
  }

  // Schedule FCM reminder (simplified, assuming server-side scheduling)
  Future<void> _scheduleReminder(Bill bill) async {
    // Request FCM permission
    await _messaging.requestPermission();
    // Note: Actual scheduling requires a server-side solution (e.g., Cloud Functions)
    // For simplicity, we'll log the reminder setup (replace with your server-side logic)
    print('Reminder scheduled for ${bill.description} on ${bill.dueDate}');
  }

  // Mark bill as paid
  Future<void> markBillAsPaid(String billId) async {
    if (_user == null) throw Exception('User not logged in');
    await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('bills')
        .doc(billId)
        .update({
      'isPaid': true,
      'paymentDate': Timestamp.now(),
    });
  }
}