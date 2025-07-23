import 'bill.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class BillRepository {
  final FirebaseService _firebaseService;
  final NotificationService _notificationService;

  BillRepository(this._firebaseService, this._notificationService);

  Future<void> addBill(Bill bill) async {
    await _firebaseService.addBill(bill);
    await _notificationService.scheduleBillReminder(
      bill.id,
      bill.description,
      bill.dueDate,
    );
  }

  Future<void> updateBill(Bill bill) async {
    await _firebaseService.updateBill(bill);
    if (!bill.isPaid) {
      await _notificationService.scheduleBillReminder(
        bill.id,
        bill.description,
        bill.dueDate,
      );
    }
  }

  Future<void> deleteBill(String userId, String billId) async {
    await _firebaseService.deleteBill(userId, billId);
  }

  Stream<List<Bill>> getBills(String userId) => _firebaseService.getBills(userId);

  Future<void> markBillAsPaid(String userId, String billId) async {
    await _firebaseService.markBillAsPaid(userId, billId);
  }
}