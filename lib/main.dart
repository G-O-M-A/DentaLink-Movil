import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentalink_movil/core/api.dart';
import 'package:dentalink_movil/core/tema.dart';
import 'package:dentalink_movil/features/auth/views/login_view.dart';
import 'package:dentalink_movil/features/home/views/home_view.dart';

Future<void> main() async {
  // 1. Asegurar la inicialización de los widgets de Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cargar las credenciales del archivo .env
  await dotenv.load(fileName: ".env");

  // 3. Inicializar Supabase. La app solo usa la clave publishable y las funciones movil_*
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  // 4. Si el paciente ya había iniciado sesión, entra directo (sin volver a escribir su contraseña)
  final conSesion = await Api.restaurarSesion();
  await cargarTema();

  runApp(MyApp(conSesion: conSesion));
}

class MyApp extends StatelessWidget {
  final bool conSesion;
  const MyApp({super.key, this.conSesion = false});

  @override
  Widget build(BuildContext context) {
    // Se reconstruye cuando el usuario cambia entre claro y oscuro
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: modoTema,
      builder: (context, modo, _) => MaterialApp(
        title: 'DentaLink Móvil',
        debugShowCheckedModeBanner: false,
        theme: temaDentaLink(Brightness.light),
        darkTheme: temaDentaLink(Brightness.dark),
        themeMode: modo,
        // Si la sesión guardada ya caducó, el inicio lo detecta y regresa al login
        home: conSesion ? const HomeView(nombre: '') : const LoginView(),
      ),
    );
  }
}
