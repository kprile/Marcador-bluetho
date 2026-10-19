import 'dart:io';
import 'dart:convert';
import 'package:marcador_bluetooth/scoring.dart';
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
    final icons=FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await numbers.load();await body.load();await icons.load();
  });
  String stored="";
  final spoken=<Map<dynamic,dynamic>>[];
  setUp(() {
    stored="";spoken.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(native,(call) async {
      if(call.method=='read') return stored;
      if(call.method=='write') stored=call.arguments as String;
      if(call.method=='speak') spoken.add(Map<dynamic,dynamic>.from(call.arguments));
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
    await tester.tap(find.byTooltip('Menú de opciones'));await tester.pumpAndSettle();
    await tester.tap(find.text('Invertir lados'));await tester.pumpAndSettle();
    expect(find.text('15'),findsOneWidget);
    await preview(tester,'portrait');
    await tester.tap(find.byTooltip('Menú de opciones'));await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer último punto'));await tester.pumpAndSettle();
    expect(find.text('15'),findsNothing);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
  });
  testWidgets('landscape y diálogos no desbordan',(tester) async {
    await render(tester,const Size(844,390));
    await preview(tester,'landscape');expect(tester.takeException(),isNull);
    expect(find.text('SCOREBT'),findsNothing);
    expect(find.byTooltip('Menú de opciones'),findsOneWidget);
    await tester.tap(find.byTooltip('Menú de opciones'));await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo partido'));await tester.pumpAndSettle();
    expect(find.text('Configurar nuevo partido'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.tap(find.text('Cancelar'));await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Menú de opciones'));await tester.pumpAndSettle();
    await tester.tap(find.text('Voz y parlante'));await tester.pumpAndSettle();
    expect(find.text('Voz y control'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
  });
  testWidgets('la voz manual guardada no cambia al cargar otras voces',(tester) async {
    stored=jsonEncode({'version':2,'config':const MatchConfig().toJson(),'ledger':[],
      'history':[],'key':24,'window':420,'rate':1.0,'voice':true,
      'selectedVoice':'Mi voz elegida','device':null,'startedAt':'2026-10-19T17:00:00Z'});
    await render(tester,const Size(390,844));
    await tester.tap(find.byTooltip('Menú de opciones'));await tester.pumpAndSettle();
    await tester.tap(find.text('Repetir marcador'));await tester.pumpAndSettle();
    expect(spoken.last['voice'],'Mi voz elegida');
    await tester.tap(find.byTooltip('Menú de opciones'));await tester.pumpAndSettle();
    await tester.tap(find.text('Voz y parlante'));await tester.pumpAndSettle();
    expect(find.text('La voz guardada no está disponible. Selecciona otra o Automática.'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pumpAndSettle();
  });

}
