import 'dart:async';

class NotificationHandlerService {
  static final NotificationHandlerService _instance = NotificationHandlerService._internal();
  static NotificationHandlerService get instance => _instance;
  NotificationHandlerService._internal();

  final _notificationStreamController = StreamController<String?>.broadcast();

  Stream<String?> get notificationStream => _notificationStreamController.stream;

  void handleNotification(String? payload) {
    _notificationStreamController.add(payload);
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
