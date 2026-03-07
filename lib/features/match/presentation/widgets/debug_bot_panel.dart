import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/usecases/bot_service.dart';

class DebugBotPanel extends StatefulWidget {
  final BotService botService;

  const DebugBotPanel({super.key, required this.botService});

  @override
  State<DebugBotPanel> createState() => _DebugBotPanelState();
}

class _DebugBotPanelState extends State<DebugBotPanel> {
  String _selectedSkill = 'random'; // default to random to be realistic

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Host Debug Controls (Bots)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Get.back(),
              )
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bot Skill Level:'),
              DropdownButton<String>(
                value: _selectedSkill,
                items: const [
                  DropdownMenuItem(value: 'optimal', child: Text('Optimal (Perfect)')),
                  DropdownMenuItem(value: 'random', child: Text('Random (Human-like)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedSkill = val;
                    });
                  }
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Obx(() => Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.botService.botCount >= 6 ? null : () async {
                    await widget.botService.spawnBot('teamA', _selectedSkill);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Team A'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[100]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.botService.botCount >= 6 ? null : () async {
                    await widget.botService.spawnBot('teamB', _selectedSkill);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Team B'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan[100]),
                ),
              ),
            ],
          )),
          
          const SizedBox(height: 8),
          Center(
            child: Obx(() => Text(
              '${widget.botService.botCount} / 6 Bots Spawned',
              style: TextStyle(color: Colors.grey[700], fontSize: 12),
            )),
          ),
          
          const SizedBox(height: 24),

          Obx(() => ElevatedButton.icon(
            onPressed: widget.botService.botCount == 0 ? null : () {
              if (widget.botService.isRunning) {
                widget.botService.stopSimulation();
              } else {
                widget.botService.startSimulation();
              }
            },
            icon: Icon(widget.botService.isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(widget.botService.isRunning ? 'STOP SIMULATION' : 'START SIMULATION'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.botService.isRunning ? Colors.red[100] : Colors.green[100],
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          )),
        ],
      ),
    );
  }
}
