import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:stage_raster/stage_raster.dart';

import '../art/battle_stage.dart';
import '../art/bosses/fafnir_boss.dart';
import '../art/bosses/nemea_boss.dart';
import '../art/bosses/nemea_monster_art.dart';
import '../art/bosses/orochi_boss.dart';
import '../art/bosses/thuy_tinh_boss.dart';
import '../art/hero_art.dart';
import '../art/hero_pose.dart';

/// Đo hiệu năng trên máy thật (chạy bằng `--profile`):
/// `flutter run --profile -d <máy> -t lib/dev/perf_bench_main.dart`
///
/// 1. Chi phí ghi lệnh vẽ từng sân khấu (như test/art/perf_budget_test.dart).
/// 2. Trận Nemea thật 15 giây (nhân vật hít đất giả lập, đòn đánh định kỳ):
///    thời gian dựng (build/UI) và tô (raster/GPU) từng khung.
/// Kết quả in ra log với tiền tố `BENCH`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _BenchScreen()));
}

void _log(String s) => debugPrint('BENCH $s');

double _measure(void Function(Canvas c, int i) draw, {int n = 120}) {
  for (var i = 0; i < 30; i++) {
    final r = ui.PictureRecorder();
    draw(Canvas(r), i);
    r.endRecording();
  }
  var best = double.infinity;
  for (var run = 0; run < 3; run++) {
    final sw = Stopwatch()..start();
    for (var i = 0; i < n; i++) {
      final r = ui.PictureRecorder();
      draw(Canvas(r), i);
      r.endRecording();
    }
    best = math.min(best, sw.elapsedMicroseconds / n / 1000);
  }
  return best;
}

void _recordStages() {
  for (final (name, art) in <(String, BossArt)>[
    ('nemea', NemeaBossArt()),
    ('thuy_tinh', ThuyTinhBossArt()),
    ('orochi', OrochiBossArt()),
    ('fafnir', FafnirBossArt()),
  ]) {
    final r = ui.PictureRecorder();
    art.paintStageBackdrop(Canvas(r));
    final backdrop = r.endRecording();
    final battle = StageBattleState()..totalHeads = 8;
    final ms = _measure((c, i) {
      battle
        ..bossHp = 1 - (i % 100) / 100
        ..water = (i % 100).toDouble()
        ..headsLeft = 8 - (i ~/ 30) % 8
        ..cold = (i % 30) / 30;
      final frame = BossFrame(
        time: i / 30,
        attack: (i % 20) / 20,
        hurt: (i % 7) / 7,
        glint: -1,
        defeat: 0,
        battle: battle,
      );
      c.drawPicture(backdrop);
      art.paintScene(c, i / 30, battle);
      art.paintBoss(c, frame);
      paintHero(
        c,
        HeroPose.plank(80 + i % 90),
        look: const HeroLook(fat: 0.5),
        cloak: i.isEven,
        effort: (i % 10) / 10,
        time: i / 30,
      );
      art.paintForeground(c, frame);
    });
    _log('record $name ${ms.toStringAsFixed(3)} ms');
  }
  final heroMs = _measure(
    (c, i) => paintHero(
      c,
      HeroPose.plank(80 + i % 90),
      effort: (i % 10) / 10,
      time: i / 30,
    ),
  );
  _log('record hero ${heroMs.toStringAsFixed(3)} ms');
}

class _BenchScreen extends StatefulWidget {
  const _BenchScreen();

  @override
  State<_BenchScreen> createState() => _BenchScreenState();
}

class _BenchScreenState extends State<_BenchScreen>
    with SingleTickerProviderStateMixin {
  BattleStageGame _game = BattleStageGame(boss: NemeaBossArt(), cloak: true);
  final _timings = <FrameTiming>[];
  late final Ticker _ticker = createTicker(_tick);
  double _t = 0;
  int _lastHit = 0;
  String _status = 'Đang đo ghi lệnh vẽ…';

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 500), () async {
      _recordStages();
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _ticker.start();
      // Đo cấu hình đầy đủ ở cả hai hướng máy: ảnh chụp sẵn phụ thuộc độ
      // phân giải màn hình nên bộ nhớ/thời gian tô khác hẳn khi nằm ngang.
      // Mốc `BENCH phase <tên>` báo cho tool/bench_device.sh đo bộ nhớ.
      // Nemea đo cả hai hướng máy (ảnh chụp sẵn phụ thuộc độ phân giải);
      // các boss khác đo dọc. Mốc `BENCH phase <tên>` báo cho
      // tool/bench_device.sh đo bộ nhớ.
      for (final (name, orientation, boss)
          in <(String, DeviceOrientation, BossArt?)>[
            ('full', DeviceOrientation.portraitUp, null),
            ('full-landscape', DeviceOrientation.landscapeLeft, null),
            ('orochi', DeviceOrientation.portraitUp, OrochiBossArt()),
            ('fafnir', DeviceOrientation.portraitUp, FafnirBossArt()),
            ('thuy_tinh', DeviceOrientation.portraitUp, ThuyTinhBossArt()),
            (
              'swarm',
              DeviceOrientation.portraitUp,
              NemeaMonsterArt(NemeaMonster.swarm),
            ),
            (
              'hydra',
              DeviceOrientation.portraitUp,
              NemeaMonsterArt(NemeaMonster.hydra),
            ),
            (
              'harpy',
              DeviceOrientation.portraitUp,
              NemeaMonsterArt(NemeaMonster.harpy),
            ),
            (
              'boar',
              DeviceOrientation.portraitUp,
              NemeaMonsterArt(NemeaMonster.boar),
            ),
            (
              'spartoi',
              DeviceOrientation.portraitUp,
              NemeaMonsterArt(NemeaMonster.spartoi),
            ),
            (
              'stone',
              DeviceOrientation.portraitUp,
              NemeaMonsterArt(NemeaMonster.stone),
            ),
            (
              'pack',
              DeviceOrientation.portraitUp,
              NemeaMonsterArt(NemeaMonster.pack),
            ),
          ]) {
        await SystemChrome.setPreferredOrientations([orientation]);
        if (boss != null) {
          setState(() => _game = BattleStageGame(boss: boss, cloak: true));
        }
        setState(() => _status = 'Đo cấu hình $name…');
        await Future<void>.delayed(const Duration(seconds: 2));
        _timings.clear();
        _log('phase $name');
        await Future<void>.delayed(const Duration(seconds: 6));
        _report(name);
      }
      _ticker.stop();
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      setState(() => _status = 'Xong — xem log BENCH');
    });
  }

  void _onTimings(List<FrameTiming> t) => _timings.addAll(t);

  void _tick(Duration e) {
    _t = e.inMicroseconds / 1e6;
    // Hít đất giả lập: chu kỳ 1,6 s, góc khuỷu 70–175°.
    final angle = 122 + 52 * math.cos(_t * 2 * math.pi / 1.6);
    _game.updatePlayer(elbowAngle: angle);
    _game.battle.bossHp = 0.7;
    final rep = (_t / 1.6).floor();
    if (rep > _lastHit) {
      _lastHit = rep;
      rep % 4 == 0 ? _game.blocked() : _game.hit(critical: rep % 3 == 0);
    }
  }

  void _report(String name) {
    if (_timings.isEmpty) {
      _log('[$name] frames 0');
      return;
    }
    List<double> ms(Duration Function(FrameTiming) f) =>
        [for (final t in _timings) f(t).inMicroseconds / 1000]..sort();
    String stats(List<double> v) {
      double p(double q) => v[math.min(v.length - 1, (v.length * q).floor())];
      final avg = v.reduce((a, b) => a + b) / v.length;
      return 'avg ${avg.toStringAsFixed(2)} p50 ${p(0.5).toStringAsFixed(2)} '
          'p90 ${p(0.9).toStringAsFixed(2)} p99 ${p(0.99).toStringAsFixed(2)} '
          'max ${v.last.toStringAsFixed(2)}';
    }

    final build = ms((t) => t.buildDuration);
    final raster = ms((t) => t.rasterDuration);
    final total = ms((t) => t.totalSpan);
    final janky = total.where((v) => v > 16.7).length;
    _log(
      '[$name] frames ${_timings.length} (~${(_timings.length / 6).toStringAsFixed(1)} fps) '
      '>16.7ms: $janky',
    );
    _log('[$name] build  ${stats(build)} ms');
    _log('[$name] raster ${stats(raster)} ms');
    final cache = RasterBudget.shared;
    _log(
      '[$name] raster-cache ${(cache.bytes / 1048576).toStringAsFixed(1)} MB '
      'in ${cache.liveCount} images, hero renders $debugHeroImageRenders, '
      'scale '
      '${cache.effectiveScale.toStringAsFixed(2)}',
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    // Bố cục giống màn trận thật: dọc thì sân khấu trên, camera dưới; ngang
    // thì sân khấu chiếm 3/5 bên trái (lib/ui/battle_screen.dart).
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final stage = AspectRatio(
            aspectRatio: 400 / 260,
            child: GameWidget(key: ObjectKey(_game), game: _game),
          );
          final status = Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_status, style: const TextStyle(color: Colors.white)),
          );
          if (box.maxWidth > box.maxHeight) {
            return Row(
              children: [
                Expanded(flex: 3, child: Center(child: stage)),
                Expanded(flex: 2, child: Center(child: status)),
              ],
            );
          }
          return Column(
            children: [
              stage,
              Expanded(child: Center(child: status)),
            ],
          );
        },
      ),
    ),
  );
}
