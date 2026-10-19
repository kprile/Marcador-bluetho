import 'package:flutter_test/flutter_test.dart';
import 'package:marcador_bluetooth/remote_clicks.dart';
void main() {
  testWidgets('simple espera y doble cuenta solo para equipo dos', (tester) async {
    final points=<int>[];var undo=0;
    final r=RemoteClicks(onPoint:points.add,onUndo:()=>undo++,window:const Duration(milliseconds:420));
    r.press();await tester.pump(const Duration(milliseconds:419));expect(points,isEmpty);
    await tester.pump(const Duration(milliseconds:1));expect(points,[0]);
    r.press();await tester.pump(const Duration(milliseconds:100));r.press();
    await tester.pump(const Duration(milliseconds:420));expect(points,[0,1]);expect(undo,0);
  });
  testWidgets('tres clics deshacen sin sumar y cancelar descarta pendientes', (tester) async {
    final points=<int>[];var undo=0;
    final r=RemoteClicks(onPoint:points.add,onUndo:()=>undo++);
    r.press();r.press();r.press();await tester.pump(const Duration(seconds:1));
    expect(points,isEmpty);expect(undo,1);
    r.press();r.cancel();await tester.pump(const Duration(seconds:1));expect(points,isEmpty);
    r.press();await tester.pump(const Duration(seconds:1));expect(points,[0]);
  });
}
