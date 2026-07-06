import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A memory this device uploaded. Stored locally so the uploader can see their
/// own pending memory before an admin approves it for everyone.
class MyUpload {
  const MyUpload({
    required this.id,
    required this.guestName,
    required this.caption,
    required this.fileUrl,
    required this.mediaType, // 'Photo' | 'Video'
  });

  final String id;
  final String guestName;
  final String caption;
  final String fileUrl;
  final String mediaType;

  bool get isVideo => mediaType.toLowerCase() == 'video';

  Map<String, dynamic> toJson() => {
        'id': id,
        'guestName': guestName,
        'caption': caption,
        'fileUrl': fileUrl,
        'mediaType': mediaType,
      };

  factory MyUpload.fromJson(Map<String, dynamic> j) => MyUpload(
        id: j['id'] as String? ?? '',
        guestName: j['guestName'] as String? ?? '',
        caption: j['caption'] as String? ?? '',
        fileUrl: j['fileUrl'] as String? ?? '',
        mediaType: j['mediaType'] as String? ?? 'Photo',
      );
}

/// Persists the guest's own uploads on this device (no per-guest login).
class MyUploads {
  static const _key = 'wedding_my_uploads';

  static Future<List<MyUpload>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.whereType<Map<String, dynamic>>().map(MyUpload.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(MyUpload upload) async {
    final current = await all();
    final next = [upload, ...current.where((item) => item.id != upload.id)];
    await replace(next);
  }

  static Future<void> replace(List<MyUpload> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(list.map((item) => item.toJson()).toList()));
  }
}
