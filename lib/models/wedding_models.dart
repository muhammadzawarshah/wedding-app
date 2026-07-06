import 'package:flutter/material.dart';

import '../config/app_config.dart';

enum UserRole { guest, organizer, superAdmin }

/// Maps the backend role strings (`guest`, `organizer`, `super_admin`) to the
/// app's [UserRole] enum. Defaults to [UserRole.guest] for anything unknown.
UserRole userRoleFromApi(String? value) {
  switch (value) {
    case 'organizer':
      return UserRole.organizer;
    case 'super_admin':
      return UserRole.superAdmin;
    default:
      return UserRole.guest;
  }
}

/// Maps a [UserRole] back to the backend string the API expects.
String userRoleToApi(UserRole role) {
  switch (role) {
    case UserRole.organizer:
      return 'organizer';
    case UserRole.superAdmin:
      return 'super_admin';
    case UserRole.guest:
      return 'guest';
  }
}

enum UploadStatus { pending, approved, rejected }

UploadStatus uploadStatusFromApi(String? value) {
  switch (value) {
    case 'approved':
      return UploadStatus.approved;
    case 'rejected':
      return UploadStatus.rejected;
    default:
      return UploadStatus.pending;
  }
}

class AdminUser {
  const AdminUser({
    required this.name,
    required this.role,
    required this.code,
    this.attending = true,
  });

  /// Builds an admin/guest identity from the `user` object returned by
  /// `POST /api/auth/code-login` (`{ sub, role, attending }`).
  factory AdminUser.fromApi(Map<String, dynamic> json, {required String code}) {
    final label = (json['sub'] as String?)?.trim();
    return AdminUser(
      name: (label != null && label.isNotEmpty) ? label : 'Wedding Guest',
      role: userRoleFromApi(json['role'] as String?),
      code: code,
      // Defaults to true so admins (and older tokens without the flag) keep
      // full access; only an explicit `false` marks a non-attending guest.
      attending: json['attending'] != false,
    );
  }

  final String name;
  final UserRole role;
  final String code;

  /// Guest-only flag. A non-attending guest (`role == guest && !attending`)
  /// can browse everything except the "Upload memories" form.
  final bool attending;

  bool get canModerate =>
      role == UserRole.organizer || role == UserRole.superAdmin;
  bool get canManageFamily => role == UserRole.superAdmin;

  /// Admin dashboard users can create/manage logins (access codes).
  bool get canManageAccessCodes =>
      role == UserRole.organizer || role == UserRole.superAdmin;

  /// Everyone except a non-attending guest may upload memories.
  bool get canUploadMemories => role != UserRole.guest || attending;
}

/// A 4-digit login as managed by the couple on `/admin/access-codes`.
class AccessCode {
  const AccessCode({
    required this.id,
    required this.label,
    required this.code,
    required this.role,
    required this.attending,
    required this.active,
  });

  factory AccessCode.fromApi(Map<String, dynamic> json) {
    return AccessCode(
      id: json['id']?.toString() ?? '',
      label: json['label'] as String? ?? '',
      code: json['code'] as String? ?? '',
      role: userRoleFromApi(json['role'] as String?),
      attending: json['attending'] != false,
      active: json['active'] != false,
    );
  }

  final String id;
  final String label;
  final String code;
  final UserRole role;
  final bool attending;
  final bool active;

  /// Human label for the login "type" used in the management UI.
  String get typeLabel {
    switch (role) {
      case UserRole.organizer:
        return 'Organiser';
      case UserRole.superAdmin:
        return 'Couple (super admin)';
      case UserRole.guest:
        return attending ? 'Attending guest' : 'Non-attending guest';
    }
  }
}

/// A free-form knowledge note admins write for the AI assistant
/// (`GET/POST/PATCH/DELETE /api/admin/notes`).
class AiNote {
  const AiNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdBy,
    required this.active,
  });

  factory AiNote.fromApi(Map<String, dynamic> json) {
    return AiNote(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      active: json['active'] != false,
    );
  }

  final String id;
  final String title;
  final String content;
  final String createdBy;
  final bool active;
}

/// Core wedding details + links managed from the admin "Wedding settings"
/// panel and served by `GET /api/wedding`.
class WeddingOverview {
  const WeddingOverview({
    required this.brideName,
    required this.groomName,
    required this.weddingDate,
    required this.venueName,
    required this.venueAddress,
    required this.mapUrl,
    required this.streamUrl,
    required this.giftUrl,
    required this.transportDescription,
    this.venueUrl = '',
    this.liveIsActive = false,
    this.liveTitle = '',
  });

  factory WeddingOverview.fromApi(Map<String, dynamic> json) {
    String str(String key, String fallback) {
      final value = json[key];
      return (value is String && value.trim().isNotEmpty) ? value : fallback;
    }

    return WeddingOverview(
      brideName: str('brideName', ''),
      groomName: str('groomName', ''),
      weddingDate: str('weddingDate', ''),
      venueName: str('venueName', ''),
      venueAddress: str('venueAddress', ''),
      mapUrl: str('mapUrl', ''),
      streamUrl: str('streamUrl', ''),
      giftUrl: str('giftUrl', ''),
      transportDescription: str('transportDescription', ''),
      venueUrl: str('venueUrl', ''),
      liveIsActive: json['liveIsActive'] == true,
      liveTitle: str('liveTitle', ''),
    );
  }

  /// Empty placeholder used when the backend is unreachable or has no config
  /// yet. Intentionally blank so no dummy wedding details are ever shown.
  static const WeddingOverview fallback = WeddingOverview(
    brideName: '',
    groomName: '',
    weddingDate: '',
    venueName: '',
    venueAddress: '',
    mapUrl: '',
    streamUrl: '',
    giftUrl: '',
    transportDescription: '',
  );

  final String brideName;
  final String groomName;
  final String weddingDate;
  final String venueName;
  final String venueAddress;
  final String mapUrl;
  final String streamUrl;
  final String giftUrl;
  final String transportDescription;
  final String venueUrl;
  final bool liveIsActive;
  final String liveTitle;

  /// JSON body for `PUT /api/admin/wedding` (matches `UpdateWeddingDto`).
  Map<String, dynamic> toAdminJson() {
    final body = <String, dynamic>{
      'brideName': brideName,
      'groomName': groomName,
      'weddingDate': weddingDate,
      'venueName': venueName,
      'venueAddress': venueAddress,
      'transportDescription': transportDescription,
      'venueUrl': venueUrl.trim(),
      'liveTitle': liveTitle,
      'liveIsActive': liveIsActive,
    };
    if (mapUrl.trim().isNotEmpty) body['mapUrl'] = mapUrl.trim();
    if (streamUrl.trim().isNotEmpty) body['streamUrl'] = streamUrl.trim();
    if (giftUrl.trim().isNotEmpty) body['giftUrl'] = giftUrl.trim();
    return body;
  }

  WeddingOverview copyWith({
    String? brideName,
    String? groomName,
    String? weddingDate,
    String? venueName,
    String? venueAddress,
    String? mapUrl,
    String? streamUrl,
    String? giftUrl,
    String? transportDescription,
    String? venueUrl,
    bool? liveIsActive,
    String? liveTitle,
  }) {
    return WeddingOverview(
      brideName: brideName ?? this.brideName,
      groomName: groomName ?? this.groomName,
      weddingDate: weddingDate ?? this.weddingDate,
      venueName: venueName ?? this.venueName,
      venueAddress: venueAddress ?? this.venueAddress,
      mapUrl: mapUrl ?? this.mapUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      giftUrl: giftUrl ?? this.giftUrl,
      transportDescription: transportDescription ?? this.transportDescription,
      venueUrl: venueUrl ?? this.venueUrl,
      liveIsActive: liveIsActive ?? this.liveIsActive,
      liveTitle: liveTitle ?? this.liveTitle,
    );
  }
}

/// A chatbot FAQ entry managed from the admin "FAQs" panel
/// (`{ id, keyword, answer }`, served inside `GET /api/admin/content`).
class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.keyword,
    required this.answer,
  });

  factory FaqEntry.fromApi(Map<String, dynamic> json) {
    return FaqEntry(
      id: json['id']?.toString() ?? '',
      keyword: json['keyword'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }

  final String id;
  final String keyword;
  final String answer;

  /// JSON body for `POST/PATCH /api/admin/faqs` (matches `FaqDto`).
  Map<String, dynamic> toAdminJson() => {'keyword': keyword, 'answer': answer};
}

/// Counts shown on the admin dashboard header (`GET /api/admin/dashboard`).
class DashboardStats {
  const DashboardStats({
    required this.pendingUploads,
    required this.unansweredQuestions,
    required this.totalUploads,
  });

  factory DashboardStats.fromApi(Map<String, dynamic> json) {
    return DashboardStats(
      pendingUploads: (json['pendingUploads'] as num?)?.toInt() ?? 0,
      unansweredQuestions: (json['unansweredQuestions'] as num?)?.toInt() ?? 0,
      totalUploads: (json['totalUploads'] as num?)?.toInt() ?? 0,
    );
  }

  final int pendingUploads;
  final int unansweredQuestions;
  final int totalUploads;
}

/// All editable content returned in one call by `GET /api/admin/content`.
class AdminContent {
  const AdminContent({
    required this.wedding,
    required this.events,
    required this.family,
    required this.gallery,
    required this.faqs,
    required this.carousel,
    this.payments = const <PaymentMethod>[],
  });

  factory AdminContent.fromApi(Map<String, dynamic> json) {
    List<T> parse<T>(String key, T Function(Map<String, dynamic>) from) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw.whereType<Map<String, dynamic>>().map(from).toList();
    }

    final weddingJson = json['wedding'];
    return AdminContent(
      wedding: weddingJson is Map<String, dynamic>
          ? WeddingOverview.fromApi(weddingJson)
          : WeddingOverview.fallback,
      events: parse('events', WeddingEvent.fromApi),
      family: parse('family', FamilyMember.fromApi),
      gallery: parse('gallery', GalleryItem.fromApi),
      faqs: parse('faqs', FaqEntry.fromApi),
      carousel: parse('carousel', CarouselSlide.fromApi),
      payments: parse('payments', PaymentMethod.fromApi),
    );
  }

  final WeddingOverview wedding;
  final List<WeddingEvent> events;
  final List<FamilyMember> family;
  final List<GalleryItem> gallery;
  final List<FaqEntry> faqs;
  final List<CarouselSlide> carousel;
  final List<PaymentMethod> payments;
}

/// A gift/payment option the couple offers for one currency
/// (`GET /api/wedding/payment-methods`, `POST/PATCH/DELETE /api/admin/payments`).
class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.currency,
    required this.type,
    this.link = '',
    this.rawQrUrl = '',
    this.qrUrl = '',
    this.accountDetails = '',
    this.description = '',
    this.active = true,
    this.sortOrder = 0,
  });

  factory PaymentMethod.fromApi(Map<String, dynamic> json) {
    final rawQr = json['qrUrl'] as String? ?? '';
    return PaymentMethod(
      id: json['id']?.toString() ?? '',
      currency: json['currency'] as String? ?? '',
      type: json['type'] as String? ?? 'link',
      link: json['link'] as String? ?? '',
      rawQrUrl: rawQr,
      qrUrl: AppConfig.resolveMedia(rawQr),
      accountDetails: json['accountDetails'] as String? ?? '',
      description: json['description'] as String? ?? '',
      active: json['active'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String currency;

  /// One of `link`, `qr`, `account`.
  final String type;
  final String link;
  final String rawQrUrl;
  final String qrUrl;
  final String accountDetails;
  final String description;
  final bool active;
  final int sortOrder;

  String get typeLabel {
    switch (type) {
      case 'qr':
        return 'QR code';
      case 'account':
        return 'Account details';
      default:
        return 'Link';
    }
  }

  /// JSON body for `POST/PATCH /api/admin/payments` (matches `PaymentDto`).
  Map<String, dynamic> toAdminJson() => {
    'currency': currency,
    'type': type,
    'link': link,
    'qrUrl': rawQrUrl,
    'accountDetails': accountDetails,
    'description': description,
    'active': active,
    'sortOrder': sortOrder,
  };
}

/// A home hero carousel slide as managed by admins
/// (`GET /api/wedding/carousel`, `POST/DELETE /api/admin/carousel`).
class CarouselSlide {
  const CarouselSlide({
    required this.id,
    required this.imageUrl,
    required this.caption,
    required this.sortOrder,
  });

  factory CarouselSlide.fromApi(Map<String, dynamic> json) {
    return CarouselSlide(
      id: json['id']?.toString() ?? '',
      imageUrl: AppConfig.resolveMedia(json['imageUrl'] as String? ?? ''),
      caption: json['caption'] as String? ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String imageUrl;
  final String caption;
  final int sortOrder;
}

class WeddingEvent {
  const WeddingEvent({
    required this.title,
    required this.date,
    required this.time,
    required this.venue,
    required this.description,
    this.id = '',
    this.sortOrder = 0,
    this.streamUrl = '',
    this.recordingUrl = '',
    this.isLive = false,
  });

  /// Parses a `GET /api/wedding/events` row
  /// (`{ id, title, eventDate, eventTime, venue, description, streamUrl,
  /// recordingUrl, isLive, sortOrder }`).
  factory WeddingEvent.fromApi(Map<String, dynamic> json) {
    return WeddingEvent(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      date: json['eventDate'] as String? ?? '',
      time: json['eventTime'] as String? ?? '',
      venue: json['venue'] as String? ?? '',
      description: json['description'] as String? ?? '',
      streamUrl: json['streamUrl'] as String? ?? '',
      recordingUrl: json['recordingUrl'] as String? ?? '',
      isLive: json['isLive'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// Server id (present when loaded from the admin content endpoint). Empty for
  /// bundled/offline rows that cannot be edited.
  final String id;
  final int sortOrder;
  final String title;
  final String date;
  final String time;
  final String venue;
  final String description;
  final String streamUrl;
  final String recordingUrl;
  final bool isLive;

  /// JSON body for `POST/PATCH /api/admin/events` (matches `EventDto`).
  Map<String, dynamic> toAdminJson() => {
    'title': title,
    'eventDate': date,
    'eventTime': time,
    'venue': venue,
    'description': description,
    'sortOrder': sortOrder,
    'streamUrl': streamUrl,
    'recordingUrl': recordingUrl,
    'isLive': isLive,
  };

  /// True when the event has a live stream running or a recording to watch.
  bool get hasStream => isLive && streamUrl.isNotEmpty;
  bool get hasRecording =>
      recordingUrl.isNotEmpty || (!isLive && streamUrl.isNotEmpty);
  String get watchUrl => hasStream
      ? streamUrl
      : (recordingUrl.isNotEmpty ? recordingUrl : streamUrl);
}

class FamilyMember {
  const FamilyMember({
    required this.name,
    required this.relation,
    required this.side,
    required this.imageAsset,
    this.id = '',
    this.sortOrder = 0,
    this.rawImageUrl = '',
    this.rawImages = const <String>[],
    this.description = '',
    this.showRelation = true,
  });

  /// Parses a `GET /api/wedding/family` row
  /// (`{ id, name, relation, side, imageUrl, images, description,
  /// showRelation, sortOrder }`).
  factory FamilyMember.fromApi(Map<String, dynamic> json) {
    final rawImageUrl = json['imageUrl'] as String? ?? '';
    final imagesRaw = json['images'];
    final rawImages = (imagesRaw is List)
        ? imagesRaw
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList()
        : <String>[];
    return FamilyMember(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      relation: json['relation'] as String? ?? '',
      side: json['side'] as String? ?? '',
      imageAsset: AppConfig.resolveMedia(rawImageUrl),
      rawImageUrl: rawImageUrl,
      rawImages: rawImages,
      description: json['description'] as String? ?? '',
      showRelation: json['showRelation'] != false,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final int sortOrder;
  final String name;
  final String relation;
  final String side;
  final String imageAsset;

  /// The unresolved `imageUrl` exactly as stored by the backend, sent back
  /// unchanged on edits so the photo is preserved.
  final String rawImageUrl;

  /// All photos (unresolved URLs). First one is the cover. Empty for older rows
  /// that only have a single [rawImageUrl].
  final List<String> rawImages;

  /// Optional styled description shown when a guest opens the member.
  final String description;

  /// Whether the relationship tag is shown on the site.
  final bool showRelation;

  /// True when [imageAsset] is a remote URL (loaded with `Image.network`)
  /// rather than a bundled asset path.
  bool get isRemoteImage => imageAsset.startsWith('http');

  /// Resolved photo URLs for the gallery view (falls back to the cover image).
  List<String> get imageAssets {
    if (rawImages.isNotEmpty) {
      return rawImages.map(AppConfig.resolveMedia).toList(growable: false);
    }
    return imageAsset.isNotEmpty ? <String>[imageAsset] : const <String>[];
  }

  /// JSON body for `POST/PATCH /api/admin/family` (matches `FamilyDto`).
  Map<String, dynamic> toAdminJson() {
    final cover = rawImages.isNotEmpty ? rawImages.first : rawImageUrl;
    return {
      'name': name,
      'relation': relation,
      'side': side,
      'description': description,
      'imageUrl': cover,
      'images': rawImages,
      'showRelation': showRelation,
      'sortOrder': sortOrder,
    };
  }
}

class GalleryItem {
  const GalleryItem({
    required this.title,
    required this.caption,
    required this.imageAsset,
    this.isVideo = false,
    this.id = '',
    this.rawMediaUrl = '',
  });

  /// Parses a `GET /api/wedding/gallery` row
  /// (`{ id, title, caption, mediaUrl, mediaType }`).
  factory GalleryItem.fromApi(Map<String, dynamic> json) {
    final rawMediaUrl = json['mediaUrl'] as String? ?? '';
    return GalleryItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      imageAsset: AppConfig.resolveMedia(rawMediaUrl),
      rawMediaUrl: rawMediaUrl,
      isVideo: (json['mediaType'] as String?) == 'video',
    );
  }

  final String id;
  final String title;
  final String caption;
  final String imageAsset;

  /// The unresolved `mediaUrl` exactly as stored by the backend.
  final String rawMediaUrl;
  final bool isVideo;

  /// True when [imageAsset] is a remote URL (loaded with `Image.network`)
  /// rather than a bundled asset path.
  bool get isRemoteImage => imageAsset.startsWith('http');

  /// JSON body for `POST/PATCH /api/admin/gallery` (matches `GalleryDto`).
  Map<String, dynamic> toAdminJson() => {
    'title': title,
    'caption': caption,
    'mediaUrl': rawMediaUrl,
    'mediaType': isVideo ? 'video' : 'photo',
  };
}

class GuestUpload {
  const GuestUpload({
    required this.id,
    required this.guestName,
    required this.caption,
    required this.type,
    required this.fileName,
    required this.fileSizeBytes,
    required this.status,
    this.fileUrl,
  });

  /// Parses a `GET /api/uploads` row.
  factory GuestUpload.fromApi(Map<String, dynamic> json) {
    final mediaType = (json['mediaType'] as String?) ?? 'photo';
    final url = json['fileUrl'] as String?;
    return GuestUpload(
      id: json['id']?.toString() ?? '',
      guestName: json['guestName'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      type: mediaType == 'video' ? 'Video' : 'Photo',
      fileName: json['fileName'] as String? ?? '',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      status: uploadStatusFromApi(json['status'] as String?),
      fileUrl: (url != null && url.isNotEmpty)
          ? AppConfig.resolveMedia(url)
          : null,
    );
  }

  final String id;
  final String guestName;
  final String caption;
  final String type;
  final String fileName;
  final int fileSizeBytes;
  final UploadStatus status;

  /// Resolved URL of the actual uploaded photo/video, if any.
  final String? fileUrl;

  bool get isVideo => type == 'Video';
  bool get hasMedia => fileUrl != null && fileUrl!.isNotEmpty;

  GuestUpload copyWith({UploadStatus? status}) {
    return GuestUpload(
      id: id,
      guestName: guestName,
      caption: caption,
      type: type,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      status: status ?? this.status,
      fileUrl: fileUrl,
    );
  }
}

class ChatMessage {
  const ChatMessage({required this.text, required this.isGuest});

  final String text;
  final bool isGuest;
}

class SupportQuestion {
  const SupportQuestion({
    required this.id,
    required this.question,
    required this.askedBy,
    this.answer,
  });

  /// Parses a `GET /api/chatbot/handoffs` row.
  factory SupportQuestion.fromApi(Map<String, dynamic> json) {
    final answer = json['answer'] as String?;
    return SupportQuestion(
      id: json['id']?.toString() ?? '',
      question: json['question'] as String? ?? '',
      askedBy: json['askedBy'] as String? ?? 'Guest',
      answer: (answer != null && answer.trim().isNotEmpty) ? answer : null,
    );
  }

  final String id;
  final String question;
  final String askedBy;
  final String? answer;

  bool get isAnswered => answer != null && answer!.isNotEmpty;

  SupportQuestion copyWith({String? answer}) {
    return SupportQuestion(
      id: id,
      question: question,
      askedBy: askedBy,
      answer: answer ?? this.answer,
    );
  }
}

class FeatureItem {
  const FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
