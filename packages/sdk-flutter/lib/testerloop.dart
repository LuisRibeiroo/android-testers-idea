import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Enrollment tracking state reported by the native Android SDK.
enum TesterLoopStatus {
  notEnrolled,
  tracking,
  disabled;

  static TesterLoopStatus fromWire(String? value) {
    switch (value) {
      case 'TRACKING':
        return TesterLoopStatus.tracking;
      case 'NOT_ENROLLED':
        return TesterLoopStatus.notEnrolled;
      case 'DISABLED':
      default:
        return TesterLoopStatus.disabled;
    }
  }
}

/// Optional Flutter facade for [TesterLoop].
///
/// Integration requires zero Dart code; auto-init runs on Android via manifest
/// metadata (`io.testerloop.APP_KEY`). Non-Android platforms are safe no-ops.
abstract final class TesterLoop {
  static const MethodChannel _channel = MethodChannel('io.testerloop/sdk');

  static bool get _isSupportedAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Returns current SDK tracking status. Always returns [TesterLoopStatus.disabled]
  /// on non-Android targets.
  static Future<TesterLoopStatus> status() async {
    if (!_isSupportedAndroid) return TesterLoopStatus.disabled;
    try {
      final raw = await _channel.invokeMethod<String>('status');
      return TesterLoopStatus.fromWire(raw);
    } on MissingPluginException {
      return TesterLoopStatus.disabled;
    }
  }

  /// Allows host apps to expose an opt-out toggle. No-op on non-Android targets.
  static Future<void> setEnabled(bool enabled) async {
    if (!_isSupportedAndroid) return;
    try {
      await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
    } on MissingPluginException {
      // Safe no-op when running without Android embedding
    }
  }
}
