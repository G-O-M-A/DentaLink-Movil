import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo claro/oscuro de toda la app. Por defecto sigue al sistema del celular.
final ValueNotifier<ThemeMode> modoTema = ValueNotifier<ThemeMode>(ThemeMode.system);

const String _claveTema = 'dentalink_tema';

/// Recupera el modo que eligió el usuario la última vez.
Future<void> cargarTema() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString(_claveTema);
    if (t == 'claro') modoTema.value = ThemeMode.light;
    if (t == 'oscuro') modoTema.value = ThemeMode.dark;
  } catch (_) {
    // Sin preferencia guardada: sigue al sistema
  }
}

Future<void> _guardarTema(ThemeMode modo) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveTema, modo == ThemeMode.dark ? 'oscuro' : 'claro');
  } catch (_) {}
}

/// Paleta de DentaLink (la misma que la web).
/// Cian #00A5C4 · Menta #E0F7F1 · Gris azulado #5A6B7C
class Paleta {
  static const Color primario = Color(0xFF00A5C4);
  static const Color primarioHover = Color(0xFF008FA9);
  static const Color menta = Color(0xFFE0F7F1);
  static const Color grisAzul = Color(0xFF5A6B7C);
  static const Color ok = Color(0xFF10B981);
  static const Color peligro = Color(0xFFD95C5C);
  static const Color aviso = Color(0xFFF59E0B);

  final bool oscuro;
  const Paleta._(this.oscuro);

  static Paleta of(BuildContext context) => Paleta._(Theme.of(context).brightness == Brightness.dark);

  Color get fondo => oscuro ? const Color(0xFF0D1418) : const Color(0xFFF5F7F8);
  Color get superficie => oscuro ? const Color(0xFF141D23) : Colors.white;
  Color get superficie2 => oscuro ? const Color(0xFF1A252C) : const Color(0xFFF5F7F8);
  Color get linea => oscuro ? const Color(0xFF26343C) : const Color(0xFFE2E8EC);
  Color get lineaFuerte => oscuro ? const Color(0xFF36464F) : const Color(0xFFCBD5DC);
  Color get texto => oscuro ? const Color(0xFFE8EEF2) : const Color(0xFF1E293B);
  Color get texto2 => oscuro ? const Color(0xFF9DB0BD) : grisAzul;
  Color get texto3 => oscuro ? const Color(0xFF70848F) : const Color(0xFF8896A3);
  Color get tinte => oscuro ? const Color(0x2900A5C4) : menta;
  Color get tinteTexto => oscuro ? const Color(0xFF4FD1E8) : const Color(0xFF00778D);
  Color get okFondo => oscuro ? const Color(0x2910B981) : menta;
  Color get okTexto => oscuro ? const Color(0xFF34D399) : const Color(0xFF047857);
  Color get peligroFondo => oscuro ? const Color(0x2ED95C5C) : const Color(0xFFFDECEC);
  Color get peligroTexto => oscuro ? const Color(0xFFF08A8A) : const Color(0xFFB83E3E);
  Color get avisoFondo => oscuro ? const Color(0x29F59E0B) : const Color(0xFFFEF3C7);
  Color get avisoTexto => oscuro ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
}

ThemeData temaDentaLink(Brightness brillo) {
  final oscuro = brillo == Brightness.dark;
  final esquema = ColorScheme.fromSeed(seedColor: Paleta.primario, brightness: brillo).copyWith(
    primary: Paleta.primario,
    onPrimary: Colors.white,
    surface: oscuro ? const Color(0xFF141D23) : Colors.white,
    onSurface: oscuro ? const Color(0xFFE8EEF2) : const Color(0xFF1E293B),
    error: Paleta.peligro,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brillo,
    colorScheme: esquema,
    scaffoldBackgroundColor: oscuro ? const Color(0xFF0D1418) : const Color(0xFFF5F7F8),
  );
}

/// Botón sol/luna para cambiar entre claro y oscuro.
class BotonTema extends StatelessWidget {
  final Color? color;
  const BotonTema({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: oscuro ? 'Modo claro' : 'Modo oscuro',
      color: color,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          oscuro ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey<bool>(oscuro),
        ),
      ),
      onPressed: () {
        final nuevo = oscuro ? ThemeMode.light : ThemeMode.dark;
        modoTema.value = nuevo;
        _guardarTema(nuevo);
      },
    );
  }
}

/// Etiqueta pequeña de color (estado de una cita, "Más reciente", etc.)
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;
  const Etiqueta(this.texto, {super.key, required this.fondo, required this.color, this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(texto, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
