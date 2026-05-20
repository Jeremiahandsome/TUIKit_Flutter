import 'dart:io';
import 'dart:ui' as ui;

import 'package:atomic_x_core/atomicxcore.dart';
import 'package:flutter/material.dart';

import 'package:tuikit_atomic_x/album_picker/album_picker.dart';

abstract class AlbumPickerMediaSendListener {
  void onSendMessage(MessageInfo messageInfo);
  void onSendPlaceholderMessage(MessageInfo placeholder);
  void onRemovePlaceholderMessage(MessageInfo placeholder);
}

class AlbumPickerMediaSendManager {
  static final AlbumPickerMediaSendManager shared = AlbumPickerMediaSendManager._();
  AlbumPickerMediaSendManager._();

  final Map<String, _PickerSession> _pickerSessions = {};

  Future<void> pickAlbumMedia({
    required String conversationID,
    required AlbumPickerMediaSendListener listener,
    AlbumPickerConfig? config,
    AlbumPickerTheme? theme,
  }) async {
    final sessionKey = '${DateTime.now().millisecondsSinceEpoch}_${conversationID.hashCode}';
    final session = _PickerSession(
      sessionKey: sessionKey,
      conversationID: conversationID,
      listener: listener,
    );
    _pickerSessions[sessionKey] = session;

    debugPrint("[MediaSendManager] pickAlbumMedia: session=$sessionKey, conversationID=$conversationID");

    await AlbumPicker.pickMedia(
      config: config,
      theme: theme,
      onPickConfirm: (pickedAlbumMedias, textMessage) {
        debugPrint("[MediaSendManager] onPickConfirm: ${pickedAlbumMedias.length} items, session=$sessionKey");
      },
      onMediaProcessing: (albumMedia, progress, error) {
        _handleMediaProcessing(media: albumMedia, progress: progress, error: error, session: session);
      },
      onMediaProcessed: () {
        debugPrint("[MediaSendManager] onMediaProcessed: session=$sessionKey");
        _pickerSessions.remove(sessionKey);
      },
      onCancel: () {
        debugPrint("[MediaSendManager] onCancel: session=$sessionKey");
        _pickerSessions.remove(sessionKey);
      },
    );
  }

  void restorePlaceholders({
    required String conversationID,
    required AlbumPickerMediaSendListener listener,
  }) {
    for (final session in _pickerSessions.values) {
      if (session.conversationID != conversationID) continue;
      session.listener = listener;

      for (final state in session.mediaStates.values) {
        if (state.progress >= 1.0 || state.thumbnailPath == null) continue;
        state.placeholder = null;
        state.placeholderCreating = false;

        final placeholder = _createPlaceholderMessage(state.thumbnailPath!);
        placeholder.progress = (state.progress * 100).toInt();
        state.placeholder = placeholder;
        listener.onSendPlaceholderMessage(placeholder);
      }
    }
  }

  void _handleMediaProcessing({
    required AlbumMedia media,
    required double progress,
    required bool error,
    required _PickerSession session,
  }) {
    if (error) return;

    switch (media.mediaType) {
      case AlbumMediaType.image:
        _handleImageProcessing(media: media, progress: progress, session: session);
        break;
      case AlbumMediaType.video:
        _handleVideoProcessing(media: media, progress: progress, session: session);
        break;
    }
  }

  void _handleImageProcessing({
    required AlbumMedia media,
    required double progress,
    required _PickerSession session,
  }) {
    if (progress < 1.0 || media.mediaPath.isEmpty) return;

    final messageInfo = MessageInfo();
    messageInfo.messageType = MessageType.image;
    final body = MessageBody();
    body.originalImagePath = media.mediaPath;
    messageInfo.messageBody = body;

    session.listener.onSendMessage(messageInfo);
    session.mediaStates.remove(media.id);
  }

  void _handleVideoProcessing({
    required AlbumMedia media,
    required double progress,
    required _PickerSession session,
  }) {
    final state = session.mediaStates[media.id] ?? _MediaState();
    state.progress = progress;
    session.mediaStates[media.id] = state;

    _createPlaceholderIfNeeded(media: media, state: state, session: session);

    if (state.placeholder != null && progress < 1.0) {
      state.placeholder!.progress = (progress * 100).toInt();
    }

    if (progress >= 1.0 && media.mediaPath.isNotEmpty) {
      _sendVideo(media: media, state: state, session: session);
    }
  }

  void _createPlaceholderIfNeeded({
    required AlbumMedia media,
    required _MediaState state,
    required _PickerSession session,
  }) {
    if (state.placeholder != null || state.placeholderCreating) return;
    final thumbnailPath = media.videoThumbnailPath;
    if (thumbnailPath == null || thumbnailPath.isEmpty) return;

    state.placeholderCreating = true;
    state.thumbnailPath = thumbnailPath;

    final placeholder = _createPlaceholderMessage(thumbnailPath);
    placeholder.progress = (state.progress * 100).toInt();
    state.placeholder = placeholder;
    session.listener.onSendPlaceholderMessage(placeholder);
  }

  MessageInfo _createPlaceholderMessage(String thumbnailPath) {
    final placeholder = MessageInfo();
    placeholder.msgID = 'placeholder_${DateTime.now().millisecondsSinceEpoch}_${thumbnailPath.hashCode}';
    placeholder.messageType = MessageType.video;
    placeholder.status = MessageStatus.sending;
    placeholder.isSelf = true;
    placeholder.timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final userInfo = LoginStore.shared.loginState.loginUserInfo;
    if (userInfo != null) {
      placeholder.sender = MessageSenderInfo()
        ..userID = userInfo.userID
        ..avatarURL = userInfo.avatarURL
        ..nickname = userInfo.nickname;
    }

    final body = MessageBody();
    body.videoSnapshotPath = thumbnailPath;
    placeholder.messageBody = body;

    return placeholder;
  }

  void _sendVideo({
    required AlbumMedia media,
    required _MediaState state,
    required _PickerSession session,
  }) async {
    final placeholderToRemove = state.placeholder;
    if (placeholderToRemove != null) {
      placeholderToRemove.progress = 100;
      session.listener.onRemovePlaceholderMessage(placeholderToRemove);
    }

    String snapshotPath = media.videoThumbnailPath ?? '';
    if (snapshotPath.isEmpty) {
      snapshotPath = await _generateBlackSnapshot();
    }

    final messageInfo = MessageInfo();
    messageInfo.messageType = MessageType.video;
    final body = MessageBody();
    body.videoPath = media.mediaPath;
    body.videoSnapshotPath = snapshotPath;
    body.videoDuration = (media.duration / 1000).round();
    body.videoType = media.mediaPath.split('.').last;
    messageInfo.messageBody = body;

    session.listener.onSendMessage(messageInfo);
    session.mediaStates.remove(media.id);
  }

  String? _cachedBlackSnapshotPath;

  Future<String> _generateBlackSnapshot() async {
    if (_cachedBlackSnapshotPath != null && File(_cachedBlackSnapshotPath!).existsSync()) {
      return _cachedBlackSnapshotPath!;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 320, 240),
      Paint()..color = Colors.black,
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(320, 240);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return '';
    final bytes = byteData.buffer.asUint8List();
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/album_picker_black_snapshot.png');
    await file.writeAsBytes(bytes);
    _cachedBlackSnapshotPath = file.path;
    return file.path;
  }
}

class _PickerSession {
  final String sessionKey;
  final String conversationID;
  AlbumPickerMediaSendListener listener;
  final Map<int, _MediaState> mediaStates = {};

  _PickerSession({
    required this.sessionKey,
    required this.conversationID,
    required this.listener,
  });
}

class _MediaState {
  MessageInfo? placeholder;
  bool placeholderCreating = false;
  String? thumbnailPath;
  double progress = 0;
}
