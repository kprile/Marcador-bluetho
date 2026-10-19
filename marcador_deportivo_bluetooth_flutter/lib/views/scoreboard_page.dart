import 'package:flutter/material.dart';
import '../services/score_engine.dart';
import '../services/tts_service.dart';
import '../services/bluetooth_hid_listener.dart';

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key});

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  final ScoreEngine _engine = ScoreEngine();
  final TtsService _tts = TtsService();
  late BluetoothHidListener _btListener;

  @override
  void initState() {
    super.initState();
    _btListener = BluetoothHidListener(
      onAction: (action) {
        if (action == ScoreAction.pointP1) {
          _scorePoint(1);
        } else if (action == ScoreAction.pointP2) {
          _scorePoint(2);
        } else if (action == ScoreAction.undo) {
          _undoPoint();
        }
      },
    );
    _btListener.startListening();
  }

  @override
  void dispose() {
    _btListener.stopListening();
    super.dispose();
  }

  void _scorePoint(int player) {
    final speech = _engine.addPoint(player);
    setState(() {});
    _tts.speak(speech);
  }

  void _undoPoint() {
    final speech = _engine.undo();
    setState(() {});
    _tts.speak(speech);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Barra superior de Sets y Juegos
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: const Color(0xFF131B2A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("PÁDEL · PUNTO DE ORO", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
                  Text("SETS: ${_engine.setsP1} - ${_engine.setsP2}  |  JUEGOS: ${_engine.gamesP1} - ${_engine.gamesP2}",
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.undo, color: Colors.orangeAccent),
                    onPressed: _undoPoint,
                    tooltip: "Deshacer punto",
                  ),
                ],
              ),
            ),
            
            // División vertical: Jugador 1 a la izquierda y Jugador 2 a la derecha
            Expanded(
              child: Row(
                children: [
                  // Lado izquierdo: Jugador 1
                  Expanded(
                    child: InkWell(
                      onTap: () => _scorePoint(1),
                      child: Container(
                        color: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Text("JUGADOR 1", style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w600)),
                                  if (_engine.currentServer == 1)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Chip(avatar: Icon(Icons.sports_tennis, size: 14), label: Text("SAQUE", style: TextStyle(fontSize: 10))),
                                    ),
                                ],
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("${_engine.pointsP1}", style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Color(0xFFE2F952))),
                              ),
                              Text("SETS: ${_engine.setsP1} | JUEGOS: ${_engine.gamesP1}",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Línea vertical divisoria en el centro
                  Container(
                    width: 3,
                    color: Colors.grey[700],
                    child: const Center(
                      child: Text("VS", style: TextStyle(fontSize: 9, color: Colors.white70, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  // Lado derecho: Jugador 2
                  Expanded(
                    child: InkWell(
                      onTap: () => _scorePoint(2),
                      child: Container(
                        color: const Color(0xFF090D14),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                children: [
                                  Text("JUGADOR 2", style: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w600)),
                                  if (_engine.currentServer == 2)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Chip(avatar: Icon(Icons.sports_tennis, size: 14), label: Text("SAQUE", style: TextStyle(fontSize: 10))),
                                    ),
                                ],
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text("${_engine.pointsP2}", style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8))),
                              ),
                              Text("SETS: ${_engine.setsP2} | JUEGOS: ${_engine.gamesP2}",
                                  style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
