import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/tower.dart';
import '../../domain/entities/player.dart';
import 'tower_component.dart';

/// A lightweight Flame game that renders exactly ONE tower.
/// We use this inside a Flutter ListView.builder to let Flutter handle 
/// the scroll gestures natively (BouncingScrollPhysics), 
/// while strictly adhering to the "Flame Engine for rendering" requirement.
class SingleTowerGame extends FlameGame {
  final Map<String, Player> players;
  final String towerId;
  Tower tower;
  final int index;
  final int targetValue;
  final bool isTargetTower;
  bool isCarOnTop;
  final Function(String) onTowerTapped;

  SingleTowerGame({
    required this.players,
    required this.towerId,
    required this.tower,
    required this.index,
    required this.targetValue,
    required this.isTargetTower,
    required this.isCarOnTop,
    required this.onTowerTapped,
  });

  late TowerComponent component;
  bool _isComponentLoaded = false;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    component = TowerComponent(
      players: players,
      towerId: towerId,
      initialState: tower,
      index: index,
      getGameSize: () => size,
      getTargetValue: () => targetValue,
      isTargetTower: isTargetTower,
      isCarOnTop: isCarOnTop,
      onTowerTapped: onTowerTapped,
    );
    add(component);
    _isComponentLoaded = true;
  }

  void updateTower(Tower newTower, bool newIsCarOnTop) {
    tower = newTower;
    isCarOnTop = newIsCarOnTop;
    if (_isComponentLoaded) {
      component.updateState(newTower, index, newIsCarOnTop);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_isComponentLoaded) {
      component.recalculateLayout();
    }
  }
}
