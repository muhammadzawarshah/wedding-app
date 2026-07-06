import 'package:flutter/material.dart';

import '../models/wedding_models.dart';

class MockWeddingData {
  static final features = [
    FeatureItem(
      title: 'Live Stream',
      subtitle: 'Watch the ceremony live',
      icon: Icons.live_tv,
    ),
    FeatureItem(
      title: 'Transport',
      subtitle: 'Travel from Riga',
      icon: Icons.directions_bus,
    ),
    FeatureItem(
      title: 'Send Gift',
      subtitle: 'Open the PayPal gift link',
      icon: Icons.card_giftcard,
    ),
    FeatureItem(
      title: 'Itinerary',
      subtitle: 'See all wedding events',
      icon: Icons.event,
    ),
    FeatureItem(
      title: 'Gallery',
      subtitle: 'Photos and approved memories',
      icon: Icons.photo_library,
    ),
    FeatureItem(
      title: 'Location',
      subtitle: 'Venue and map details',
      icon: Icons.location_on,
    ),
    FeatureItem(
      title: 'Family',
      subtitle: 'Couple and family photos',
      icon: Icons.groups,
    ),
    FeatureItem(
      title: 'AI Assistant',
      subtitle: 'Ask wedding questions',
      icon: Icons.smart_toy,
    ),
    FeatureItem(
      title: 'Upload Memories',
      subtitle: 'Send photos/videos for approval',
      icon: Icons.cloud_upload,
    ),
    FeatureItem(
      title: 'Admin Dashboard',
      subtitle: 'Moderation and replies',
      icon: Icons.admin_panel_settings,
    ),
  ];
}

class AppState {
  AppState._();

  static final uploads = ValueNotifier<List<GuestUpload>>([]);

  static final supportQuestions = ValueNotifier<List<SupportQuestion>>([]);

  static void addUpload({
    required String guestName,
    required String caption,
    required String type,
    required String fileName,
    required int fileSizeBytes,
  }) {
    final next = GuestUpload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      guestName: guestName,
      caption: caption,
      type: type,
      fileName: fileName,
      fileSizeBytes: fileSizeBytes,
      status: UploadStatus.pending,
    );
    uploads.value = [next, ...uploads.value];
  }

  static void updateUpload(String id, UploadStatus status) {
    uploads.value = [
      for (final upload in uploads.value)
        if (upload.id == id) upload.copyWith(status: status) else upload,
    ];
  }

  static void addQuestion(String question) {
    final next = SupportQuestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      askedBy: 'Guest',
      question: question,
    );
    supportQuestions.value = [next, ...supportQuestions.value];
  }

  static void answerQuestion(String id, String answer) {
    supportQuestions.value = [
      for (final question in supportQuestions.value)
        if (question.id == id) question.copyWith(answer: answer) else question,
    ];
  }
}
