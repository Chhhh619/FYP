import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> scheduleBillNotification({
    required String billId,
    required String billerName,
    required double amount,
    required String categoryName,
    required DateTime dueDate,
  }) async {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime.from(
      dueDate.subtract(const Duration(days: 1)),
      tz.local,
    );

    // Ensure scheduledDate is in the future
    if (scheduledDate.isBefore(now)) {
      scheduledDate = tz.TZDateTime(tz.local, dueDate.year, dueDate.month, dueDate.day)
          .subtract(const Duration(days: 1))
          .add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'bill_channel',
      'Bill Reminders',
      channelDescription: 'Notifications for bill due dates',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    try {
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        billId.hashCode,
        'Bill Due Soon',
        '$billerName ($categoryName) bill of RM${amount.toStringAsFixed(2)} is due on ${DateFormat('MMM dd, yyyy').format(dueDate)}.',
        scheduledDate,
        platformChannelSpecifics,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      developer.log('Exact alarm scheduled for billId: $billId');
    } catch (e) {
      developer.log('Exact alarm failed: $e');
      if (e.toString().contains('Exact_Alarms_not_permitted')) {
        // Fall back to inexact alarm
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          billId.hashCode,
          'Bill Due Soon',
          '$billerName ($categoryName) bill of RM${amount.toStringAsFixed(2)} is due on ${DateFormat('MMM dd, yyyy').format(dueDate)}.',
          scheduledDate,
          platformChannelSpecifics,
          androidAllowWhileIdle: false,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        developer.log('Inexact alarm scheduled for billId: $billId');
      } else {
        rethrow; // Re-throw other exceptions
      }
    }
  }

  Future<void> showBillPaidNotification({
    required String billerName,
    required double amount,
    required String categoryName,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'bill_paid_channel',
      'Bill Paid Notifications',
      channelDescription: 'Notifications for bill payments',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _flutterLocalNotificationsPlugin.show(
      0,
      'Bill Paid',
      '$billerName ($categoryName) bill of RM${amount.toStringAsFixed(2)} has been marked as paid.',
      platformChannelSpecifics,
    );
  }

  Future<void> cancelNotification(String billId) async {
    await _flutterLocalNotificationsPlugin.cancel(billId.hashCode);
  }
}