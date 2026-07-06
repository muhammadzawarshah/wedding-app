import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/wedding_models.dart';

/// Result of an attempt to reach the backend. When [online] is false the
/// caller should fall back to bundled mock data so the app keeps working
/// offline / in APK demo mode.
class ApiResult<T> {
  const ApiResult.online(this.data) : online = true, error = null;
  const ApiResult.offline([this.error]) : online = false, data = null;

  final bool online;
  final T? data;
  final Object? error;
}

/// Outcome of a chatbot question. [answered] mirrors the backend's response;
/// when the FAQ has no match the question is queued to the organiser handoff.
class ChatbotReply {
  const ChatbotReply({required this.answered, required this.answer});

  final bool answered;
  final String answer;
}

/// Single client for the shared wedding platform backend (`apps/api`).
///
/// Holds the logged-in session (JWT + role) and exposes typed methods for the
/// mobile screens. Reads fall back to bundled defaults if the network is
/// unavailable, so the UI never breaks when the server is down.
class ApiService {
  ApiService._();

  /// App-wide singleton.
  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();

  String? _token;
  AdminUser? _currentUser;

  /// The JWT returned by the backend after a successful code login.
  String? get token => _token;

  /// The signed-in identity, or null before login.
  AdminUser? get currentUser => _currentUser;

  bool get isLoggedIn => _token != null;

  void logout() {
    _token = null;
    _currentUser = null;
  }

  Uri _uri(String path) => Uri.parse('${AppConfig.apiBaseUrl}$path');

  Map<String, String> _headers({bool auth = false}) {
    return {
      'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };
  }

  /// Records whether the backend was reachable on the most recent call so the
  /// UI can show an "offline / demo data" banner. Any HTTP response (even an
  /// error status) counts as reachable; only timeouts / socket errors are offline.
  void _setOnline(bool ok) {
    if (AppConfig.backendOnline.value != ok) AppConfig.backendOnline.value = ok;
  }

  /// Pings the backend (`GET /api/wedding`) to verify the configured URL is
  /// reachable. Used by the in-app "Test connection" button. Returns true when
  /// the server answers at all.
  Future<bool> healthCheck() async {
    try {
      final response = await _client
          .get(_uri('/wedding'), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      final ok = response.statusCode > 0;
      _setOnline(ok);
      return ok;
    } catch (_) {
      _setOnline(false);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Logs in with a 4-digit access code via `POST /api/auth/code-login`.
  ///
  /// All codes live in the backend database — there is no offline/hardcoded
  /// fallback. On success stores the JWT + role and returns the resolved
  /// [AdminUser]; returns null when the code is invalid. Throws on network /
  /// timeout errors so the UI can show a "server unreachable" message.
  Future<AdminUser?> login(String code) async {
    final response = await _client
        .post(
          _uri('/auth/code-login'),
          headers: _headers(),
          body: jsonEncode({'code': code}),
        )
        .timeout(AppConfig.requestTimeout);
    _setOnline(true);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      _token = body['accessToken'] as String?;
      final user = body['user'] as Map<String, dynamic>? ?? const {};
      _currentUser = AdminUser.fromApi(user, code: code);
      return _currentUser;
    }
    // 401 etc. -> invalid code per the backend.
    return null;
  }

  // ---------------------------------------------------------------------------
  // Access codes / logins (super-admin only)
  // ---------------------------------------------------------------------------

  /// Lists all logins via `GET /api/admin/access-codes` (super-admin only).
  /// Returns null on network failure so the UI can show an offline message.
  Future<List<AccessCode>?> fetchAccessCodes() async {
    if (_token == null) return null;
    try {
      final response = await _client
          .get(_uri('/admin/access-codes'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AccessCode.fromApi)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Creates a login via `POST /api/admin/access-codes` (super-admin only).
  /// Returns null on success, or a human-readable error message on failure
  /// (e.g. duplicate code) so the form can surface it.
  Future<String?> createAccessCode({
    required String label,
    required String code,
    required UserRole role,
    bool attending = true,
  }) async {
    if (_token == null) return 'Not signed in.';
    try {
      final response = await _client
          .post(
            _uri('/admin/access-codes'),
            headers: _headers(auth: true),
            body: jsonEncode({
              'label': label,
              'code': code,
              'role': userRoleToApi(role),
              'attending': attending,
            }),
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode == 200 || response.statusCode == 201) return null;
      return _errorMessage(response.body) ?? 'Could not create login.';
    } catch (_) {
      return 'Could not reach the server.';
    }
  }

  /// Updates a login via `PATCH /api/admin/access-codes/:id` (super-admin only).
  Future<bool> updateAccessCode(String id, Map<String, dynamic> body) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .patch(
            _uri('/admin/access-codes/$id'),
            headers: _headers(auth: true),
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a login via `DELETE /api/admin/access-codes/:id` (super-admin only).
  Future<bool> deleteAccessCode(String id) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .delete(
            _uri('/admin/access-codes/$id'),
            headers: _headers(auth: true),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // AI knowledge notes (admin)
  // ---------------------------------------------------------------------------

  /// Lists AI knowledge notes via `GET /api/admin/notes` (admin only).
  /// Returns null on network failure so the UI can show an offline message.
  Future<List<AiNote>?> fetchNotes() async {
    if (_token == null) return null;
    try {
      final response = await _client
          .get(_uri('/admin/notes'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AiNote.fromApi)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Creates a note via `POST /api/admin/notes` (admin only).
  Future<bool> createNote({
    required String content,
    String title = '',
    String createdBy = '',
  }) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .post(
            _uri('/admin/notes'),
            headers: _headers(auth: true),
            body: jsonEncode({
              'title': title,
              'content': content,
              'createdBy': createdBy,
            }),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Updates a note via `PATCH /api/admin/notes/:id` (admin only).
  Future<bool> updateNote(String id, Map<String, dynamic> body) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .patch(
            _uri('/admin/notes/$id'),
            headers: _headers(auth: true),
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a note via `DELETE /api/admin/notes/:id` (admin only).
  Future<bool> deleteNote(String id) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .delete(_uri('/admin/notes/$id'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Pulls the `message` field out of a NestJS error body, if present.
  String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String) return message;
        if (message is List && message.isNotEmpty) {
          return message.first.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Wedding content (read, with mock fallback)
  // ---------------------------------------------------------------------------

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
    List<T> fallback,
  ) async {
    try {
      final response = await _client
          .get(_uri(path), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      _setOnline(true);
      if (response.statusCode != 200) return fallback;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return fallback;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false);
    } catch (_) {
      _setOnline(false);
      return fallback;
    }
  }

  /// Fetches the wedding overview (names, venue, map/stream/gift links) from
  /// `GET /api/wedding`. Falls back to bundled defaults when offline.
  Future<WeddingOverview> fetchOverview() async {
    try {
      final noCacheHeaders = {
        ..._headers(),
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      };
      final response = await _client
          .get(
            _uri('/wedding?ts=${DateTime.now().millisecondsSinceEpoch}'),
            headers: noCacheHeaders,
          )
          .timeout(AppConfig.requestTimeout);
      _setOnline(true);
      if (response.statusCode != 200) return WeddingOverview.fallback;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return WeddingOverview.fallback;
      return WeddingOverview.fromApi(decoded);
    } catch (_) {
      _setOnline(false);
      return WeddingOverview.fallback;
    }
  }

  Future<List<WeddingEvent>> fetchEvents() =>
      _getList('/wedding/events', WeddingEvent.fromApi, const <WeddingEvent>[]);

  Future<List<FamilyMember>> fetchFamily() =>
      _getList('/wedding/family', FamilyMember.fromApi, const <FamilyMember>[]);

  Future<List<GalleryItem>> fetchGallery() =>
      _getList('/wedding/gallery', GalleryItem.fromApi, const <GalleryItem>[]);

  /// Public gift/payment options (`GET /api/wedding/payment-methods`).
  Future<List<PaymentMethod>> fetchPaymentMethods() => _getList(
    '/wedding/payment-methods',
    PaymentMethod.fromApi,
    const <PaymentMethod>[],
  );

  /// Fetches the home hero carousel slides (managed by admins) and returns
  /// resolved image URLs. Returns an empty list on failure so the caller can
  /// fall back to bundled asset images.
  Future<List<String>> fetchCarousel() async {
    try {
      final response = await _client
          .get(_uri('/wedding/carousel'), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      _setOnline(true);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (row) => AppConfig.resolveMedia(row['imageUrl'] as String? ?? ''),
          )
          .where((url) => url.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      _setOnline(false);
      return const [];
    }
  }

  // ---------------------------------------------------------------------------
  // Carousel management (admin)
  // ---------------------------------------------------------------------------

  /// Full carousel slides (with ids) for the admin manager.
  Future<List<CarouselSlide>> fetchCarouselSlides() async {
    try {
      final response = await _client
          .get(_uri('/wedding/carousel'), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(CarouselSlide.fromApi)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Uploads an image/video file to `POST /api/admin/media` (admin only) and
  /// returns the stored URL, or null on failure.
  Future<String?> uploadMedia(String filePath) async {
    if (_token == null) return null;
    try {
      final request = http.MultipartRequest('POST', _uri('/admin/media'))
        ..headers['Authorization'] = 'Bearer $_token'
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['url'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Adds a carousel slide via `POST /api/admin/carousel` (admin only).
  Future<bool> createCarouselSlide({
    required String imageUrl,
    String caption = '',
    int sortOrder = 0,
  }) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .post(
            _uri('/admin/carousel'),
            headers: _headers(auth: true),
            body: jsonEncode({
              'imageUrl': imageUrl,
              'caption': caption,
              'sortOrder': sortOrder,
            }),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Deletes a carousel slide via `DELETE /api/admin/carousel/:id` (admin only).
  Future<bool> deleteCarouselSlide(String id) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .delete(_uri('/admin/carousel/$id'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Updates a carousel slide via `PATCH /api/admin/carousel/:id` (admin only).
  Future<bool> updateCarouselSlide({
    required String id,
    required String imageUrl,
    String caption = '',
    int sortOrder = 0,
  }) => updateContent('carousel', id, {
    'imageUrl': imageUrl,
    'caption': caption,
    'sortOrder': sortOrder,
  });

  // ---------------------------------------------------------------------------
  // Admin dashboard content (stats + generic CRUD)
  // ---------------------------------------------------------------------------

  /// Loads the dashboard counters from `GET /api/admin/dashboard` (admin only).
  /// Returns null on failure so the header can hide gracefully.
  Future<DashboardStats?> fetchDashboardStats() async {
    if (_token == null) return null;
    try {
      final response = await _client
          .get(_uri('/admin/dashboard'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      _setOnline(true);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return DashboardStats.fromApi(decoded);
    } catch (_) {
      _setOnline(false);
      return null;
    }
  }

  /// Loads all editable content in one call (`GET /api/admin/content`).
  /// Returns null on network failure so panels can show an offline message.
  Future<AdminContent?> fetchAdminContent() async {
    if (_token == null) return null;
    try {
      final response = await _client
          .get(_uri('/admin/content'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      _setOnline(true);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return AdminContent.fromApi(decoded);
    } catch (_) {
      _setOnline(false);
      return null;
    }
  }

  /// Saves the wedding details via `PUT /api/admin/wedding` (admin only).
  Future<bool> updateWedding(Map<String, dynamic> body) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .put(
            _uri('/admin/wedding'),
            headers: _headers(auth: true),
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Creates an item in an admin content [section] (`events`, `family`,
  /// `gallery`, `faqs`, `carousel`) via `POST /api/admin/:section`.
  Future<bool> createContent(String section, Map<String, dynamic> body) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .post(
            _uri('/admin/$section'),
            headers: _headers(auth: true),
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Updates an item via `PATCH /api/admin/:section/:id`.
  Future<bool> updateContent(
    String section,
    String id,
    Map<String, dynamic> body,
  ) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .patch(
            _uri('/admin/$section/$id'),
            headers: _headers(auth: true),
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Reorders a section via `PATCH /api/admin/reorder/:section` with the new
  /// id order (`events`, `family`, `carousel`, `payments`).
  Future<bool> reorderContent(String section, List<String> ids) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .patch(
            _uri('/admin/reorder/$section'),
            headers: _headers(auth: true),
            body: jsonEncode({'ids': ids}),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Deletes an item via `DELETE /api/admin/:section/:id`.
  Future<bool> deleteContent(String section, String id) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .delete(_uri('/admin/$section/$id'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Guest memory uploads
  // ---------------------------------------------------------------------------

  /// Uploads a guest's actual photo/video to the public
  /// `POST /api/uploads/file` endpoint so an admin can preview it before
  /// approving. Returns `{ url, size, fileName }` or null on failure.
  Future<({String url, int size, String fileName})?> uploadGuestMedia(
    String filePath,
  ) async {
    try {
      final request = http.MultipartRequest('POST', _uri('/uploads/file'))
        ..files.add(await http.MultipartFile.fromPath('file', filePath));
      final streamed = await request.send().timeout(
        const Duration(seconds: 90),
      );
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final url = body['url'] as String?;
      if (url == null) return null;
      return (
        url: url,
        size: (body['size'] as num?)?.toInt() ?? 0,
        fileName: body['fileName'] as String? ?? 'upload',
      );
    } catch (_) {
      return null;
    }
  }

  /// Submits a memory for moderation via `POST /api/uploads`.
  /// Returns the created upload's id on success, or null on failure.
  Future<String?> createUpload({
    required String guestName,
    required String caption,
    required String fileName,
    required String mediaType, // 'Photo' | 'Video'
    int fileSizeBytes = 0,
    String? fileUrl,
  }) async {
    final body = <String, dynamic>{
      'guestName': guestName,
      'caption': caption,
      'fileName': fileName,
      'mediaType': mediaType.toLowerCase(),
      'fileSizeBytes': fileSizeBytes,
    };
    if (fileUrl != null) body['fileUrl'] = fileUrl;
    try {
      final response = await _client
          .post(
            _uri('/uploads'),
            headers: _headers(auth: true),
            body: jsonEncode(body),
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded['id']?.toString() : null;
    } catch (_) {
      return null;
    }
  }

  /// Approved guest memories shown to everyone (`GET /api/uploads/approved`).
  Future<List<GuestUpload>> fetchApprovedUploads() async {
    try {
      final response = await _client
          .get(_uri('/uploads/approved'), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(GuestUpload.fromApi)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Status of a single upload (`GET /api/uploads/:id`) so an uploader can see
  /// whether their own pending memory was approved or rejected.
  Future<GuestUpload?> fetchUploadById(String id) async {
    try {
      final response = await _client
          .get(_uri('/uploads/$id'), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return null;
      return GuestUpload.fromApi(decoded);
    } catch (_) {
      return null;
    }
  }

  /// All guest uploads from the shared backend (`GET /api/uploads`), newest
  /// first — what the admin moderates. Returns null on network failure so the
  /// caller can fall back to the local in-session list.
  Future<List<GuestUpload>?> fetchUploads() async {
    try {
      final response = await _client
          .get(_uri('/uploads'), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(GuestUpload.fromApi)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Approves/rejects an upload via `PATCH /api/uploads/:id/moderate` so the
  /// decision is shared with every admin and device.
  Future<bool> moderateUpload({
    required String id,
    required UploadStatus status,
    required String moderatedBy,
  }) async {
    try {
      final response = await _client
          .patch(
            _uri('/uploads/$id/moderate'),
            headers: _headers(auth: true),
            body: jsonEncode({
              'status': status == UploadStatus.approved
                  ? 'approved'
                  : 'rejected',
              'moderatedBy': moderatedBy,
            }),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Permanently deletes a guest upload via `DELETE /api/uploads/:id` (admin).
  Future<bool> deleteUpload(String id) async {
    if (_token == null) return false;
    try {
      final response = await _client
          .delete(_uri('/uploads/$id'), headers: _headers(auth: true))
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Chatbot
  // ---------------------------------------------------------------------------

  /// Asks the shared FAQ assistant via `POST /api/chatbot/ask`.
  /// Unanswered questions are queued to the organiser handoff on the backend.
  /// Returns null on network failure so the caller can use the local FAQ.
  Future<ChatbotReply?> askChatbot(
    String question, {
    String askedBy = 'Guest',
  }) async {
    try {
      final response = await _client
          .post(
            _uri('/chatbot/ask'),
            headers: _headers(auth: true),
            body: jsonEncode({'question': question, 'askedBy': askedBy}),
          )
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200 && response.statusCode != 201) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return ChatbotReply(
        answered: body['answered'] as bool? ?? false,
        answer: body['answer'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Unanswered/answered guest questions sent to the organiser queue
  /// (`GET /api/chatbot/handoffs`). Returns null on failure for local fallback.
  Future<List<SupportQuestion>?> fetchHandoffs() async {
    try {
      final response = await _client
          .get(_uri('/chatbot/handoffs'), headers: _headers())
          .timeout(AppConfig.requestTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(SupportQuestion.fromApi)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  /// Posts an admin reply via `PATCH /api/chatbot/handoffs/:id/answer` so the
  /// answer is stored centrally for every admin to see.
  Future<bool> answerHandoff({
    required String id,
    required String answer,
    required String answeredBy,
  }) async {
    try {
      final response = await _client
          .patch(
            _uri('/chatbot/handoffs/$id/answer'),
            headers: _headers(auth: true),
            body: jsonEncode({'answer': answer, 'answeredBy': answeredBy}),
          )
          .timeout(AppConfig.requestTimeout);
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }
}
