enum SportType { padel, tennis, pingpong }
enum PadelDeuceRule { goldenPoint, advantage }

class ScoreEngine {
  SportType sport = SportType.padel;
  PadelDeuceRule padelDeuce = PadelDeuceRule.goldenPoint;
  
  int pointsP1 = 0;
  int pointsP2 = 0;
  int gamesP1 = 0;
  int gamesP2 = 0;
  int setsP1 = 0;
  int setsP2 = 0;
  
  int currentServer = 1; // 1 o 2
  bool isTiebreak = false;
  bool isMatchWon = false;
  
  final List<Map<String, dynamic>> _history = [];

  String addPoint(int player) {
    if (isMatchWon) return "Partido finalizado";
    _saveSnapshot();

    if (sport == SportType.pingpong) {
      return _handlePingPongPoint(player);
    } else {
      return _handleRacketPoint(player);
    }
  }

  String _handleRacketPoint(int player) {
    final isP1 = player == 1;
    if (isP1) pointsP1++; else pointsP2++;

    // Lógica Punto de Oro en Pádel
    if (padelDeuce == PadelDeuceRule.goldenPoint && pointsP1 >= 4 && pointsP2 >= 3) {
      return _winGame(player);
    }
    if (padelDeuce == PadelDeuceRule.goldenPoint && pointsP2 >= 4 && pointsP1 >= 3) {
      return _winGame(player);
    }

    // Puntos normales 0, 15, 30, 40
    if (pointsP1 >= 4 && pointsP1 - pointsP2 >= 2) return _winGame(1);
    if (pointsP2 >= 4 && pointsP2 - pointsP1 >= 2) return _winGame(2);

    if (pointsP1 == 3 && pointsP2 == 3 && padelDeuce == PadelDeuceRule.goldenPoint) {
      return "Cuarenta iguales. ¡Punto de oro!";
    }

    return "${_formatRacketPoint(pointsP1)} a ${_formatRacketPoint(pointsP2)}";
  }

  String _handlePingPongPoint(int player) {
    if (player == 1) pointsP1++; else pointsP2++;
    
    // Cambio de saque cada 2 puntos
    if ((pointsP1 + pointsP2) % 2 == 0) {
      currentServer = currentServer == 1 ? 2 : 1;
    }

    if ((pointsP1 >= 11 || pointsP2 >= 11) && (pointsP1 - pointsP2).abs() >= 2) {
      final winner = pointsP1 > pointsP2 ? 1 : 2;
      pointsP1 = 0; pointsP2 = 0;
      if (winner == 1) setsP1++; else setsP2++;
      return "Set para Jugador $winner. Sets: $setsP1 a $setsP2";
    }

    return "$pointsP1 a $pointsP2. Saca Jugador $currentServer";
  }

  String _winGame(int player) {
    pointsP1 = 0;
    pointsP2 = 0;
    if (player == 1) gamesP1++; else gamesP2++;
    currentServer = currentServer == 1 ? 2 : 1;

    if (gamesP1 >= 6 && gamesP1 - gamesP2 >= 2) {
      setsP1++; gamesP1 = 0; gamesP2 = 0;
      return "Set para Jugador 1. Sets: $setsP1 a $setsP2";
    }
    if (gamesP2 >= 6 && gamesP2 - gamesP1 >= 2) {
      setsP2++; gamesP1 = 0; gamesP2 = 0;
      return "Set para Jugador 2. Sets: $setsP1 a $setsP2";
    }

    return "Juego para Jugador $player. Juegos: $gamesP1 a $gamesP2. Saca Jugador $currentServer";
  }

  String _formatRacketPoint(int pts) {
    if (pts == 0) return "Cero";
    if (pts == 1) return "15";
    if (pts == 2) return "30";
    if (pts == 3) return "40";
    return "AD";
  }

  void _saveSnapshot() {
    _history.add({
      'p1': pointsP1, 'p2': pointsP2,
      'g1': gamesP1, 'g2': gamesP2,
      's1': setsP1, 's2': setsP2,
      'srv': currentServer,
    });
  }

  String undo() {
    if (_history.isEmpty) return "No hay puntos para deshacer";
    final last = _history.removeLast();
    pointsP1 = last['p1']; pointsP2 = last['p2'];
    gamesP1 = last['g1']; gamesP2 = last['g2'];
    setsP1 = last['s1']; setsP2 = last['s2'];
    currentServer = last['srv'];
    return "Punto corregido: ${_formatRacketPoint(pointsP1)} a ${_formatRacketPoint(pointsP2)}";
  }
}
