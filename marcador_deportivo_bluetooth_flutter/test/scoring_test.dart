import 'package:flutter_test/flutter_test.dart';
import 'package:marcador_bluetooth/scoring.dart';
void main() {
  void game(Score s,int p) { for(var n=0;n<4;n++) { s.add(p); } }
  test('15, 30, 40, juego y cambio de saque', () {
    final s=Score(const MatchConfig()); s.add(0); expect(s.pointLabel(0),'15');
    s.add(0);expect(s.pointLabel(0),'30');s.add(0);expect(s.pressure,contains('juego'));
    s.add(0);expect(s.games,[1,0]);expect(s.server,1);
  });
  test('iguales, ventaja y regreso a iguales', () {
    final s=Score(const MatchConfig());for(var n=0;n<3;n++){s.add(0);s.add(1);}
    s.add(0);expect(s.pointLabel(0),'AD');s.add(1);expect(s.pointLabel(0),'40');
    s.add(1);s.add(1);expect(s.games,[0,1]);
  });
  test('punto de oro', () {
    final s=Score(const MatchConfig(goldenPoint:true));
    for(var n=0;n<3;n++){s.add(0);s.add(1);}s.add(1);expect(s.games,[0,1]);
  });
  test('6-6, tie-break prolongado y saque siguiente', () {
    final s=Score(const MatchConfig(doubles:true));
    for(var n=0;n<6;n++){game(s,0);game(s,1);}expect(s.tie,true);expect(s.server,0);
    s.add(0);expect(s.server,1);s.add(1);expect(s.server,1);s.add(0);expect(s.server,2);
    s.add(1);for(var n=0;n<4;n++){s.add(0);s.add(1);}expect(s.points,[6,6]);
    s.add(0);s.add(0);expect(s.completed.single,[7,6]);expect(s.server,1);
  });
  test('ganador, punto de partido y bloqueo después del final', () {
    final s=Score(const MatchConfig(bestOf:1));for(var n=0;n<5;n++){game(s,0);}
    s.add(0);s.add(0);s.add(0);expect(s.pressure,contains('partido'));
    s.add(0);expect(s.winner,0);s.add(1);expect(s.points,[0,0]);
  });
  test('ping-pong deuce y saque cada dos / uno', () {
    final s=Score(const MatchConfig(sport:Sport.tableTennis));
    s.add(0);expect(s.server,0);s.add(1);expect(s.server,1);
    for(var n=0;n<9;n++){s.add(0);s.add(1);}expect(s.points,[10,10]);
    s.add(0);expect(s.winner,null);expect(s.server,1);s.add(0);expect(s.sets,[1,0]);expect(s.server,1);
  });
  test('undo reconstruye un set y su saque', () {
    final c=const MatchConfig(bestOf:1);final ledger=List.filled(24,0,growable:true);
    expect(Score.replay(c,ledger).winner,0);ledger.removeLast();
    final s=Score.replay(c,ledger);expect(s.winner,null);expect(s.games,[5,0]);expect(s.points,[3,0]);expect(s.server,1);
  });
  test('dobles tenis rota los cuatro jugadores', () {
    final s=Score(const MatchConfig(sport:Sport.tennis,doubles:true));
    expect(s.server,0);game(s,0);expect(s.server,1);game(s,0);expect(s.server,2);
    game(s,0);expect(s.server,3);
  });
  test('configuración JSON conserva opciones', () {
    const c=MatchConfig(sport:Sport.tableTennis,doubles:true,firstServer:3,bestOf:5);
    final d=MatchConfig.fromJson(c.toJson());expect(d.firstServer,3);expect(d.team(1),'Jugador 2 / Jugador 4');
  });
  test('dobles ping-pong conserva primer sacador y rota para cada elección', () {
    for(var first=0;first<4;first++) {
      final s=Score(MatchConfig(sport:Sport.tableTennis,doubles:true,firstServer:first));
      expect(s.server,first);
      s.add(0);s.add(0);expect(s.server,first.isEven?1:0);
      s.add(0);s.add(0);expect(s.server,(first+2)%4);
    }
  });
  test('ping-pong dobles cambia receptor a cinco en juego decisivo', () {
    final s=Score(const MatchConfig(sport:Sport.tableTennis,doubles:true,bestOf:1));
    for(var n=0;n<5;n++){s.add(0);}
    expect(s.server,2); // sigue el sacador, cambia la pareja que recibe
    s.add(1);expect(s.server,1); // próximo turno refleja el cambio de receptor
  });

  test('ping-pong alterna primer sacador entre juegos, incluso tras 11–1', () {
    final s=Score(const MatchConfig(sport:Sport.tableTennis));
    s.add(1);for(var n=0;n<11;n++){s.add(0);}
    expect(s.server,1);s.add(1);s.add(0);expect(s.server,0);
  });
  test('cambio de lado en juego decisivo ocurre una sola vez', () {
    final s=Score(const MatchConfig(sport:Sport.tableTennis,bestOf:1));
    for(var n=0;n<5;n++){s.add(0);}expect(s.changeEnds,true);
    s.add(1);expect(s.changeEnds,false);
  });
  test('deshacer final vuelve a punto de partido y conserva tanteo', () {
    const c=MatchConfig(bestOf:1);final ledger=List.filled(24,1,growable:true);
    expect(Score.replay(c,ledger).winner,1);
    ledger.removeLast();final s=Score.replay(c,ledger);
    expect(s.pointLabel(1),'40');expect(s.pressure,contains('partido'));
  });
  test('primer receptor elegido define la rotación de dobles', () {
    final s=Score(const MatchConfig(sport:Sport.tableTennis,doubles:true,firstServer:2,firstReceiver:3));
    expect(s.server,2);expect(s.receiver,3);s.add(0);s.add(0);
    expect(s.server,3);expect(s.receiver,0);
  });

}
