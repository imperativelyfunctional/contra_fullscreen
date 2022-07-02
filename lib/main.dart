import 'dart:async';

import 'package:contra/constructions/bridge.dart';
import 'package:contra/events/event.dart';
import 'package:contra/player/player.dart';
import 'package:contra/player/player_states.dart';
import 'package:contra/wall/wall.dart';
import 'package:event/event.dart';
import 'package:flame/components.dart' hide Timer;
import 'package:flame/effects.dart';
import 'package:flame/flame.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tiled/tiled.dart' show ObjectGroup;

const worldWidth = 3327.0;
const worldHeight = 240.0;
const ogViewPortHeight = 240.0;
const ogViewPortWidth = 256.0;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Flame.device.setLandscape();
  await Flame.device.fullScreen();
  var contra = Contra();
  runApp(GameWidget(game: contra));
}

final keyEvents = Event<KeyEventArgs>();
final touchWaterEvents = Event<TouchWallArgs>();
final touchWallEvents = Event<TouchWallArgs>();
final inAirEvents = Event<InAirArgs>();
final spawnEvents = Event();

class Contra extends FlameGame with KeyboardEvents, HasCollisionDetection {
  late Timer cameraTimer;
  late Lance player;
  late PlayerInfoArgs playerInfoArgs;
  late double viewPortWidth;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    viewPortWidth = size.x * ogViewPortWidth / size.y;
    camera.viewport =
        FixedResolutionViewport(Vector2(viewPortWidth, ogViewPortHeight));
    var map = await TiledComponent.load('map.tmx', Vector2.all(16));
    add(map);
    for (var object
        in map.tileMap.getLayer<ObjectGroup>('collisions')!.objects) {
      add(Wall(WallType.fromString(object.type),
          position: Vector2(object.x, object.y),
          size: Vector2(object.width, object.height)));
    }
    add(Bridge()
      ..position = Vector2(768, 113)
      ..size = Vector2(32 * 4, 32 * 4));
    add(Bridge()
      ..position = Vector2(1024, 113)
      ..size = Vector2(32 * 4, 32 * 4));
    player = Lance(
      'player.png',
      position: Vector2(30, 0),
      size: Vector2(41, 42),
    );
    await add(player);

    Sprite life = await loadSprite('life.png', srcSize: Vector2(8, 16));
    add(SpriteComponent(sprite: life, position: Vector2(20, 0))
      ..positionType = PositionType.viewport);
    add(SpriteComponent(sprite: life, position: Vector2(35, 0))
      ..positionType = PositionType.viewport);
    add(SpriteComponent(sprite: life, position: Vector2(50, 0))
      ..positionType = PositionType.viewport);
    add(SpriteComponent(sprite: life, position: Vector2(65, 0))
      ..positionType = PositionType.viewport);

    Sprite logo =
        await loadSprite('contra_logo.png', srcSize: Vector2(191, 79));

    add(SpriteComponent(
        sprite: logo,
        anchor: Anchor.topCenter,
        position: Vector2(viewPortWidth / 2, 0),
        size: Vector2(191, 79) / 4)
      ..positionType = PositionType.viewport);
    add(ScreenHitbox());
    spawnEvents.subscribe((args) {
      player = Lance(
        'player.png',
        position: Vector2(camera.position.x + 30, 0),
        size: Vector2(41, 42),
      );
      add(player);
    });

    // update playerinfo to main
    playerInfoEvents.subscribe((args) {
      playerInfoArgs = args!;
    });
  }

  void moveComponentAlongPath(
      PositionComponent component, int numberOfSegment, Vector2 destination) {
    var position = component.position;
    var segmentLength = (destination.x - position.x) / numberOfSegment;
    var path = Path();
    var endPosition = position.y;
    var handlePointLength = segmentLength / 3;
    for (int i = 0; i < numberOfSegment; i++) {
      double dy = 20;
      if (i % 2 == 1) {
        dy = -20;
      }
      path.cubicTo(
          endPosition + handlePointLength,
          dy,
          endPosition + 2 * handlePointLength,
          dy,
          endPosition + segmentLength,
          0);
      endPosition += segmentLength;
    }
    component.add(MoveAlongPathEffect(
        path, EffectController(infinite: false, duration: 6)));
  }

  @override
  void update(double dt) {
    super.update(dt);
    var cameraXPos = camera.position.x;
    if (cameraXPos < worldWidth - viewPortWidth) {
      camera.followComponent(player,
          worldBounds: Rect.fromLTWH(
              cameraXPos, 0, worldWidth - cameraXPos, worldHeight));
    }
  }

  @override
  KeyEventResult onKeyEvent(
    RawKeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    {
      if (keysPressed.isNotEmpty) {
        for (var element in keysPressed) {
          keyEvents.broadcast(KeyEventArgs(element, true));
        }
      }

      if (event is RawKeyUpEvent) {
        keyEvents.broadcast(KeyEventArgs(event.logicalKey, false));
        if (event.logicalKey == LogicalKeyboardKey.keyJ) {}
      }
      return super.onKeyEvent(event, keysPressed);
    }
  }
}

Vector2 _fireVelocity(PlayerStates playerStates, double positiveSpeed) {
  switch (playerStates) {
    case PlayerStates.waterLeftIdle:
      return Vector2(-positiveSpeed, 0);
    case PlayerStates.waterRightIdle:
      return Vector2(positiveSpeed, 0);
    case PlayerStates.waterLeftShoot:
      return Vector2(-positiveSpeed, 0);
    case PlayerStates.waterRightShoot:
      return Vector2(positiveSpeed, 0);
    case PlayerStates.waterLeftStraightUp:
      return Vector2(0, -positiveSpeed);
    case PlayerStates.waterRightStraightUp:
      return Vector2(0, -positiveSpeed);
    case PlayerStates.waterLeftUp:
      return Vector2(-positiveSpeed, -positiveSpeed);
    case PlayerStates.waterRightUp:
      return Vector2(positiveSpeed, -positiveSpeed);
    case PlayerStates.leftRunShoot:
      return Vector2(-positiveSpeed, 0);
    case PlayerStates.rightRunShoot:
      return Vector2(positiveSpeed, 0);
    case PlayerStates.leftUp:
      return Vector2(-positiveSpeed, -positiveSpeed);
    case PlayerStates.rightUp:
      return Vector2(positiveSpeed, -positiveSpeed);
    case PlayerStates.leftUpJump:
      return Vector2(-positiveSpeed, -positiveSpeed);
    case PlayerStates.rightUpJump:
      return Vector2(positiveSpeed, -positiveSpeed);
    case PlayerStates.leftDownJump:
      return Vector2(-positiveSpeed, positiveSpeed);
    case PlayerStates.rightDownJump:
      return Vector2(positiveSpeed, positiveSpeed);
    case PlayerStates.leftStraightUpJump:
      return Vector2(0, -positiveSpeed);
    case PlayerStates.rightStraightUpJump:
      return Vector2(0, -positiveSpeed);
    case PlayerStates.leftStraightUpJumpNoKey:
      return Vector2(-positiveSpeed, 0);
    case PlayerStates.rightStraightUpJumpNoKey:
      return Vector2(positiveSpeed, 0);
    case PlayerStates.leftJump:
      return Vector2(-positiveSpeed, 0);
    case PlayerStates.rightJump:
      return Vector2(positiveSpeed, 0);
    case PlayerStates.leftStraightUp:
      return Vector2(0, -positiveSpeed);
    case PlayerStates.rightStraightUp:
      return Vector2(0, -positiveSpeed);
    case PlayerStates.leftStraightDown:
      return Vector2(-positiveSpeed, 0);
    case PlayerStates.rightStraightDown:
      return Vector2(positiveSpeed, 0);
    case PlayerStates.leftStraightDownJump:
      return Vector2(0, positiveSpeed);
    case PlayerStates.rightStraightDownJump:
      return Vector2(0, positiveSpeed);
    case PlayerStates.leftDown:
      return Vector2(-positiveSpeed, positiveSpeed);
    case PlayerStates.rightDown:
      return Vector2(positiveSpeed, positiveSpeed);
    case PlayerStates.leftIdle:
      return Vector2(-positiveSpeed, 0);
    case PlayerStates.rightIdle:
      return Vector2(positiveSpeed, 0);
    default:
      return Vector2.zero();
  }
}
