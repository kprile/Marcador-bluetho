import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:marcador_bluetooth/scoring.dart';
import 'package:marcador_bluetooth/storage.dart';
void main() {
  Map<String,dynamic> state()=>{'version':2,'config':const MatchConfig().toJson(),
    'ledger':[0,1,0],'history':[],'key':24,'window':420,'rate':1.0,'voice':true,
    'selectedVoice':null,'device':null,'startedAt':'2026-10-19T10:00:00Z'};
  test('restauración de datos válidos',(){
    final j=validateSavedState(jsonEncode(state()));
    expect(Score.replay(MatchConfig.fromJson(j['config']),List<int>.from(j['ledger'])).points,[2,1]);
  });
  test('no acepta preferencias fuera de rango ni puntos inválidos',(){
    final j=state()..['window']=0;expect(()=>validateSavedState(jsonEncode(j)),throwsFormatException);
    final k=state()..['ledger']=[0,3];expect(()=>validateSavedState(jsonEncode(k)),throwsArgumentError);
  });
  test('rechaza puntos después de finalizar y configura saque válido',(){
    final j=state()..['config']=const MatchConfig(bestOf:1).toJson()..['ledger']=List.filled(25,0);
    expect(()=>validateSavedState(jsonEncode(j)),throwsFormatException);
    expect(()=>Score(const MatchConfig(firstServer:3)),throwsFormatException);
    expect(()=>Score(const MatchConfig(doubles:true,firstReceiver:2)),throwsFormatException);
  });
}
