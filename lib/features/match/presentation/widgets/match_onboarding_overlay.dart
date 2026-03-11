import 'package:flutter/material.dart';

class MatchOnboardingOverlay extends StatefulWidget {
  final GlobalKey botIconKey;
  final GlobalKey startIconKey;
  final VoidCallback onDismiss;

  const MatchOnboardingOverlay({
    super.key,
    required this.botIconKey,
    required this.startIconKey,
    required this.onDismiss,
  });

  @override
  State<MatchOnboardingOverlay> createState() => _MatchOnboardingOverlayState();
}

class _MatchOnboardingOverlayState extends State<MatchOnboardingOverlay> {
  Offset? _botIconOffset;
  Offset? _startIconOffset;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Delay slightly to ensure Obx has rendered the icons into the tree before we search for their RenderBox.
    // Resolves the "GlobalKey Null Pointer Trap (UI Crash)" blind spot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Small delay just to be 100% safe
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _calculatePositions();
      });
    });
  }

  void _calculatePositions() {
    final botContext = widget.botIconKey.currentContext;
    final startContext = widget.startIconKey.currentContext;

    if (botContext == null && startContext == null) {
      // Icons are not mounted yet, wait a bit and retry.
      // This is the strict null-check guard.
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 200), _calculatePositions);
      }
      return;
    }

    if (botContext != null) {
      final box = botContext.findRenderObject() as RenderBox;
      _botIconOffset = box.localToGlobal(Offset.zero);
    }
    
    if (startContext != null) {
      final box = startContext.findRenderObject() as RenderBox;
      _startIconOffset = box.localToGlobal(Offset.zero);
    }

    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Return a transparent block while we calculate coordinates to prevent UI flashes
      return const SizedBox.shrink();
    }

    // Usually the icons are on the top right
    final targetOffset = _startIconOffset ?? _botIconOffset ?? const Offset(300, 50);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent background tapping to dismiss
          GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              color: Colors.black.withOpacity(0.6),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          
          // The tooltip box
          Positioned(
            top: targetOffset.dy + 50, // Position below the icon
            right: 16, // Assuming the icons are typically on the right side of AppBar
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(Icons.arrow_upward, color: Colors.amber, size: 32),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Match Host Controls',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap 🤖 to simulate AI players.\nTap ⚡ to force start the match now!',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: widget.onDismiss,
                        child: const Text('Got it!', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
