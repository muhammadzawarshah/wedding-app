import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central configuration for talking to the live wedding platform backend.
///
/// Production builds use the hosted API by default:
/// https://abhiaijawedding.co.uk/backend-api/api
///
/// Developers can override it intentionally with dart defines when needed.
class AppConfig {
  AppConfig._();

  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://abhiaijawedding.co.uk/backend-api/api',
  );

  static const bool _allowRuntimeApiOverride = bool.fromEnvironment(
    'ALLOW_RUNTIME_API_OVERRIDE',
    defaultValue: false,
  );

  static const String _prefsKey = 'api_base_url';

  /// The currently active base URL (including the `/api` prefix).
  static String _baseUrl = _defaultBaseUrl;

  /// REST API root, including the `/api` global prefix configured in
  /// `apps/api/src/main.ts`.
  static String get apiBaseUrl => _baseUrl;

  /// The compile-time / built-in default.
  static String get defaultBaseUrl => _defaultBaseUrl;

  /// Whether the last backend read succeeded. The UI listens to this to show a
  /// production connection warning when the server is unreachable.
  static final ValueNotifier<bool> backendOnline = ValueNotifier<bool>(true);

  /// Loads any saved URL override. Call once from `main()` before `runApp`.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_allowRuntimeApiOverride) {
        await prefs.remove(_prefsKey);
        return;
      }
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _baseUrl = saved.trim();
      }
    } catch (_) {
      // Storage unavailable -> keep the default; the app still works.
    }
  }

  /// Saves and activates a new backend URL. Trailing slashes are trimmed and a
  /// missing `/api` suffix is added so users can paste just `host:port`.
  static Future<void> setApiBaseUrl(String url) async {
    _baseUrl = normalize(url);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _baseUrl);
    } catch (_) {
      // Best-effort persistence; the in-memory value is already updated.
    }
  }

  /// Restores the built-in default URL and clears the saved override.
  static Future<void> resetApiBaseUrl() async {
    _baseUrl = _defaultBaseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// Cleans up user-entered URLs: trims spaces/trailing slashes and ensures the
  /// `/api` suffix the backend expects.
  static String normalize(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.isEmpty) return _defaultBaseUrl;
    if (!url.endsWith('/api')) url = '$url/api';
    return url;
  }

  /// Origin (no `/api`) used to resolve relative media paths the API returns,
  /// e.g. `/uploads/123.jpg` or `/images/passport_invitation.jpeg`.
  static String get mediaOrigin {
    final value = apiBaseUrl;
    return value.endsWith('/api')
        ? value.substring(0, value.length - '/api'.length)
        : value;
  }

  /// Turns a possibly-relative media path from the API into a fully qualified
  /// URL the app can load with `Image.network`.
  static String resolveMedia(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$mediaOrigin$path';
    return path;
  }

  /// How long network calls wait before falling back to bundled mock data.
  static const Duration requestTimeout = Duration(seconds: 8);
}
