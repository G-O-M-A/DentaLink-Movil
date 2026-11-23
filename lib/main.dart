import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentalink_movil/features/auth/views/login_view.dart';

Future<void> main() async {
  // 1. Asegurar la inicialización de los widgets de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cargar las credenciales del archivo .env
  await dotenv.load(fileName: ".env");

  // 3. Inicializar Supabase usando las variables del .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dentalink Móvil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00A8B5)),
        useMaterial3: true,
      ),
      home: const LoginView(), 
    );
  }
}