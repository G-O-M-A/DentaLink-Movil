import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dentalink_movil/core/animaciones.dart';
import 'package:dentalink_movil/core/api.dart';
import 'package:dentalink_movil/core/tema.dart';

/// Historial de citas: selector animado "Próximas / Anteriores".
class AppointmentHistoryView extends StatefulWidget {
  final List<Cita> citas;
  final DateTime hoy;

  const AppointmentHistoryView({super.key, required this.citas, required this.hoy});

  @override
  State<AppointmentHistoryView> createState() => _AppointmentHistoryViewState();
}

class _AppointmentHistoryViewState extends State<AppointmentHistoryView> {
  late final DateTime _dia = Fechas.soloDia(widget.hoy);
  late final List<Cita> _proximas = widget.citas.where((c) => c.pendiente && !c.dia.isBefore(_dia)).toList()
    ..sort((a, b) => '${a.fecha} ${a.horaInicio}'.compareTo('${b.fecha} ${b.horaInicio}'));
  late final List<Cita> _anteriores = widget.citas.where((c) => !_proximas.contains(c)).toList()
    ..sort((a, b) => '${b.fecha} ${b.horaInicio}'.compareTo('${a.fecha} ${a.horaInicio}'));
  late int _vista = _proximas.isEmpty && _anteriores.isNotEmpty ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final lista = _vista == 0 ? _proximas : _anteriores;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.fondo,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: p.texto,
        elevation: 0,
        title: const Text('Mis citas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _Segmentos(
                opciones: ['Próximas · ${_proximas.length}', 'Anteriores · ${_anteriores.length}'],
                seleccion: _vista,
                alCambiar: (i) => setState(() => _vista = i),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: KeyedSubtree(
                  key: ValueKey<int>(_vista),
                  child: lista.isEmpty
                      ? _vacio(p)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          itemCount: lista.length,
                          itemBuilder: (context, i) => Aparecer(orden: i, child: _tarjeta(p, lista[i])),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vacio(Paleta p) => Center(
        child: Aparecer(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_vista == 0 ? Icons.event_available_rounded : Icons.history_rounded, size: 56, color: p.lineaFuerte),
                const SizedBox(height: 12),
                Text(_vista == 0 ? 'Sin citas próximas' : 'Sin citas anteriores',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.texto)),
                const SizedBox(height: 4),
                Text(
                  _vista == 0 ? 'Cuando tu clínica te agende una cita, aparecerá aquí.' : 'Aquí verás tus visitas pasadas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.texto2),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _tarjeta(Paleta p, Cita c) {
    final Etiqueta etiqueta;
    if (c.estado == 'Completada') {
      etiqueta = Etiqueta('Completada', fondo: p.okFondo, color: p.okTexto, icono: Icons.check_rounded);
    } else if (c.estado == 'Cancelada') {
      etiqueta = Etiqueta('Cancelada', fondo: p.peligroFondo, color: p.peligroTexto);
    } else if (c.dia.isBefore(_dia)) {
      etiqueta = Etiqueta('Sin atender', fondo: p.avisoFondo, color: p.avisoTexto);
    } else {
      etiqueta = Etiqueta(Fechas.cuentaRegresiva(c.dia, _dia), fondo: p.tinte, color: p.tinteTexto);
    }
    final cancelada = c.estado == 'Cancelada';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.superficie,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.linea),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: cancelada ? p.superficie2 : p.tinte,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(Fechas.mesCorto(c.dia), style: TextStyle(fontSize: 11, color: cancelada ? p.texto3 : p.tinteTexto)),
                Text('${c.dia.day}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                      color: cancelada ? p.texto3 : p.tinteTexto,
                    )),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fechas.relativa(c.dia, _dia)} · ${c.horaInicio} h',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: cancelada ? p.texto3 : p.texto,
                    decoration: cancelada ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 2),
                Text(c.motivo, style: TextStyle(color: p.texto2, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          etiqueta,
        ],
      ),
    );
  }
}

/// Selector de dos opciones con un fondo que se desliza a la opción elegida.
class _Segmentos extends StatelessWidget {
  final List<String> opciones;
  final int seleccion;
  final ValueChanged<int> alCambiar;
  const _Segmentos({required this.opciones, required this.seleccion, required this.alCambiar});

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.superficie2, borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: seleccion == 0 ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 1 / opciones.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: p.superficie,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: p.oscuro ? null : const [BoxShadow(color: Color(0x1A5A6B7C), blurRadius: 8, offset: Offset(0, 2))],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < opciones.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i == seleccion) return;
                      HapticFeedback.selectionClick();
                      alCambiar(i);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: i == seleccion ? p.tinteTexto : p.texto2,
                        ),
                        child: Text(opciones[i]),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
