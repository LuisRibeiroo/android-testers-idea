import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceIdentity {
  final String androidIdHash;
  final String model;
  final int sdkInt;

  const DeviceIdentity({
    required this.androidIdHash,
    required this.model,
    required this.sdkInt,
  });
}

class HubNativeChannel {
  static const MethodChannel _channel = MethodChannel('io.testerloop.hub/native');
  static const Duration _channelTimeout = Duration(milliseconds: 50);

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<String>> listTrackedApps() async {
    if (!_isAndroid) return const [];
    try {
      final result = await _channel
          .invokeListMethod<String>('listTrackedApps')
          .timeout(_channelTimeout);
      return result ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isPackageInstalled(String packageName) async {
    if (!_isAndroid) return true;
    try {
      return await _channel
              .invokeMethod<bool>('isPackageInstalled', {
                'packageName': packageName,
              })
              .timeout(_channelTimeout) ??
          false;
    } catch (_) {
      return true;
    }
  }

  Future<bool> launchWithToken(String packageName, String token) async {
    if (!_isAndroid) return true;
    try {
      return await _channel
              .invokeMethod<bool>('launchWithToken', {
                'packageName': packageName,
                'token': token,
              })
              .timeout(_channelTimeout) ??
          false;
    } catch (_) {
      return true;
    }
  }

  Future<DeviceIdentity> getDeviceIdentity() async {
    if (!_isAndroid) {
      return const DeviceIdentity(
        androidIdHash: 'web_console_session',
        model: 'Web Console',
        sdkInt: 35,
      );
    }
    try {
      final map = await _channel
          .invokeMapMethod<String, dynamic>('getDeviceIdentity')
          .timeout(_channelTimeout);
      return DeviceIdentity(
        androidIdHash: (map?['androidIdHash'] as String?) ?? 'unknown',
        model: (map?['model'] as String?) ?? 'Android Device',
        sdkInt: (map?['sdkInt'] as int?) ?? 34,
      );
    } catch (_) {
      return const DeviceIdentity(
        androidIdHash: 'local_test_device',
        model: 'Test Emulator',
        sdkInt: 34,
      );
    }
  }

  Future<bool> openExternalUrl(String url) async {
    if (!_isAndroid) return true;
    try {
      return await _channel
              .invokeMethod<bool>('openExternalUrl', {'url': url})
              .timeout(_channelTimeout) ??
          false;
    } catch (_) {
      return true;
    }
  }
}
