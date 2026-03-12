import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/tower.dart';
import '../../domain/entities/player.dart';

/// A custom Flame component that draws a rounded rectangle + optional border.
class RoundedRectComponent extends PositionComponent {
  Paint paint;
  double radius;

  RoundedRectComponent({
    required this.paint,
    required this.radius,
    super.anchor,
    super.size,
    super.position,
  });

  @override
  void render(Canvas canvas) {
    if (paint.color.alpha == 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), Radius.circular(radius)),
      paint,
    );
  }
}

// Single shared palette used by BOTH tower bar AND avatar icon background.
// Using the same index guarantees they always match.
const List<Color> _towerPalette = [
  Color(0xFFF48FB1), // Pink
  Color(0xFFFFCC80), // Orange/Peach
  Color(0xFF80DEEA), // Cyan
  Color(0xFFB39DDB), // Light Purple
  Color(0xFFA5D6A7), // Mint Green
  Color(0xFFEF9A9A), // Light Red
  Color(0xFF90CAF9), // Sky Blue
  Color(0xFFFFF59D), // Yellow
];

class TowerComponent extends PositionComponent with TapCallbacks {
  final Map<String, Player> players;
  final String towerId;
  final Function(String) onTowerTapped;
  final Vector2 Function() getGameSize;
  final int Function() getTargetValue;
  final bool isTargetTower;

  Tower _state;
  int _index;
  bool _isCarOnTop;

  // Tower bar
  late RectangleComponent _bar;

  // Value label on the bar
  late TextComponent _valueText;

  // Purple base platform strip (sits under all towers within the component)
  late RectangleComponent _basePlatform;

  // Avatar: rounded square on the base, colored independently from bar
  late RoundedRectComponent _avatarBg;
  late TextComponent _avatarEmoji;
  late TextComponent _nameText;

  // Plus: yellow circle for available towers
  late CircleComponent _plusCircle;
  late TextComponent _plusText;

  // Car / clock on top
  late TextComponent _floatingText;

  TowerComponent({
    required this.players,
    required this.towerId,
    required Tower initialState,
    required int index,
    required this.getGameSize,
    required this.getTargetValue,
    required this.isTargetTower,
    required bool isCarOnTop,
    required this.onTowerTapped,
  })  : _state = initialState,
        _index = index,
        _isCarOnTop = isCarOnTop;

  @override
  Future<void> onLoad() async {
    anchor = Anchor.topLeft;

    // ── Base purple platform ─────────────────────────────────
    _basePlatform = RectangleComponent(
      paint: Paint()..color = const Color(0xFF5E35B1), // Deep Purple 600
      anchor: Anchor.topLeft,
    );
    add(_basePlatform);

    // ── Tower bar (grows up from base) ────────────────────────
    _bar = RectangleComponent(anchor: Anchor.bottomLeft);
    add(_bar);

    // ── Value text (top of bar) ───────────────────────────────
    _valueText = TextComponent(
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 2, color: Colors.black54)],
        ),
      ),
      anchor: Anchor.topCenter,
    );
    add(_valueText);

    // ── Avatar background (rounded square, independent pastel) ─
    _avatarBg = RoundedRectComponent(
      paint: Paint()..color = Colors.transparent,
      radius: 10,
      anchor: Anchor.center,
    );
    add(_avatarBg);

    _avatarEmoji = TextComponent(
      textRenderer: TextPaint(style: const TextStyle(fontSize: 16)),
      anchor: Anchor.center,
    );
    _avatarBg.add(_avatarEmoji);

    _nameText = TextComponent(
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
      ),
      anchor: Anchor.topCenter,
    );
    add(_nameText);

    // ── Plus circle (yellow) for available ────────────────────
    _plusCircle = CircleComponent(
      radius: 18,
      paint: Paint()..color = const Color(0xFFFFEE58), // Yellow
      anchor: Anchor.center,
    );
    add(_plusCircle);

    _plusText = TextComponent(
      text: '+',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Color(0xFF6A1B9A),
          fontSize: 26,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
      anchor: Anchor.center,
    );
    _plusCircle.add(_plusText);

    // ── Floating car / clock ──────────────────────────────────
    _floatingText = TextComponent(
      textRenderer: TextPaint(style: const TextStyle(fontSize: 18)),
      anchor: Anchor.bottomCenter,
    );
    add(_floatingText);

    recalculateLayout();
  }

  void updateState(Tower newState, int index, bool isCarOnTop) {
    _state = newState;
    _index = index;
    _isCarOnTop = isCarOnTop;
    recalculateLayout();
  }

  void recalculateLayout() {
    final gameSize = getGameSize();
    if (gameSize.y == 0) return;

    const double towerWidth = 50.0;
    const double basePlatformHeight = 70.0; // The dark purple base
    const double avatarSize = 36.0;          // Rounded square icon inside base
    const double nameLabelHeight = 14.0;

    size = Vector2(towerWidth, gameSize.y);

    // Purple base runs from (size.y - basePlatformHeight) to size.y
    _basePlatform.size = Vector2(towerWidth, basePlatformHeight);
    _basePlatform.position = Vector2(0, size.y - basePlatformHeight);

    // Avatar / plus sits centered at 1/2 of basePlatform height
    final double iconCenterY = size.y - basePlatformHeight + basePlatformHeight / 2 - nameLabelHeight / 2;
    _avatarBg.size = Vector2(avatarSize, avatarSize);
    _avatarBg.position = Vector2(towerWidth / 2, iconCenterY);
    _avatarEmoji.position = Vector2(avatarSize / 2, avatarSize / 2);

    _nameText.position = Vector2(towerWidth / 2, size.y - basePlatformHeight + basePlatformHeight - nameLabelHeight);

    _plusCircle.radius = 18;
    _plusCircle.position = Vector2(towerWidth / 2, iconCenterY);
    _plusText.position = Vector2(18, 21);

    // ── Bar height calculation ────────────────────────────────
    bool isSolved = _state.state == 'solved';
    bool isAvailable = _state.state == 'available';
    bool isClaimed = _state.state == 'claimed';

    final int targetValue = getTargetValue();
    double ratio = targetValue > 0 ? _state.startValue / targetValue : 0;

    double heightRatio;
    if (isTargetTower || isSolved) {
      // Solved towers rise to full height — same as the 1000 target tower
      heightRatio = 0.92;
    } else {
      heightRatio = ratio.clamp(0.08, 0.92);
    }

    // Bar top anchor is at base top; bar descends down
    final double usableHeight = size.y - basePlatformHeight;
    final double finalBarHeight = usableHeight * heightRatio;

    _bar.size = Vector2(towerWidth, finalBarHeight);
    _bar.position = Vector2(0, size.y - basePlatformHeight); // bottom-left anchor

    // Value text sits just above top of bar
    if (!isSolved || isTargetTower) {
      _valueText.text = _state.startValue.toString();
      _valueText.position = Vector2(towerWidth / 2, size.y - basePlatformHeight - finalBarHeight + 4);
    } else {
      _valueText.text = '';
    }

    // ── Icon visibility ───────────────────────────────────────
    if (isTargetTower) {
      _avatarBg.paint.color = Colors.transparent;
      _avatarEmoji.text = '';
      _nameText.text = '';
      _plusCircle.paint.color = Colors.transparent;
      _plusText.text = '';
    } else if (isAvailable) {
      _avatarBg.paint.color = Colors.transparent;
      _avatarEmoji.text = '';
      _nameText.text = '';
      _plusCircle.paint.color = const Color(0xFFFFEE58);
      _plusText.text = '+';
    } else {
      _plusCircle.paint.color = Colors.transparent;
      _plusText.text = '';
      String uid = _state.claimedBy ?? _state.solvedBy ?? '';
      _avatarEmoji.text = _getEmojiForUser(uid);
      String displayName = players.containsKey(uid) ? players[uid]!.displayName : uid;
      
      // Cut to 6 chars
      if (displayName.length > 6) {
        displayName = displayName.substring(0, 6);
      }
      _nameText.text = displayName;
      // Avatar bg = same palette as bar → always matches tower color
      _avatarBg.paint.color = _towerPalette[_index % _towerPalette.length];
    }

    // ── Car or hourglass ──────────────────────────────────────
    if (_isCarOnTop) {
      _floatingText.text = '🚗';
      _floatingText.position = Vector2(towerWidth / 2, size.y - basePlatformHeight - finalBarHeight + 2);
    } else if (isClaimed && !isTargetTower) {
      _floatingText.text = '⏳';
      _floatingText.position = Vector2(towerWidth / 2, size.y - basePlatformHeight - finalBarHeight - 2);
    } else {
      _floatingText.text = '';
    }

    _applyBarColor();
  }

  void _applyBarColor() {
    if (isTargetTower) {
      _bar.paint.color = const Color(0xFF7E57C2); // Deep purple for target
      return;
    }
    if (_state.state == 'solved') {
      // Solved: keep tower bar the same palette color but slightly darker/greyer
      final base = _towerPalette[_index % _towerPalette.length];
      _bar.paint.color = Color.fromARGB(255, 
        ((base.red * 0.6) + (128 * 0.4)).round(),
        ((base.green * 0.6) + (128 * 0.4)).round(),
        ((base.blue * 0.6) + (128 * 0.4)).round(),
      );
      return;
    }
    // Bar color = same as avatar background = same palette index
    _bar.paint.color = _towerPalette[_index % _towerPalette.length];
  }

  String _getEmojiForUser(String uid) {
    if (uid.isEmpty) return '😺';
    // All players/bots get animal avatars
    const emojis = ['🐱', '🐶', '🦉', '🐰', '🐻', '🦊', '🐼', '🐯'];
    return emojis[uid.hashCode.abs() % emojis.length];
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!isTargetTower && _state.state != 'solved') {
      onTowerTapped(towerId);
    }
  }
}
