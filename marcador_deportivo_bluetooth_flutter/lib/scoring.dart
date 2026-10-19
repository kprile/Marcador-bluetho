enum Sport { padel, tennis, tableTennis }

class MatchConfig {
  final Sport sport;
  final bool doubles, goldenPoint;
  final int bestOf, firstServer;
  final int? firstReceiver;
  final List<String> players;
  const MatchConfig({this.sport = Sport.padel, this.doubles = false,
    this.goldenPoint = false, this.bestOf = 3, this.firstServer = 0,
    this.firstReceiver,
    this.players = const ['Jugador 1', 'Jugador 2', 'Jugador 3', 'Jugador 4']});
  String get label => ['Pádel', 'Tenis', 'Ping-pong'][sport.index];
  List<int> get order => doubles ? [0, 1, 2, 3] : [0, 1];
  int get initialReceiver => firstReceiver ?? (firstServer.isEven ? 1 : 0);
  String team(int i) => doubles ? '${players[i]} / ${players[i + 2]}' : players[i];
  void validate() {
    if (![1,3,5,7].contains(bestOf) || !order.contains(firstServer) ||
        !order.contains(initialReceiver) || initialReceiver % 2 == firstServer % 2 ||
        players.length != 4 || players.any((p) => p.trim().isEmpty || p.length > 30)) {
      throw const FormatException('Configuración de partido inválida');
    }
  }
  Map<String, dynamic> toJson() => {'sport': sport.index, 'doubles': doubles,
    'golden': goldenPoint, 'bestOf': bestOf, 'firstServer': firstServer,
    'firstReceiver': firstReceiver, 'players': players};
  factory MatchConfig.fromJson(Map<String, dynamic> j) {
    final c = MatchConfig(sport: Sport.values[j['sport'] as int],
      doubles: j['doubles'] as bool, goldenPoint: j['golden'] as bool,
      bestOf: j['bestOf'] as int, firstServer: j['firstServer'] as int,
      firstReceiver: j['firstReceiver'] as int?, players: List<String>.from(j['players']));
    c.validate();
    return c;
  }
}

/// Replaying the point ledger makes undo restore service, tiebreaks and match end.
class Score {
  final MatchConfig config;
  List<int> points = [0, 0], games = [0, 0], sets = [0, 0];
  final List<List<int>> completed = [];
  int serviceTurn = 0, tableGameFirst = 0;
  int? winner, receiverSwapTeam;
  bool changeEnds = false, decidingEndsChanged = false;
  String lastEvent = '';
  Score(this.config) { config.validate(); }
  bool get table => config.sport == Sport.tableTennis;
  bool get tie => !table && games[0] == 6 && games[1] == 6;
  bool get deciding => sets[0] == config.bestOf ~/ 2 && sets[1] == config.bestOf ~/ 2;
  int get total => points[0] + points[1];
  int get _tableTurns => points[0] >= 10 && points[1] >= 10 ? total - 10 : total ~/ 2;
  List<int> get _tableOrder {
    final a = config.firstServer, b = config.initialReceiver;
    final base = config.doubles
        ? (tableGameFirst.isEven ? [a,b,(a+2)%4,(b+2)%4] : [b,a,(b+2)%4,(a+2)%4])
        : (tableGameFirst.isEven ? [a,b] : [b,a]);
    return base.map((p) => receiverSwapTeam == p % 2 ? (p+2)%4 : p).toList();
  }
  int get server {
    if (table) { final o = _tableOrder; return o[_tableTurns % o.length]; }
    final start = config.order.indexOf(config.firstServer);
    return config.order[(start + serviceTurn + (tie ? (total+1)~/2 : 0)) % config.order.length];
  }
  int? get receiver => table ? _tableOrder[(_tableTurns+1)%_tableOrder.length] : null;
  String pointLabel(int i) {
    if (table || tie) return '${points[i]}';
    if (points[0] >= 3 && points[1] >= 3) return points[i] > points[1-i] ? 'AD' : '40';
    return ['0','15','30','40'][points[i].clamp(0,3)];
  }
  String get pointSpeech {
    if (!table && !tie && points[0] >= 3 && points[1] >= 3) {
      if (points[0] == points[1]) return config.goldenPoint ? 'Cuarenta iguales. Punto de oro' : 'Iguales';
      return 'Ventaja para ${config.team(points[0] > points[1] ? 0 : 1)}';
    }
    return '${config.team(0)} ${pointLabel(0)}, ${config.team(1)} ${pointLabel(1)}';
  }
  bool _winsPointGame(int i) {
    final p=points[i]+1, q=points[1-i];
    if (table || tie) return p >= (table ? 11 : 7) && p-q >= 2;
    return p >= 4 && (p-q >= 2 || config.goldenPoint);
  }
  String get pressure {
    if (winner != null) return '';
    final notices=<String>[];
    for(var i=0;i<2;i++) {
      if (!_winsPointGame(i)) continue;
      final winsSet=table || tie || (games[i]+1>=6 && games[i]+1-games[1-i]>=2);
      final kind=winsSet ? (sets[i]+1>config.bestOf~/2 ? 'partido' : table ? 'juego' : 'set') : 'juego';
      notices.add('Punto de $kind para ${config.team(i)}');
    }
    return notices.join('. ');
  }
  void add(int i) {
    if (i!=0 && i!=1) throw ArgumentError.value(i,'team');
    if (winner!=null) return;
    final wasTie=tie;
    changeEnds=false; lastEvent='';
    points[i]++;
    final limit=table ? 11 : wasTie ? 7 : 4;
    final won=points[i]>=limit && (points[i]-points[1-i]>=2 || (!table && !wasTie && config.goldenPoint));
    if (table && deciding && !decidingEndsChanged && (points[0]==5 || points[1]==5)) {
      decidingEndsChanged=true;
      // At five points, the receiving pair changes receiving order, not the server.
      if(config.doubles) receiverSwapTeam=1-server%2;
      changeEnds=true;
    }
    if (wasTie && total%6==0) changeEnds=true;
    if (!won) return;
    if (table) {
      completed.add(List.of(points)); sets[i]++; tableGameFirst++; receiverSwapTeam=null; decidingEndsChanged=false;
      changeEnds=true; lastEvent='Juego para ${config.team(i)}.';
    } else {
      games[i]++; serviceTurn++;
      changeEnds=wasTie || (games[0]+games[1]).isOdd;
      lastEvent='Juego para ${config.team(i)}.';
      if(wasTie || (games[i]>=6 && games[i]-games[1-i]>=2)) {
        completed.add(List.of(games)); sets[i]++; games=[0,0];
        lastEvent='Set para ${config.team(i)}.';
      }
    }
    points=[0,0];
    if(sets[i]>config.bestOf~/2) { winner=i; lastEvent='Partido finalizado. Ganador ${config.team(i)}.'; changeEnds=false; }
  }
  static Score replay(MatchConfig config, Iterable<int> ledger) {
    final s=Score(config);
    for(final p in ledger) {
      if(s.winner!=null) throw const FormatException('Hay puntos después del final');
      s.add(p);
    }
    return s;
  }
  String get summary => '$pointSpeech. ${table ? "Juegos ganados" : "Sets"} ${sets[0]} a ${sets[1]}.'
    '${table ? "" : " Juegos ${games[0]} a ${games[1]}."}';
}
