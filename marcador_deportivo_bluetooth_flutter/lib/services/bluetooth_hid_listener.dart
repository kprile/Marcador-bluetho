import 'dart:async';
import 'package:flutter/services.dart';

enum ScoreAction { pointP1, pointP2, undo }

class BluetoothHidListener {
  final Function(ScoreAction action) onAction;
  final Function(String keyName, int deltaMs)? onDiagnosticSignal;
  
  int doubleClickWindowMs = 420;
  int _clickCount = 0;
  Timer? _debounceTimer;
  DateTime? _lastPressTime;

  BluetoothHidListener({required this.onAction, this.onDiagnosticSignal});

  void startListening() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  void stopListening() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _debounceTimer?.cancel();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;
    final now = DateTime.now();
    final delta = _lastPressTime != null ? now.difference(_lastPressTime!).inMilliseconds : 0;
    _lastPressTime = now;

    // Detectar si la tecla corresponde a un disparador selfie común
    final isShutterKey = key == LogicalKeyboardKey.audioVolumeUp ||
        key == LogicalKeyboardKey.audioVolumeDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;

    if (!isShutterKey) {
      if (key == LogicalKeyboardKey.keyU || key == LogicalKeyboardKey.backspace) {
        onAction(ScoreAction.undo);
        return true;
      }
      onDiagnosticSignal?.call(key.keyLabel, delta);
      return false;
    }

    onDiagnosticSignal?.call(key.keyLabel, delta);
    _clickCount++;
    _debounceTimer?.cancel();

    // 3 pulsaciones rápidas = Deshacer
    if (_clickCount >= 3) {
      _clickCount = 0;
      onAction(ScoreAction.undo);
      return true;
    }

    // Ventana temporal para discriminar 1 vs 2 pulsaciones
    _debounceTimer = Timer(Duration(milliseconds: doubleClickWindowMs), () {
      final count = _clickCount;
      _clickCount = 0;

      if (count == 1) {
        onAction(ScoreAction.pointP1);
      } else if (count == 2) {
        onAction(ScoreAction.pointP2);
      }
    });

    return true; // Evitar que el sistema cambie el volumen nativo
  }
}
