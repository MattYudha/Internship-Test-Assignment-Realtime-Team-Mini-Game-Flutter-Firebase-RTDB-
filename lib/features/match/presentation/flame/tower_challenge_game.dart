import 'dart:async';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flame/camera.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/tower.dart';
import 'tower_component.dart';

class TowerChallengeGame extends FlameGame {
  final Map<String, TowerComponent> _towerCache = {};
  
  late World worldA;
  late World worldB;
  
  late CameraComponent cameraA;
  late CameraComponent cameraB;
  
  // Callbacks to UI
  final Function(String, String) onTowerTapped; // (teamId, towerId)

  double _latestMaxX_A = 0;
  double _latestMaxX_B = 0;

  TowerChallengeGame({required this.onTowerTapped});

  @override
  Color backgroundColor() => const Color(0xFF1E1E1E);

  @override
  Future<void> onLoad() async {

    worldA = World();
    worldB = World();
    
    add(worldA);
    add(worldB);

    final halfHeight = size.y / 2;

    cameraA = CameraComponent(
      world: worldA,
      viewport: FixedSizeViewport(size.x, halfHeight)..position = Vector2(0, 0),
    );
    cameraA.viewfinder.anchor = Anchor.topLeft;
    
    cameraB = CameraComponent(
      world: worldB,
      viewport: FixedSizeViewport(size.x, halfHeight)..position = Vector2(0, halfHeight),
    );
    cameraB.viewfinder.anchor = Anchor.topLeft;

    add(cameraA);
    add(cameraB);
    
    // Render dividing line using a simple background component on UI layer
    add(
      RectangleComponent(
        position: Vector2(0, halfHeight - 2),
        size: Vector2(size.x, 4),
        paint: Paint()..color = Colors.white24,
      )
    );
  }

  void syncTowers(String teamId, List<Tower> remoteTowers) {
    final world = teamId == 'teamA' ? worldA : worldB;
    final camera = teamId == 'teamA' ? cameraA : cameraB;

    double currentMaxX = 0;

    for (int i = 0; i < remoteTowers.length; i++) {
      final tower = remoteTowers[i];
      final key = '${teamId}_${tower.id}';
      
      // Calculate layout: horizontal scroll, 60px size, 20px gap, margins
      double posX = 30.0 + (i * (60.0 + 20.0));
      double posY = (size.y / 4) - 30.0; // center vertically within its half viewport
      currentMaxX = posX;

      if (_towerCache.containsKey(key)) {
        // O(1) Update
        _towerCache[key]!.updateState(tower);
      } else {
        // Spawn newly generated tower
        final component = TowerComponent(
          towerId: tower.id,
          initialState: tower,
          position: Vector2(posX, posY),
          size: Vector2(60, 60),
          onTowerTapped: (tId) => onTowerTapped(teamId, tId),
        );
        _towerCache[key] = component;
        world.add(component);
      }
    }

    // Prof's Rule #3: Spatial Blindness Fix
    // If the tower grid expanded, pan the camera smoothly to show the new tower.
    if (teamId == 'teamA' && currentMaxX > _latestMaxX_A) {
       _latestMaxX_A = currentMaxX;
       _panCameraToCover(cameraA, currentMaxX);
    } else if (teamId == 'teamB' && currentMaxX > _latestMaxX_B) {
       _latestMaxX_B = currentMaxX;
       _panCameraToCover(cameraB, currentMaxX);
    }
  }

  void _panCameraToCover(CameraComponent camera, double targetMaxX) {
    // If target is beyond screen boundaries, move camera right bounds
    final screenRightEdge = camera.viewfinder.position.x + size.x;
    // adding padding of 150px
    if (targetMaxX + 150 > screenRightEdge) {
       final panDistance = (targetMaxX + 150) - size.x;
       // Smooth movement
       camera.viewfinder.add(
         MoveToEffect(
           Vector2(panDistance, 0),
           EffectController(duration: 0.8, curve: Curves.easeInOut),
         )
       );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) {
      final halfHeight = size.y / 2;
      (cameraA.viewport as FixedSizeViewport).size = Vector2(size.x, halfHeight);
      
      final viewportB = cameraB.viewport as FixedSizeViewport;
      viewportB.size = Vector2(size.x, halfHeight);
      viewportB.position = Vector2(0, halfHeight);
    }
  }
}
