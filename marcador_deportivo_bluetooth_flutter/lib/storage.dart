import 'dart:convert';
import 'scoring.dart';

Map<String,dynamic> validateSavedState(String raw) {
  final j=Map<String,dynamic>.from(jsonDecode(raw) as Map);
  if(j['version']!=2) throw const FormatException('Versión de datos no compatible');
  void checkMatch(Map<String,dynamic> m) {
    final c=MatchConfig.fromJson(Map<String,dynamic>.from(m['config']));
    final l=List<int>.from(m['ledger']);
    if(l.length>100000) throw const FormatException('Partido demasiado grande');
    Score.replay(c,l);
  }
  checkMatch(j);
  DateTime.parse(j['startedAt'] as String);
  if(j['device']!=null && j['device'] is! String) throw const FormatException('Control inválido');
  final history=List<Map<String,dynamic>>.from(j['history']);
  if(history.length>100) throw const FormatException('Historial inválido');
  for(final h in history) { checkMatch(h);DateTime.parse(h['date'] as String); }
  final k=j['key'] as int, w=j['window'] as int;
  final r=(j['rate'] as num).toDouble();
  if(k<1||k>999||w<220||w>700||r<0.5||r>1.5||!r.isFinite) {
    throw const FormatException('Preferencias inválidas');
  }
  if(j['voice'] is! bool) throw const FormatException('Preferencias de voz inválidas');
  if(j['selectedVoice']!=null && j['selectedVoice'] is! String) throw const FormatException('Voz inválida');
  return j;
}
