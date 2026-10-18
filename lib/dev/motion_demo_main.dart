import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../art/battle_stage.dart';
import '../art/bosses/fafnir_boss.dart';
import '../art/bosses/nemea_boss.dart';
import '../art/bosses/orochi_boss.dart';
import '../art/bosses/thuy_tinh_boss.dart';
import '../art/nemea_scene.dart' show stageSize;
import '../feedback/rep_feedback.dart';

/// Màn demo có kịch bản để quay video báo cáo đồ hoạ trên máy thật:
/// `bash tool/record_motion_demo.sh` (build profile, quay màn hình, trộn âm).
///
/// Mỗi boss diễn [_length] giây: mở màn → boss lấy đà/ra đòn → người chơi
/// hít đất trúng đòn → pha cuối (máu < 40%) → boss ra đòn lần hai → gục.
/// Mọi tín hiệu âm thanh in ra log `DEMO cue <tên> <epoch ms>` để trộn đúng
/// file WAV của game vào video (máy Android 13 không ghi được tiếng).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: _DemoScreen()),
  );
}

void _log(String s) =>
    debugPrint('DEMO $s ${DateTime.now().millisecondsSinceEpoch}');

const _length = 17.0;

/// Chờ trước khi diễn (màn đen) để máy quay kịp chạy và để căn tiếng.
const _lead = 4.0;

class _Act {
  const _Act(this.key, this.title, this.make);
  final String key;
  final String title;
  final BossArt Function() make;
}

final _acts = [
  _Act('nemea', 'Sư tử Nemea', NemeaBossArt.new),
  _Act('orochi', 'Yamata no Orochi', OrochiBossArt.new),
  _Act('fafnir', 'Rồng Fafnir', FafnirBossArt.new),
  _Act('thuy_tinh', 'Thuỷ Tinh', ThuyTinhBossArt.new),
];

class _DemoScreen extends StatefulWidget {
  const _DemoScreen();

  @override
  State<_DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<_DemoScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  BattleStageGame? _game;
  int _act = -1;
  double _actStart = 0;
  double _t = 0;
  String _caption = '';
  int _lastRep = -1;
  bool _raged = false;
  bool _attacked = false;
  bool _won = false;

  /// Âm thanh phát qua đúng đường của game (RepFeedback + tiếng rep), để
  /// scrcpy ghi được tiếng thật.
  final _feedback = RepFeedback()..soundMode = SoundMode.beep;
  final _repSounds = <String, AudioPool>{};

  @override
  void initState() {
    super.initState();
    _loadSounds().then((_) => _ticker.start());
  }

  Future<void> _loadSounds() async {
    await _feedback.init();
    for (final act in _acts) {
      await _feedback.loadBossSounds(act.key);
    }
    for (final name in ['rep', 'crit']) {
      _repSounds[name] = await AudioPool.createFromAsset(
        path: 'sounds/$name.wav',
        maxPlayers: 2,
        playerMode: PlayerMode.lowLatency,
      );
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _startAct(int i) {
    final act = _acts[i];
    final game = BattleStageGame(boss: act.make(), cloak: true, sword: true)
      ..onCue = (cue) {
        _log('cue ${act.key}_${cue.name}');
        // Cùng cách chọn tiếng như màn trận (lib/ui/battle_screen.dart).
        _feedback.playBoss(act.key, switch (cue) {
          StageCue.hit => 'hit',
          StageCue.defeat => 'defeat',
          StageCue.tellAlt => 'tell2',
          StageCue.tell || StageCue.rage => 'tell',
        });
      };
    setState(() {
      _act = i;
      _game = game;
      _lastRep = -1;
      _raged = false;
      _attacked = false;
      _won = false;
    });
    _log('act ${act.key}');
  }

  void _tick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    if (now < _lead) return;
    final want = ((now - _lead) / _length).floor();
    if (want >= _acts.length) {
      if (_game != null) {
        _log('end');
        setState(() => _game = null);
      }
      return;
    }
    if (want != _act) {
      _actStart = _lead + want * _length;
      _startAct(want);
    }
    final game = _game;
    if (game == null) return;
    _t = now - _actStart;
    _script(game);
  }

  /// Kịch bản một boss theo giây [_t] tính từ lúc vào trận.
  void _script(BattleStageGame game) {
    final t = _t;
    final key = _acts[_act].key;
    // Hít đất giả lập từ giây 0,8: chu kỳ 1,6 s, đáy ở giữa chu kỳ.
    if (t > 0.8 && !_won) {
      final p = (t - 0.8) / 1.6;
      game.updatePlayer(elbowAngle: 122 + 52 * math.cos(p * 2 * math.pi));
      final rep = (p - 0.5).floor();
      // Rep tính khi rời đáy; đòn đầu từ giây ~3 (sau đòn đầu của boss).
      if (rep > _lastRep && t > 3) {
        _lastRep = rep;
        final critical = rep % 3 == 2;
        _log('cue ${critical ? 'crit' : 'rep'}');
        _repSounds[critical ? 'crit' : 'rep']?.start(volume: 0.55);
        game.hit(critical: critical);
        final b = game.battle;
        b.bossHp = math.max(0.05, b.bossHp - (_raged ? 0.08 : 0.12));
        if (key == 'orochi') {
          b
            ..totalHeads = 8
            ..headsLeft = math.max(1, (b.bossHp * 8).ceil());
        }
      }
    }
    final b = game.battle;
    if (key == 'thuy_tinh') b.water = (30 + t * 3.5).clamp(0, 75);
    if (key == 'fafnir') b.cold = t < 3 ? (t / 3) * 0.7 : 0;
    // Pha cuối: ép máu xuống dưới 40% ở giây 8,6.
    if (t > 8.6 && !_raged) {
      _raged = true;
      b.bossHp = math.min(b.bossHp, 0.36);
    }
    if (t > 10 && !_attacked) {
      _attacked = true;
      game.triggerAttack();
    }
    if (t > 13.6 && !_won) {
      _won = true;
      game.updatePlayer();
      game.victory();
    }
    final caption = switch (t) {
      < 1.4 => 'Mở màn: vòng sáng mở · sương Trì Trệ sát đất',
      < 2.1 => 'Boss lấy đà (≥ 0,6 s) · tiếng báo đòn',
      < 3.0 => 'Ra đòn · nhân vật giật lùi (lò xo)',
      < 8.6 => 'Hít đất = đòn đánh · ánh sáng động · boss nảy · sương tan dần',
      < 10 => 'Pha cuối (máu < 40%): gầm, rung, loé đỏ, viền nhịp tim',
      < 13.6 => 'Boss ra đòn lần hai trong pha cuối',
      _ => 'Gục: khói Trì Trệ rời xác · sương tan hết · tiếng gục',
    };
    if (caption != _caption) setState(() => _caption = caption);
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return Scaffold(
      backgroundColor: Colors.black,
      body: game == null
          ? const SizedBox.expand()
          : Column(
              children: [
                AspectRatio(
                  aspectRatio: stageSize.width / stageSize.height,
                  child: GameWidget(key: ValueKey(_act), game: game),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _acts[_act].title,
                          style: const TextStyle(
                            color: Color(0xFFE8C46A),
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _caption,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
