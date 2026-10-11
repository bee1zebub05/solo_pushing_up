import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../rep/pushup_counter.dart';

enum _Cue { rep, crit, partial, reject, ready }

/// Cách báo rep bằng âm thanh.
enum SoundMode {
  /// Đọc số rep bằng giọng tiếng Việt (máy không có giọng Việt thì bíp).
  voice,

  /// Chỉ tiếng bíp.
  beep,

  off,
}

/// Âm thanh + rung cho mỗi rep: người tập không nhìn được màn hình khi
/// đang hít đất, nên phải nghe/cảm nhận được rep có được tính hay không.
class RepFeedback {
  SoundMode soundMode = SoundMode.voice;
  bool vibrationOn = true;

  final Map<_Cue, AudioPool> _pools = {};
  final FlutterTts _tts = FlutterTts();
  bool _voiceReady = false;
  CounterPhase? _lastPhase;

  /// Máy có giọng đọc tiếng Việt hay không.
  bool get voiceAvailable => _voiceReady;

  Future<void> init() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) await _configureIosAudio();
    try {
      if (await _tts.isLanguageAvailable('vi-VN') == true) {
        await _tts.setLanguage('vi-VN');
        await _tts.setSpeechRate(0.6);
        // Rep mới ngắt câu đang đọc dở, để số luôn theo kịp tốc độ tập.
        await _tts.setQueueMode(0);
        _voiceReady = true;
      }
    } on Object catch (error) {
      debugPrint('Không dùng được giọng đọc: $error');
    }
    for (final cue in _Cue.values) {
      try {
        _pools[cue] = await AudioPool.createFromAsset(
          path: 'sounds/${cue.name}.wav',
          maxPlayers: 3,
          playerMode: PlayerMode.lowLatency,
        );
      } on Object catch (error) {
        // Thiếu âm thanh không được làm hỏng việc đếm.
        debugPrint('Không tải được âm ${cue.name}: $error');
      }
    }
  }

  /// iPhone: mặc định âm của app chiếm phiên âm thanh và **tắt nhạc** người
  /// dùng đang nghe khi tập. Đặt chế độ trộn (mixWithOthers) cho cả tiếng
  /// bíp lẫn giọng đọc để nhạc vẫn chạy, vẫn kêu khi gạt công tắc im lặng.
  Future<void> _configureIosAudio() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ], IosTextToSpeechAudioMode.voicePrompt);
    } on Object catch (error) {
      debugPrint('Không đặt được phiên âm thanh iOS: $error');
    }
  }

  /// Gọi với mỗi snapshot của bộ đếm.
  void onSnapshot(CounterSnapshot snapshot) {
    final lastPhase = _lastPhase;
    _lastPhase = snapshot.phase;
    if (lastPhase == CounterPhase.searching &&
        snapshot.phase == CounterPhase.top &&
        snapshot.count == 0) {
      _play(_Cue.ready);
      _vibrate(HapticFeedback.selectionClick);
    }

    for (final event in snapshot.events) {
      switch (event) {
        case CountedRep():
          if (!_speak('${event.index}')) {
            _play(event.isDeep ? _Cue.crit : _Cue.rep);
          } else if (event.isDeep) {
            _play(_Cue.crit);
          }
          _vibrate(
            event.isDeep
                ? HapticFeedback.heavyImpact
                : HapticFeedback.mediumImpact,
          );
        case PartialRep():
          _play(_Cue.partial);
        case RejectedRep(:final reason):
          // Lời nhắc sửa tư thế: nói ra vì người tập không nhìn màn hình.
          final spoken = _speak(switch (reason) {
            RejectReason.kneelingInStandardMode => 'Duỗi thẳng chân',
            RejectReason.bodyNotStraight => 'Giữ thân thẳng',
          });
          if (!spoken) _play(_Cue.reject);
          // iPhone: `vibrate` là rung hệ thống dài ~0,4 s, quá nặng cho một
          // lời nhắc; dùng nhịp rung mạnh ngắn như các thông báo khác.
          _vibrate(
            defaultTargetPlatform == TargetPlatform.iOS
                ? HapticFeedback.heavyImpact
                : HapticFeedback.vibrate,
          );
      }
    }
  }

  void reset() => _lastPhase = null;

  /// Đọc một thông báo của trận (ví dụ đợt sóng mới); không có giọng thì rung.
  void announce(String text) {
    if (!_speak(text)) _vibrate(HapticFeedback.mediumImpact);
  }

  Future<void> dispose() async {
    for (final pool in _pools.values) {
      await pool.dispose();
    }
    _pools.clear();
    await _tts.stop();
  }

  void _play(_Cue cue) {
    if (soundMode == SoundMode.off) return;
    _pools[cue]?.start();
  }

  /// Trả về `false` nếu không đọc được (đang tắt giọng hoặc máy không có).
  bool _speak(String text) {
    if (soundMode != SoundMode.voice || !_voiceReady) return false;
    _tts.speak(text);
    return true;
  }

  void _vibrate(Future<void> Function() pattern) {
    if (!vibrationOn) return;
    pattern();
  }
}
