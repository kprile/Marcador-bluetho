import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marcador_bluetooth/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final numbers=FontLoader('BarlowCondensed')..addFont(rootBundle.load('assets/fonts/BarlowCondensed-Black.ttf'));
    final body=FontLoader('PlusJakartaSans')..addFont(rootBundle.load('assets/fonts/PlusJakartaSans.ttf'));
    await numbers.load();await body.load();
  });
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(native,(call) async {
      if(call.method=='read') return '';
      if(call.method=='voices') return <dynamic>[{'name':'Voz de prueba offline','locale':'es-CL'}];
      return null;
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('cl.marcador/keys'),(call) async => null);
  });
  Future<void> render(WidgetTester tester,Size size) async {
    tester.view.physicalSize=size;tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const App());await tester.pumpAndSettle();
  }
  Future<void> preview(WidgetTester tester,String filename) async {
    final boundary=tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('court-surface')));
    await tester.runAsync(() async {
      final image=await boundary.toImage(pixelRatio:1);
      final data=await image.toByteData(format:ui.ImageByteFormat.png);
      final file=File('build/previews/$filename.png');await file.parent.create(recursive:true);
      await file.writeAsBytes(data!.buffer.asUint8List());image.dispose();
    });
  }
  testWidgets('marcador portrait suma, deshace e invierte solo la vista',(tester) async {
    await render(tester,const Size(390,844));
    await tester.tap(find.byKey(const ValueKey('score-team-0')));await tester.pumpAndSettle();
    expect(find.text('15'),findsOneWidget);
    await tester.tap(find.byTooltip('Invertir lados'));await tester.pumpAndSettle();
    expect(find.text('15'),findsOneWidget);
    await preview(tester,'portrait');
    await tester.tap(find.text('Deshacer'));await tester.pumpAndSettle();
    expect(find.text('15'),findsNothing);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
  });
  testWidgets('landscape y diálogos no desbordan',(tester) async {
    await render(tester,const Size(844,390));
    await preview(tester,'landscape');expect(tester.takeException(),isNull);
    await tester.tap(find.text('Nuevo Partido'));await tester.pumpAndSettle();
    expect(find.text('Configurar nuevo partido'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.tap(find.text('Cancelar'));await tester.pumpAndSettle();
    await tester.tap(find.text('Voz y Parlante'));await tester.pumpAndSettle();
    expect(find.text('Voz y control'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
  });
}
