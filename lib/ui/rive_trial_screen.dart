import 'dart:ui' show Picture, PictureRecorder;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_rive/flame_rive.dart' hide Component;
import 'package:flutter/material.dart' hide Image;

import '../art/bosses/nemea_boss.dart';
import '../art/battle_stage.dart';
import '../art/nemea_scene.dart';
import '../art/vector_style.dart';

/// BẢN THỬ Rive: nhân vật hoạt hình bằng xương (file .riv mẫu chính thức của
/// Rive — nhân mã, giấy phép MIT) đứng trên sân khấu Nemea vẽ bằng code.
/// Chạm để bắn cung, kéo ngang để chạy. Chỉ để đánh giá quy trình Rive.
class RiveTrialScreen extends StatelessWidget {
  const RiveTrialScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thử Rive (nhân mã mẫu)')),
    backgroundColor: const Color(0xFF1C1612),
    body: Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: stageSize.width / stageSize.height,
              child: GameWidget(game: _RiveTrialGame()),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Chạm: bắn cung · Kéo ngang: chạy.\n'
            'Nhân mã là file .riv mẫu của Rive; phông, sư tử vẽ bằng code.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    ),
  );
}

class _RiveTrialGame extends FlameGame with TapCallbacks, DragCallbacks {
  _RiveTrialGame()
    : super(
        camera: CameraComponent.withFixedResolution(
          width: stageSize.width,
          height: stageSize.height,
        ),
      );

  final _art = NemeaBossArt();
  final _battle = StageBattleState()..bossHp = 0.05;
  StateMachine? _machine;
  TriggerInput? _fire;
  NumberInput? _move;
  double _moveValue = 0;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.add(_Backdrop(_art, _battle));
    world.add(_Lion(_art, _battle));

    final file = await File.asset(
      'assets/rive/centaur_v2.riv',
      riveFactory: Factory.flutter,
    );
    if (file == null) return;
    final artboard = await loadArtboard(file, artboardName: 'Character');
    _machine = artboard.defaultStateMachine();
    // ignore: deprecated_member_use
    _fire = _machine?.trigger('Fire');
    // ignore: deprecated_member_use
    _move = _machine?.number('Move');
    world.add(
      RiveComponent(
        artboard: artboard,
        stateMachine: _machine,
        // Nhân mã đứng trên mặt đất bên trái, cỡ ngang tầm nhân vật.
        size: Vector2(150, 150),
        position: Vector2(40, stageGroundY - 140),
      ),
    );
  }

  @override
  void onTapDown(TapDownEvent event) => _fire?.fire();

  @override
  void onDragUpdate(DragUpdateEvent event) {
    _moveValue = (_moveValue + event.localDelta.x / 80).clamp(-1.0, 1.0);
    _move?.value = _moveValue;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _moveValue = 0;
    _move?.value = 0;
  }

  @override
  void render(Canvas canvas) {
    canvas.saveLayer(
      null,
      Paint()..colorFilter = saturationFilter(BattleStageGame.saturation),
    );
    super.render(canvas);
    canvas.restore();
  }
}

class _Backdrop extends Component {
  _Backdrop(this.art, this.battle);

  final NemeaBossArt art;
  final StageBattleState battle;
  double _time = 0;
  late final Picture _sky = () {
    final r = PictureRecorder();
    art.paintStageBackdrop(Canvas(r));
    return r.endRecording();
  }();

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    canvas.drawPicture(_sky);
    art.paintScene(canvas, _time, battle);
  }
}

class _Lion extends Component {
  _Lion(this.art, this.battle);

  final NemeaBossArt art;
  final StageBattleState battle;
  double _time = 0;

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) => art.paintBoss(
    canvas,
    BossFrame(
      time: _time,
      attack: 0,
      hurt: 0,
      glint: -1,
      defeat: 0,
      battle: battle,
    ),
  );
}
