import 'dart:convert';
import 'dart:io';
import 'version.dart';

class VersionCheck {
  static const _sdkName = 'dart';
  static const _twelveHours = Duration(hours: 12);
  static bool _checked = false;

  static void checkForUpdates(Map<String, String> headers) {
    if (_checked) return;
    _checked = true;

    if (_notificationsDisabled()) return;

    final latest = headers['x-muxi-sdk-latest'] ?? headers['X-Muxi-SDK-Latest'];
    if (latest == null) return;

    if (!_isNewerVersion(latest, version)) return;

    _updateLatestVersion(latest);

    if (!_notifiedRecently()) {
      stderr.writeln('[muxi] SDK update available: $latest (current: $version)');
      stderr.writeln('[muxi] Run: dart pub upgrade muxi');
      _markNotified();
    }
  }

  static bool _notificationsDisabled() => Platform.environment['MUXI_SDK_VERSION_NOTIFICATION'] == '0';

  static File? _getCacheFile() {
    final home = Platform.environment['HOME'];
    if (home == null) return null;
    return File('$home/.muxi/sdk-versions.json');
  }

  static Map<String, dynamic> _loadCache() {
    try {
      final file = _getCacheFile();
      if (file == null || !file.existsSync()) return {};
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static void _saveCache(Map<String, dynamic> cache) {
    try {
      final file = _getCacheFile();
      if (file == null) return;
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(cache));
    } catch (_) {}
  }

  static bool _isNewerVersion(String latest, String current) => latest.compareTo(current) > 0;

  static bool _notifiedRecently() {
    try {
      final cache = _loadCache();
      final entry = cache[_sdkName] as Map<String, dynamic>?;
      if (entry == null) return false;
      final lastNotified = entry['last_notified'] as String?;
      if (lastNotified == null) return false;
      final lastTime = DateTime.parse(lastNotified);
      return DateTime.now().difference(lastTime) < _twelveHours;
    } catch (_) {
      return false;
    }
  }

  static void _updateLatestVersion(String latest) {
    final cache = _loadCache();
    final entry = (cache[_sdkName] as Map<String, dynamic>?) ?? {};
    cache[_sdkName] = {
      ...entry,
      'current': version,
      'latest': latest,
    };
    _saveCache(cache);
  }

  static void _markNotified() {
    final cache = _loadCache();
    final entry = cache[_sdkName] as Map<String, dynamic>?;
    if (entry != null) {
      entry['last_notified'] = DateTime.now().toIso8601String();
      _saveCache(cache);
    }
  }
}
