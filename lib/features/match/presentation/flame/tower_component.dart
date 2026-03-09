import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/tower.dart';

class TowerComponent extends PositionComponent with TapCallbacks {
  final String towerId;
  final Function(String) onTowerTapped;
  Tower _state;

  late TextComponent _valueText;
  late RectangleComponent _background;

  TowerComponent({
    required this.towerId,
    required Tower initialState,
    required this.onTowerTapped,
    super.position,
    super.size,
  }) : _state = initialState;

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;

    _background = RectangleComponent(
      size: size,
      paint: Paint()..color = _getColorForState(),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_background);

    _valueText = TextComponent(
      text: _state.startValue.toString(),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: size / 2,
    );
    add(_valueText);

    _applyStateEffects();
  }

  void updateState(Tower newState) {
    if (_state == newState) return;
    
    _state = newState;
    _valueText.text = _state.startValue.toString();
    
    // Prof's Rule #1: Purge ALL effects from both this component and _background
    removeAll(children.query<Effect>());
    _background.removeAll(_background.children.query<Effect>());
    
    // Reset base properties AFTER purging to prevent frozen scale/color 
    scale.setValues(1.0, 1.0);
    _background.paint.color = _getColorForState();

    _applyStateEffects();
  }

  Color _getColorForState() {
    switch (_state.state) {
      case 'available':
        return Colors.green.shade400;
      case 'claimed':
        return Colors.amber.shade600;
      case 'solved':
        return Colors.grey.shade700;
      default:
        return Colors.grey;
    }
  }

  void _applyStateEffects() {
    if (_state.state == 'available') {
      // Gentle breathing effect (Scale on this PositionComponent is safe)
      add(
        ScaleEffect.by(
          Vector2.all(1.05),
          EffectController(
            duration: 1.5,
            reverseDuration: 1.5,
            infinite: true,
          ),
        ),
      );
    } else if (_state.state == 'claimed') {
      // Rapid blinking for urgency
      // ColorEffect MUST be applied to a HasPaint component (RectangleComponent)
      _background.add(
        ColorEffect(
          Colors.orangeAccent,
          EffectController(
            duration: 0.3,
            reverseDuration: 0.3,
            infinite: true,
          ),
        ),
      );
    } else if (_state.state == 'solved') {
      // Lock down animation sequence
      add(
        SequenceEffect([
          ScaleEffect.to(
            Vector2.all(1.15),
            EffectController(duration: 0.2),
          ),
          ScaleEffect.to(
            Vector2.all(1.0),
            EffectController(duration: 0.2),
          ),
        ]),
      );
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    // Only trigger getX modal on strict tapUp to avoid drag conflicts (Prof's rule)
    if (_state.state != 'solved') {
       onTowerTapped(towerId);
    }
  }
}
