import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'scoring.dart';
import 'storage.dart';
import 'remote_clicks.dart';

void main() => runApp(const App());
const native = MethodChannel('cl.marcador/native');
const keys = EventChannel('cl.marcador/keys');

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Cancha · v2',
    theme: ThemeData(fontFamily:'PlusJakartaSans',brightness: Brightness.dark, useMaterial3: true,
      colorSchemeSeed: const Color(0xffe2f952), scaffoldBackgroundColor: const Color(0xff0b0f17),
      dialogTheme:const DialogThemeData(backgroundColor:Color(0xff0f172a)),
      inputDecorationTheme:const InputDecorationTheme(filled:true,fillColor:Color(0xff020617),border:OutlineInputBorder())),
    home: const Home());
}
class Home extends StatefulWidget {
  const Home({super.key});
  @override State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> with WidgetsBindingObserver {
  MatchConfig config = const MatchConfig(goldenPoint:true);
  List<int> ledger = [];
  List<Map<String, dynamic>> history = [];
  Score get score => Score.replay(config, ledger);
  bool voice = true, remote = false, ready = false;
  int keyCode = 24, window = 420;
  String? selectedVoice;
  double rate = 1.0;
  String startedAt=DateTime.now().toIso8601String();
  List<dynamic> voices = [];
  final signalLog = ValueNotifier<List<Map<String,dynamic>>>([]);
  late final RemoteClicks clicks;
  String? deviceDescriptor;
  bool overlay = false, foreground = true;
  bool swapped = false, fullscreen = false;
  StreamSubscription<dynamic>? subscription;
  String? error;
  Future<void> writes = Future.value();
  @override void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    clicks=RemoteClicks(onPoint:add,onUndo:undo); load();
    subscription = keys.receiveBroadcastStream().listen(onKey, onError: (Object e) {
      if (mounted) setState(() => error = 'Diagnóstico no disponible: $e');
    });
  }
  Future<dynamic> call(String method, [dynamic args]) async {
    try { return await native.invokeMethod<dynamic>(method, args).timeout(const Duration(seconds:5)); }
    catch (e) { if (mounted) setState(() => error = '$method: $e'); return null; }
  }
  Future<void> load() async {
    final raw = await call('read');
    try {
      if (raw is String && raw.isNotEmpty) {
        final j = validateSavedState(raw);
        // Assign only after the entire payload, including history, is validated.
        config = MatchConfig.fromJson(Map<String,dynamic>.from(j['config']));
        ledger = List<int>.from(j['ledger']);
        history = List<Map<String,dynamic>>.from(j['history']);
        keyCode = j['key']; window = j['window'];
        voice = j['voice']; selectedVoice = j['selectedVoice'];
        rate = (j['rate'] as num).toDouble();
        deviceDescriptor = j['device'] as String?;
        startedAt = j['startedAt'];
      }
    } catch (e) { error = 'No se pudo restaurar el partido: $e'; }
    if(!mounted) return;
    clicks.window=Duration(milliseconds:window);
    await call('awake', true);
    final available = await call('voices');
    if (mounted) setState(() { voices = available is List ? available : []; ready = true; });
  }
  void save() {
    final raw = jsonEncode({'version':2,'config': config.toJson(), 'ledger': ledger,
      'history': history, 'key': keyCode, 'window': window, 'voice': voice,
      'selectedVoice': selectedVoice, 'rate': rate, 'device': deviceDescriptor, 'startedAt':startedAt});
    writes = writes.then((_) async { await call('write', raw); });
  }
  void speak(String text) {
    if (voice) call('speak', {'text': text, 'voice': selectedVoice, 'rate': rate});
  }
  void cancelPending() => clicks.cancel();
  Future<void> capture() async { await call('capture', {
    'code': remote && !overlay && foreground ? keyCode : -1,
    'descriptor': deviceDescriptor,
  }); }
  bool allowedKey(int code) => code>0 && code<1000 && ![3,4,26,187].contains(code);
  void onKey(dynamic event) {
    if(!mounted || !ready || event is! Map) return;
    final e=Map<String,dynamic>.from(event);
    e['time']=DateTime.now().toIso8601String().substring(11,23);
    signalLog.value=[e,...signalLog.value.take(79)];
    if(!foreground || overlay || !remote ||
      e['code']!=keyCode || e['action']!=0 || e['repeat']!=0 ||
      (deviceDescriptor!=null && e['descriptor']!=deviceDescriptor)) return;
    clicks.press();
  }
  void archive() {
    if (ledger.isEmpty) return;
    history.insert(0, {'date': startedAt,
      'config': config.toJson(), 'ledger': List.of(ledger)});
    if (history.length > 100) history.removeLast();
  }
  void add(int team) {
    if (score.winner != null) return;
    cancelPending();
    final before = score;
    setState(() => ledger.add(team)); save();
    final after = score;
    var message='${after.lastEvent} ${after.summary}';
    if(after.winner==null) {
      if(before.server!=after.server) message+=' Cambio de saque. Saca ${config.players[after.server]}.';
      if(after.changeEnds) message+=' Cambio de lado.';
      if(after.table && before.receiver!=after.receiver) message+=' Recibe ${config.players[after.receiver!]}.';
      message+=' ${after.pressure}';
    }
    speak(message);
  }
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground=state==AppLifecycleState.resumed;
    cancelPending(); capture();
    if(!foreground) { save(); call('stop'); }
    else { call('awake',true); }
  }
  @override void dispose() {
    WidgetsBinding.instance.removeObserver(this); cancelPending(); subscription?.cancel();
    signalLog.dispose();
    native.invokeMethod<void>('awake', false); super.dispose();
  }
  Future<void> setup() async {
    cancelPending();
    overlay=true; await capture(); if(!mounted) return;
    var sport = config.sport;
    var doubles = config.doubles;
    var golden = config.goldenPoint;
    var best = config.bestOf;
    var first = config.firstServer;
    var receiver = config.initialReceiver;
    final names = config.players.map((n) => TextEditingController(text:n)).toList();
    final result = await showDialog<MatchConfig>(context: context, builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(title: const Text('Configurar nuevo partido'), content: SizedBox(width:420,
        child: SingleChildScrollView(child: Column(mainAxisSize:MainAxisSize.min, children:[
          DropdownButtonFormField<Sport>(initialValue:sport, items:Sport.values.map((s) => DropdownMenuItem(
            value:s, child:Text(['Pádel','Tenis','Ping-pong'][s.index]))).toList(), onChanged:(v) => update(() { sport=v!; golden=sport==Sport.padel; })),
          SwitchListTile(title:const Text('Dobles'), value:doubles, onChanged:(v) => update(() { doubles=v; first=0; receiver=1; })),
          for(var i=0;i<(doubles?4:2);i++) TextField(controller:names[i], maxLength:30,
            decoration:InputDecoration(labelText:'Jugador ${i+1} · equipo ${i%2+1}')),
          DropdownButtonFormField<int>(initialValue:best, decoration:const InputDecoration(labelText:'Al mejor de'),
            items:[1,3,5,7].map((n)=>DropdownMenuItem(value:n,child:Text('$n ${sport==Sport.tableTennis?"juegos":"sets"}'))).toList(),
            onChanged:(v)=>update(()=>best=v!)),
          DropdownButtonFormField<int>(key:ValueKey('first-$doubles-$first'), initialValue:first, decoration:const InputDecoration(labelText:'Primer saque'),
            items:List.generate(doubles?4:2,(i)=>DropdownMenuItem(value:i,child:Text('Jugador ${i+1}'))),
            onChanged:(v)=>update(() { first=v!; receiver=first.isEven?1:0; })),
          if(sport==Sport.tableTennis && doubles) DropdownButtonFormField<int>(
            key:ValueKey('receiver-$first-$receiver'),initialValue:receiver,
            decoration:const InputDecoration(labelText:'Primer receptor'),
            items:[for(var i=0;i<4;i++) if(i%2!=first%2) DropdownMenuItem(value:i,child:Text('Jugador ${i+1}'))],
            onChanged:(v)=>update(()=>receiver=v!)),
          if(sport!=Sport.tableTennis) SwitchListTile(title:Text(sport==Sport.padel?'Punto de oro':'Sin ventajas (No-Ad)'),
            value:golden,onChanged:(v)=>update(()=>golden=v)),
          const Text('Tenis/pádel: sets a 6, diferencia de 2 y tie-break a 7 en 6–6. '
            'Ping-pong: juegos a 11, diferencia de 2. Orden de dobles: J1 → J2 → J3 → J4. '
            'Orden fijo durante el partido. Pádel individual: modalidad recreativa. '
            'Antes de iniciar otro se archiva el actual.'),
        ]))), actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,MatchConfig(sport:sport,doubles:doubles,goldenPoint:golden,
          bestOf:best,firstServer:first,firstReceiver:receiver,players:List.generate(4,(i)=>names[i].text.trim().isEmpty?'Jugador ${i+1}':names[i].text.trim()))),
          child:const Text('Archivar e iniciar'))])));
    // Wait for the closing dialog transition before disposing its text controllers.
    await Future<void>.delayed(const Duration(milliseconds:300));
    for(final c in names) { c.dispose(); }
    overlay=false; await capture();
    if(result!=null && mounted) {
      setState(() { archive(); config=result; ledger=[]; startedAt=DateTime.now().toIso8601String(); }); save(); speak('Nuevo partido. Saca ${config.players[score.server]}.');
    }
  }
  Future<void> settings() async {
    cancelPending(); overlay=true; await capture();
    final available=await call('voices');
    if(available is List) voices=available;
    if(!mounted) return;
    await showModalBottomSheet<void>(context:context,isScrollControlled:true,builder:(ctx)=>StatefulBuilder(
      builder:(ctx,update)=>SafeArea(child:SingleChildScrollView(child:Padding(padding:const EdgeInsets.all(24),
        child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Voz y control',style:Theme.of(ctx).textTheme.headlineSmall),
          SwitchListTile(title:const Text('Anunciar marcador'),value:voice,onChanged:(v){setState(()=>voice=v);update((){});}),
          DropdownButtonFormField<String>(initialValue:voices.any((v)=>v['name']==selectedVoice)?selectedVoice:null,
            decoration:const InputDecoration(labelText:'Voces españolas instaladas sin red'),
            isExpanded:true,
            items:voices.map((v)=>DropdownMenuItem<String>(value:v['name'] as String,
              child:Text('${v['name']}',overflow:TextOverflow.ellipsis))).toList(),
            onChanged:(v){setState(()=>selectedVoice=v);update((){});}),
          const Text('Si no hay voces, instala una voz española sin conexión desde los ajustes de Android.'),
          Text('Velocidad: ${rate.toStringAsFixed(1)}'),
          Slider(value:rate,min:0.5,max:1.5,divisions:10,onChanged:(v){setState(()=>rate=v);update((){});}),
          OutlinedButton(onPressed:()=>speak('Prueba de voz. Quince, treinta. Cambio de saque.'),child:const Text('Probar voz')),
          SwitchListTile(title:const Text('Activar control Bluetooth'),subtitle:const Text('Emparejar en ajustes de Android'),
            value:remote,onChanged:(v){setState(()=>remote=v);update((){});}),
          TextFormField(initialValue:'$keyCode',keyboardType:TextInputType.number,
            decoration:const InputDecoration(labelText:'Código Android observado en diagnóstico'),
            onChanged:(v){final n=int.tryParse(v);if(n!=null && allowedKey(n)){keyCode=n;deviceDescriptor=null;}}),
          Text('Ventana de doble pulsación: $window ms'),
          Slider(value:window.toDouble(),min:220,max:700,divisions:24,
            onChanged:(v){setState(() { window=v.round(); clicks.window=Duration(milliseconds:window); });update((){});}),
          Text(deviceDescriptor==null?'Filtro: cualquier dispositivo con esa tecla':'Control aprendido: filtro por dispositivo activo'),
          OutlinedButton(onPressed:()=>call('ttsSettings'),child:const Text('Abrir ajustes de voz de Android')),
          const Text('Una pulsación: equipo 1. Dos: equipo 2. Tres: deshacer. Se espera la ventana antes de sumar al equipo 1. '
            'El control debe emitir eventos de teclado; algunos disparadores no son compatibles. '
            'La voz sale por la salida de audio elegida en Android.'),
          FilledButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Guardar')),
        ]))))));
    overlay=false; await capture(); save();
  }
  Future<void> diagnostics() async {
    cancelPending(); overlay=true; await capture();
    if(!mounted) return;
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Diagnóstico Bluetooth'),
      content:SizedBox(width:600,height:400,child:ValueListenableBuilder<List<Map<String,dynamic>>>(
        valueListenable:signalLog,builder:(ctx,events,_)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Pulsa el control. Aquí no se suman puntos. Toca una señal DOWN para usar ese botón. '
            'Cada pulsación debe dar DOWN=0 y UP=1. Algunas teclas pueden cambiar el volumen durante el diagnóstico.'),
          const SizedBox(height:12),Expanded(child:ListView(children:events.map((e)=>ListTile(dense:true,
            title:Text('${e['time']} · key=${e['code']} · action=${e['action']} · repeat=${e['repeat']}',
              style:const TextStyle(fontFamily:'monospace',fontSize:12)),
            subtitle:Text('${e['device']} · scan=${e['scan']}'),
            onTap:e['action']==0 && e['repeat']==0 && allowedKey(e['code'] as int)?(){
              setState(() { keyCode=e['code']; deviceDescriptor=e['descriptor']; remote=true; });
              save(); Navigator.pop(ctx);
            }:null)).toList())),
        ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar'))]));
    overlay=false; await capture();
  }
  Future<void> showHistory() async {
    cancelPending(); overlay=true; await capture(); if(!mounted) return;
    final records=[if(ledger.isNotEmpty) {'date':startedAt,'config':config.toJson(),'ledger':ledger},...history];
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Historial · guardado en este teléfono'),
      content:SizedBox(width:500,height:400,child:records.isEmpty?const Text('Todavía no hay partidos. Cada punto se guarda automáticamente.'):
        ListView(children:records.map((h){final c=MatchConfig.fromJson(h['config']);
          final s=Score.replay(c,List<int>.from(h['ledger']));
          return ListTile(title:Text('${c.label} · ${h['date'].toString().substring(0,16)}'),
            subtitle:Text('${c.team(0)} / ${c.team(1)}\n${s.sets[0]}–${s.sets[1]} · '
              '${s.winner==null?"Incompleto":"Ganador: ${c.team(s.winner!)}"}\n'
              '${s.completed.map((v)=>v.join("–")).join("  ")}'));
        }).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cerrar'))]));
    overlay=false; await capture();
  }

  static const yellow=Color(0xffe2f952), cyan=Color(0xff38bdf8), muted=Color(0xff94a3b8);
  Future<void> toggleFullscreen() async {
    setState(()=>fullscreen=!fullscreen);
    await SystemChrome.setEnabledSystemUIMode(fullscreen?SystemUiMode.immersiveSticky:SystemUiMode.edgeToEdge);
  }
  void undo() {
    if(ledger.isEmpty) return;
    cancelPending(); setState(()=>ledger.removeLast());save();
    speak('Punto corregido. ${score.summary} Saca ${config.players[score.server]}.');
  }
  Widget header(bool compact) => Container(
    decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Color(0xff1e293b)))),
    padding:const EdgeInsets.symmetric(horizontal:14),height:52,
    child:Row(children:[
      const Text.rich(TextSpan(children:[TextSpan(text:'SCORE',style:TextStyle(color:yellow)),TextSpan(text:'BT')]),
        style:TextStyle(fontSize:20,fontWeight:FontWeight.w900,letterSpacing:-1)),
      const SizedBox(width:12),
      Expanded(child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        nav('Marcador',Icons.scoreboard,()=>{},compact,selected:true),
        nav('Diagnóstico BT',Icons.bluetooth_searching,diagnostics,compact),
        nav('Voz y Parlante',Icons.volume_up,settings,compact),
        nav('Historial',Icons.history,showHistory,compact),
      ]))),
      const SizedBox(width:8),
      FilledButton(style:FilledButton.styleFrom(backgroundColor:yellow,foregroundColor:const Color(0xff020617),
        padding:const EdgeInsets.symmetric(horizontal:12),minimumSize:const Size(0,36)),
        onPressed:ready?setup:null,child:Text(compact?'Nuevo':'Nuevo Partido',style:const TextStyle(fontWeight:FontWeight.w800))),
    ]));
  Widget nav(String label,IconData icon,VoidCallback action,bool compact,{bool selected=false}) => compact
    ? IconButton(tooltip:label,onPressed:ready?action:null,icon:Icon(icon,size:20,color:selected?yellow:muted))
    : TextButton(onPressed:ready?action:null,child:Text(label,style:TextStyle(color:selected?yellow:muted,fontSize:12)));
  Widget miniMetric(String label,int value,{Color color=Colors.white}) => Expanded(child:Column(mainAxisSize:MainAxisSize.min,children:[
    Text(label,style:const TextStyle(color:Color(0xff64748b),fontSize:10,letterSpacing:1)),
    Text('$value',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900,color:color)),
  ]));
  Widget panel(int i,Score s,bool low) {
    final color=i==0?yellow:cyan;
    final serving=s.winner==null && s.server%2==i;
    return Expanded(child:Semantics(label:'Sumar punto equipo ${i+1}',button:true,
      child:Material(color:Colors.transparent,child:Ink(
        decoration:BoxDecoration(gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:i==0?const [Color(0xff0e1626),Color(0xff090e18)]:const [Color(0xff0b1320),Color(0xff070b14)])),
        child:InkWell(key:ValueKey('score-team-$i'),onTap:s.winner==null?()=>add(i):null,
          child:Padding(padding:EdgeInsets.all(low?10:18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('EQUIPO ${i+1} · ${i==0?"1 CLIC":"2 CLICS"}',style:const TextStyle(color:muted,fontSize:10,letterSpacing:1)),
            Text(config.team(i),maxLines:1,overflow:TextOverflow.ellipsis,
              style:TextStyle(fontSize:low?17:22,fontWeight:FontWeight.w900)),
            SizedBox(height:low?24:30,child:serving?Align(alignment:Alignment.centerLeft,child:Container(
              padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(
                color:const Color(0xff064e3b),borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xff047857))),
              child:Text('● SAQUE${s.table?"":" · ${s.total.isEven?"DER.":"IZQ."}"}',
                style:const TextStyle(fontSize:10,color:Color(0xff6ee7b7),fontWeight:FontWeight.bold)))):null),
            Expanded(child:Center(child:FittedBox(fit:BoxFit.contain,child:AnimatedSwitcher(
              duration:const Duration(milliseconds:180),child:Text(s.pointLabel(i),key:ValueKey(s.pointLabel(i)),
                style:TextStyle(fontSize:190,height:1,fontWeight:FontWeight.w900,fontFamily:'BarlowCondensed',
                  letterSpacing:-6,color:color,shadows:[Shadow(color:color.withValues(alpha:0.23),blurRadius:25)])))))),
            Center(child:Text(s.table||s.tie?'PUNTOS':'TANTEO',style:const TextStyle(color:muted,fontSize:10,letterSpacing:2))),
            const SizedBox(height:8),const Divider(color:Color(0xff1e293b),height:1),
            Padding(padding:const EdgeInsets.only(top:6),child:Row(children:[
              miniMetric(s.table?'PUNTOS DEL JUEGO':'JUEGOS',s.table?s.points[i]:s.games[i]),
              miniMetric(s.table?'JUEGOS GANADOS':'SETS',s.sets[i],color:const Color(0xfffbbf24)),
            ])),
          ])))))));
  }
  Widget toolbar(Score s,bool compact) => Container(color:const Color(0xff020617),
    padding:const EdgeInsets.symmetric(horizontal:12,vertical:3),child:Row(children:[
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
        Text('${config.label.toUpperCase()} · ${s.table?"A 11 PUNTOS":config.goldenPoint?"PUNTO DE ORO":"VENTAJAS"}',
          maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Color(0xffcbd5e1))),
        Text('${s.table?"Juego":"Set"} ${s.completed.length+(s.winner==null?1:0)} · ${s.completed.map((v)=>v.join("–")).join("  ")}'
          '${s.table?"":"  [${s.games.join("–")}]"}',maxLines:1,overflow:TextOverflow.ellipsis,
          style:const TextStyle(color:Color(0xfffbbf24),fontSize:11)),
      ])),
      IconButton(tooltip:'Repetir marcador',onPressed:()=>speak(s.winner==null?'${s.summary} Saca ${config.players[s.server]}.':'${s.summary} Ganador ${config.team(s.winner!)}.'),
        icon:const Icon(Icons.refresh,size:19,color:yellow)),
      IconButton(tooltip:'Invertir lados',onPressed:()=>setState(()=>swapped=!swapped),icon:const Icon(Icons.swap_horiz,size:20,color:cyan)),
      IconButton(tooltip:voice?'Silenciar voz':'Activar voz',onPressed:(){setState(()=>voice=!voice);save();if(!voice)call('stop');},
        icon:Icon(voice?Icons.volume_up:Icons.volume_off,size:19,color:voice?const Color(0xff34d399):muted)),
      IconButton(tooltip:'Pantalla completa',onPressed:toggleFullscreen,icon:Icon(fullscreen?Icons.fullscreen_exit:Icons.fullscreen,size:20)),
    ]));
  Widget status(Score s) {
    final text=s.winner!=null?'🏆 GANADOR · ${config.team(s.winner!)}':
      s.pressure.isNotEmpty?s.pressure:s.changeEnds?'Cambio de lado':
      'Saca ${config.players[s.server]}${s.table?" · Recibe ${config.players[s.receiver!]}":""}';
    return Container(width:double.infinity,color:const Color(0xff0f172a),padding:const EdgeInsets.symmetric(horizontal:12,vertical:5),
      child:Text(text,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center,
        style:TextStyle(color:s.winner!=null?yellow:muted,fontSize:12,fontWeight:FontWeight.w600)));
  }
  Widget dock(bool compact) => Container(color:const Color(0xff020617),padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
    child:Row(children:[
      OutlinedButton.icon(onPressed:ledger.isEmpty?null:undo,icon:const Icon(Icons.undo,size:17),label:const Text('Deshacer'),
        style:OutlinedButton.styleFrom(foregroundColor:const Color(0xfffcd34d),side:const BorderSide(color:Color(0xff78550d)))),
      if(!compact) Expanded(child:Padding(padding:const EdgeInsets.only(left:16),child:Text(remote?'● CONTROL ACTIVO · 1 clic = J1 · 2 clics = J2 · 3 = deshacer':'○ MODO TÁCTIL · activa el control en Diagnóstico BT',
        maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:muted)))),
      if(compact) const Spacer(),
      TextButton(onPressed:diagnostics,child:Text(compact?'Probar BT':'Probar Control',style:const TextStyle(color:muted,fontSize:12))),
    ]));
  @override Widget build(BuildContext context) {
    final s=score;
    return RepaintBoundary(key:const ValueKey('court-surface'),child:Scaffold(body:SafeArea(child:LayoutBuilder(builder:(ctx,size){
      final compact=size.maxWidth<700, low=size.maxHeight<500;
      return Column(children:[
        if(!fullscreen) header(compact),
        if(error!=null) Container(color:const Color(0xff7f1d1d),padding:const EdgeInsets.only(left:12),child:Row(children:[
          Expanded(child:Text(error!,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11))),
          IconButton(tooltip:'Cerrar aviso',onPressed:()=>setState(()=>error=null),icon:const Icon(Icons.close,size:16)),
        ])),
        if(!ready) const Expanded(child:Center(child:CircularProgressIndicator()))
        else ...[
          toolbar(s,compact),
          Expanded(child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
            panel(swapped?1:0,s,low),
            Container(width:5,color:const Color(0xff334155),child:const Center(child:RotatedBox(quarterTurns:1,
              child:Text('VS',style:TextStyle(fontSize:8,color:Color(0xff94a3b8)))))),
            panel(swapped?0:1,s,low),
          ])),
          status(s),dock(compact),
        ],
      ]);
    }))));
  }
}
