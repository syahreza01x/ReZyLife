import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'notification_parser.dart';

/// Thin bridge to Android's native [ReZyNotificationListener] via MethodChannel.
/// Safely no-ops on non-Android platforms and inside unit/widget tests.
class NotificationBridge {
  NotificationBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('rezylife/notifications');

  final MethodChannel _channel;

  bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  void setLiveListener(
    ValueChanged<RawFinanceNotification> onNotification, {
    VoidCallback? onQuickAdd,
  }) {
    if (!isSupportedPlatform) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotification' && call.arguments is Map) {
        onNotification(
          RawFinanceNotification.fromMap(call.arguments as Map<Object?, Object?>),
        );
      } else if (call.method == 'onQuickAddRequested') {
        onQuickAdd?.call();
      }
    });
  }

  Future<bool> consumePendingQuickAdd() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('consumePendingQuickAdd') ??
          false;
    } catch (_) {
      return false;
    }
  }

  void clearLiveListener() {
    if (!isSupportedPlatform) return;
    _channel.setMethodCallHandler(null);
  }

  Future<bool> isAccessEnabled() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('isNotificationAccessEnabled') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openNotificationAccessSettings() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _channel
              .invokeMethod<bool>('openNotificationAccessSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openAppDetailsSettings() async {
    if (!isSupportedPlatform) return false;
    try {
      return await _channel.invokeMethod<bool>('openAppDetailsSettings') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<List<RawFinanceNotification>> drainPendingNotifications() async {
    if (!isSupportedPlatform) return const [];
    try {
      final rawList = await _channel
          .invokeMethod<List<Object?>>('drainPendingNotifications');
      if (rawList == null || rawList.isEmpty) return const [];
      return rawList
          .whereType<Map<Object?, Object?>>()
          .map(RawFinanceNotification.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
