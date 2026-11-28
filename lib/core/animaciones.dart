import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dentalink_movil/core/tema.dart';

// Todas las animaciones mueven solo opacidad, posición y escala:
// son las más baratas de dibujar y se ven fluidas en cualquier celular.
// Si el celular tiene activado "quitar animaciones", se respetan.

bool _sinAnimaciones(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Transición entre pantallas: desvanece y desliza un poco (en lugar del salto brusco).
Route<T> rutaSuave<T>(Widget pagina) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (context, animation, secondaryAnimation) => pagina,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
            child: child,
          ),
        );
      },
    );

/// Aparece desvaneciéndose y subiendo un poco. `orden` escalona varios elementos.
class Aparecer extends StatefulWidget {
  final Widget child;
  final int orden;
  final double desplazamiento;
  const Aparecer({super.key, required this.child, this.orden = 0, this.desplazamiento = 18});

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _espera;

  @override
  void initState() {
    super.initState();
    final retraso = Duration(milliseconds: 60 * widget.orden.clamp(0, 10));
    if (retraso == Duration.zero) {
      _c.forward();
    } else {
      _espera = Timer(retraso, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _espera?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sinAnimaciones(context)) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _a.value,
        child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.desplazamiento), child: child),
      ),
    );
  }
}

/// Se encoge un poco al presionarlo y vibra suave al soltar: se siente "tocable".
class Pulsable extends StatefulWidget {
  final Widget child;
  final VoidCallback? alTocar;
  final double escala;
  const Pulsable({super.key, required this.child, this.alTocar, this.escala = 0.97});

  @override
  State<Pulsable> createState() => _PulsableState();
}

class _PulsableState extends State<Pulsable> {
  bool _abajo = false;

  void _poner(bool v) {
    if (_abajo != v) setState(() => _abajo = v);
  }

  @override
  Widget build(BuildContext context) {
    final activo = widget.alTocar != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: activo ? (_) => _poner(true) : null,
      onTapUp: activo ? (_) => _poner(false) : null,
      onTapCancel: activo ? () => _poner(false) : null,
      onTap: activo
          ? () {
              HapticFeedback.selectionClick();
              widget.alTocar!();
            }
          : null,
      child: AnimatedScale(
        scale: _abajo ? widget.escala : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Bloque gris que "respira" mientras carga (en lugar de una ruedita).
class Esqueleto extends StatefulWidget {
  final double alto;
  final double? ancho;
  final double radio;
  const Esqueleto({super.key, required this.alto, this.ancho, this.radio = 16});

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: Container(
        height: widget.alto,
        width: widget.ancho,
        decoration: BoxDecoration(color: p.superficie2, borderRadius: BorderRadius.circular(widget.radio)),
      ),
    );
  }
}

/// Sacude el contenido de lado a lado cada vez que cambia `disparo` (por ejemplo, un error).
class Sacudir extends StatelessWidget {
  final int disparo;
  final Widget child;
  const Sacudir({super.key, required this.disparo, required this.child});

  @override
  Widget build(BuildContext context) {
    if (disparo == 0 || _sinAnimaciones(context)) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(disparo),
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      child: child,
      builder: (context, v, child) => Transform.translate(
        offset: Offset(math.sin(v * math.pi * 4) * (1 - v) * 10, 0),
        child: child,
      ),
    );
  }
}

/// Palomita que aparece con un pequeño rebote (éxito).
class PalomitaExito extends StatelessWidget {
  final double tamano;
  const PalomitaExito({super.key, this.tamano = 88});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(color: p.okFondo, shape: BoxShape.circle),
        child: Icon(Icons.check_rounded, size: tamano * 0.55, color: p.okTexto),
      ),
    );
  }
}
