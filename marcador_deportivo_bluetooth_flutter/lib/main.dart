import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'views/scoreboard_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mantener la pantalla encendida de forma permanente
  await WakelockPlus.enable();
  
  // Forzar orientación horizontal recomendada para cancha
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);

  runApp(const MarcadorApp());
}

class MarcadorApp extends StatelessWidget {
  const MarcadorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Marcador Deportivo BT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE2F952), // Amarillo neón pista
          secondary: Color(0xFF38BDF8), // Azul cian
          surface: Color(0xFF131B2A),
        ),
      ),
      home: const ScoreboardPage(),
    );
  }
}
