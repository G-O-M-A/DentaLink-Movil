import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dentalink_movil/core/animaciones.dart';
import 'package:dentalink_movil/core/api.dart';
import 'package:dentalink_movil/core/tema.dart';
import 'package:dentalink_movil/features/home/views/home_view.dart';

/// Reagendar pregunta por pregunta, con barra de progreso:
/// 1) ¿Qué día?  2) ¿A qué hora? (botones; los ocupados en gris y tachados)  3) Revisa y confirma
/// La duración de la cita no cambia: la define la clínica.
class ReagendarView extends StatefulWidget {
  final Cita cita;
  final DateTime hoy;
  const ReagendarView({super.key, required this.cita, required this.hoy});

  @override
  State<ReagendarView> createState() => _ReagendarViewState();
}

class _ReagendarViewState extends State<ReagendarView> {
  static const int _primeraHora = 8 * 60; // 08:00
  static const int _ultimaHora = 19 * 60 + 30; // 19:30
  static const int _cada = 30; // minutos entre botones
  static const int _diasEnTira = 21;
  static const int _diasMaximo = 180;

  int _paso = 0; // 0 día · 1 hora · 2 resumen · 3 listo
  int _dir = 1;
  late final DateTime _hoy;
  late DateTime _fecha;
  bool _verCalendario = false;
  int? _hora;
  Horarios? _horarios;
  bool _cargandoHoras = false;
  bool _guardando = false;
  String? _errorHoras;
  Cita? _resultado;

  int get _duracion => widget.cita.duracion;

  @override
  void initState() {
    super.initState();
    _hoy = Fechas.soloDia(widget.hoy);
    final actual = Fechas.soloDia(widget.cita.dia);
    final ultimo = _hoy.add(const Duration(days: _diasMaximo));
    _fecha = actual.isBefore(_hoy) ? _hoy : (actual.isAfter(ultimo) ? ultimo : actual);
  }

  void _ir(int paso) {
    setState(() {
      _dir = paso > _paso ? 1 : -1;
      _paso = paso;
    });
    if (paso == 1) _cargarHoras();
  }

  void _elegirFecha(DateTime d) {
    HapticFeedback.selectionClick();
    setState(() {
      _fecha = Fechas.soloDia(d);
      _horarios = null; // otro día: otros horarios
    });
  }

  Future<void> _cargarHoras() async {
    setState(() {
      _cargandoHoras = true;
      _errorHoras = null;
    });
    try {
      final h = await Api.horarios(_fecha, excluir: widget.cita.id);
      if (!mounted) return;
      setState(() {
        _horarios = h;
        // Si la hora elegida ya no está libre, se pide de nuevo
        if (_hora != null && !_libre(_hora!)) _hora = null;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.sesionInvalida) return salirAlLogin(context, aviso: e.mensaje);
      setState(() => _errorHoras = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoHoras = false);
    }
  }

  bool _libre(int inicio) {
    final h = _horarios;
    if (h == null) return false;
    final fin = inicio + _duracion;
    if (fin > 21 * 60) return false;
    if (Fechas.mismoDia(_fecha, h.hoy) && inicio <= h.ahoraMin) return false;
    return !h.choca(inicio, fin);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final nueva = await Api.reagendar(widget.cita.id, _fecha, _hora!);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _resultado = nueva;
        _dir = 1;
        _paso = 3;
      });
      // Deja ver la palomita y regresa solo
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (mounted) Navigator.pop(context, nueva);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.sesionInvalida) return salirAlLogin(context, aviso: e.mensaje);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), backgroundColor: Paleta.peligro, behavior: SnackBarBehavior.floating),
      );
      if (e.codigo == 'HORARIO_OCUPADO' || e.codigo == 'FECHA_PASADA') {
        _hora = null;
        _ir(1); // regresa a elegir hora con los horarios actualizados
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    const total = 2; // preguntas antes del resumen
    final double progreso = _paso >= total ? 1.0 : (_paso / total).clamp(0.04, 1.0).toDouble();
    final falta = total - _paso;
    final textoPaso = _paso >= total ? '¡Listo! Revisa y confirma' : (falta == 1 ? 'Última pregunta' : 'Faltan $falta preguntas');
    final terminado = _paso == 3;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.fondo,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: p.texto,
        elevation: 0,
        leading: terminado
            ? const SizedBox.shrink()
            : IconButton(
                tooltip: _paso == 0 ? 'Cerrar' : 'Pregunta anterior',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(_paso == 0 ? Icons.close_rounded : Icons.arrow_back_rounded, key: ValueKey<bool>(_paso == 0)),
                ),
                onPressed: () {
                  if (_paso == 0) {
                    Navigator.pop(context);
                  } else {
                    _ir(_paso - 1);
                  }
                },
              ),
        title: const Text('Cambiar mi cita', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        bottom: terminado
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(38),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Align(
                                key: ValueKey<String>(textoPaso),
                                alignment: Alignment.centerLeft,
                                child: Text(textoPaso,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.texto)),
                              ),
                            ),
                          ),
                          Text('${(progreso * 100).round()}%', style: TextStyle(fontSize: 12, color: p.texto3)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(end: progreso),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: v,
                            minHeight: 8,
                            color: Paleta.primario,
                            backgroundColor: p.superficie2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: Offset(0.07 * _dir, 0), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey<int>(_paso),
            child: switch (_paso) {
              0 => _pasoDia(p),
              1 => _pasoHora(p),
              2 => _pasoResumen(p),
              _ => _pasoListo(p),
            },
          ),
        ),
      ),
    );
  }

  // ---------------- 1) Día ----------------
  Widget _pasoDia(Paleta p) {
    final ultimo = _hoy.add(const Duration(days: _diasMaximo));
    final dias = List<DateTime>.generate(_diasEnTira, (i) => _hoy.add(Duration(days: i)));
    final fueraDeTira = !dias.any((d) => Fechas.mismoDia(d, _fecha));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _pregunta(p, '¿Qué día te queda mejor?',
                    'Ahora es ${Fechas.larga(widget.cita.dia, hoy: _hoy)} a las ${widget.cita.horaInicio}.'),
              ),
              SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: dias.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _chipDia(p, dias[i]),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _verCalendario = !_verCalendario),
                      icon: AnimatedRotation(
                        turns: _verCalendario ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(Icons.expand_more_rounded),
                      ),
                      label: Text(_verCalendario ? 'Ocultar calendario' : 'Buscar otra fecha en el calendario'),
                      style: TextButton.styleFrom(foregroundColor: Paleta.primario),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: !_verCalendario
                          ? const SizedBox(width: double.infinity)
                          : Container(
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: p.superficie,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: p.linea),
                              ),
                              child: CalendarDatePicker(
                                key: ValueKey<String>(Fechas.iso(_fecha)), // se sincroniza con la tira de días
                                initialDate: _fecha,
                                firstDate: _hoy, // no se pueden elegir días pasados
                                lastDate: ultimo,
                                onDateChanged: _elegirFecha,
                              ),
                            ),
                    ),
                    if (fueraDeTira && !_verCalendario)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Etiqueta('Elegiste: ${Fechas.larga(_fecha, hoy: _hoy)}',
                            fondo: p.tinte, color: p.tinteTexto, icono: Icons.event_rounded),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _pie(p, 'Continuar · ${Fechas.relativa(_fecha, _hoy)}', () => _ir(1)),
      ],
    );
  }

  Widget _chipDia(Paleta p, DateTime d) {
    final sel = Fechas.mismoDia(d, _fecha);
    final esHoy = Fechas.mismoDia(d, _hoy);
    return Pulsable(
      alTocar: () => _elegirFecha(d),
      escala: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 62,
        decoration: BoxDecoration(
          color: sel ? Paleta.primario : p.superficie,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? Paleta.primario : (esHoy ? Paleta.primario : p.linea), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(esHoy ? 'hoy' : Fechas.diaSemanaCorto(d),
                style: TextStyle(fontSize: 12, color: sel ? const Color(0xE6FFFFFF) : p.texto2)),
            const SizedBox(height: 2),
            Text('${d.day}',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: sel ? Colors.white : p.texto, height: 1.1)),
            Text(Fechas.mesCorto(d), style: TextStyle(fontSize: 11, color: sel ? const Color(0xCCFFFFFF) : p.texto3)),
          ],
        ),
      ),
    );
  }

  // ---------------- 2) Hora ----------------
  Widget _pasoHora(Paleta p) {
    final horas = <int>[for (var m = _primeraHora; m <= _ultimaHora; m += _cada) m];
    final manana = horas.where((m) => m < 12 * 60).toList();
    final tarde = horas.where((m) => m >= 12 * 60).toList();

    Widget contenido;
    if (_horarios == null && _errorHoras == null) {
      contenido = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List<Widget>.generate(12, (_) => const Esqueleto(alto: 46, ancho: 76, radio: 12)),
      );
    } else if (_errorHoras != null) {
      contenido = Column(
        children: [
          Text(_errorHoras!, textAlign: TextAlign.center, style: TextStyle(color: p.texto2)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _cargarHoras, child: const Text('Reintentar')),
        ],
      );
    } else {
      final libres = horas.where(_libre).length;
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (libres == 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: p.avisoFondo, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  Icon(Icons.event_busy_rounded, color: p.avisoTexto),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Ese día ya no hay horarios libres. Regresa y elige otro día.',
                        style: TextStyle(color: p.avisoTexto, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
          _grupoHoras(p, Icons.wb_sunny_outlined, 'Mañana', manana, 0),
          const SizedBox(height: 18),
          _grupoHoras(p, Icons.wb_twilight_rounded, 'Tarde', tarde, manana.length),
          const SizedBox(height: 16),
          Row(
            children: [
              _leyenda(p, p.superficie, p.lineaFuerte, 'Libre'),
              const SizedBox(width: 16),
              _leyenda(p, p.superficie2, p.linea, 'Ocupado', tachado: true),
              const SizedBox(width: 16),
              _leyenda(p, Paleta.primario, Paleta.primario, 'Elegido'),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              _pregunta(p, '¿A qué hora?', '${Fechas.relativa(_fecha, _hoy)} · tu cita dura $_duracion minutos.'),
              AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(
                key: ValueKey<String>('${_horarios == null}-${_errorHoras != null}'),
                child: contenido,
              )),
            ],
          ),
        ),
        _pie(p, _hora == null ? 'Elige una hora' : 'Continuar · ${Fechas.hhmm(_hora!)} h',
            _hora == null ? null : () => _ir(2)),
      ],
    );
  }

  Widget _grupoHoras(Paleta p, IconData icono, String titulo, List<int> horas, int desfase) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: p.texto2),
              const SizedBox(width: 6),
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, color: p.texto2, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < horas.length; i++) Aparecer(orden: (desfase + i) ~/ 2, desplazamiento: 8, child: _botonHora(p, horas[i])),
            ],
          ),
        ],
      );

  Widget _botonHora(Paleta p, int m) {
    final libre = _libre(m);
    final sel = _hora == m;
    return Pulsable(
      escala: 0.92,
      alTocar: libre
          ? () {
              setState(() => _hora = m);
              Future<void>.delayed(const Duration(milliseconds: 220), () {
                if (mounted && _paso == 1 && _hora == m) _ir(2);
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 76,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? Paleta.primario : (libre ? p.superficie : p.superficie2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? Paleta.primario : (libre ? p.lineaFuerte : p.linea), width: 1.5),
        ),
        child: Text(
          Fechas.hhmm(m),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: sel ? Colors.white : (libre ? p.texto : p.texto3),
            decoration: libre ? TextDecoration.none : TextDecoration.lineThrough,
          ),
        ),
      ),
    );
  }

  Widget _leyenda(Paleta p, Color fondo, Color borde, String texto, {bool tachado = false}) => Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borde, width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(texto,
              style: TextStyle(
                fontSize: 12,
                color: p.texto2,
                decoration: tachado ? TextDecoration.lineThrough : TextDecoration.none,
              )),
        ],
      );

  // ---------------- 3) Resumen ----------------
  Widget _pasoResumen(Paleta p) {
    final c = widget.cita;
    final fin = _hora! + _duracion;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              _pregunta(p, 'Revisa el cambio', 'Si algo no es correcto, toca “Cambiar”.'),
              Aparecer(
                child: Container(
                  decoration: BoxDecoration(
                    color: p.superficie,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.linea),
                  ),
                  child: Column(
                    children: [
                      _filaResumen(p, Icons.event_rounded, 'Día', Fechas.relativa(_fecha, _hoy), alCambiar: () => _ir(0)),
                      Divider(height: 1, color: p.linea),
                      _filaResumen(p, Icons.schedule_rounded, 'Hora', '${Fechas.hhmm(_hora!)} a ${Fechas.hhmm(fin)} h',
                          alCambiar: () => _ir(1)),
                      Divider(height: 1, color: p.linea),
                      _filaResumen(p, Icons.medical_services_outlined, 'Motivo', c.motivo),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Aparecer(
                orden: 2,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: p.superficie2, borderRadius: BorderRadius.circular(14)),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 18, color: p.texto3),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Antes: ${Fechas.larga(c.dia, hoy: _hoy)}, ${c.horaInicio} h',
                          style: TextStyle(color: p.texto2, fontSize: 13, decoration: TextDecoration.lineThrough),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        _pie(p, 'Confirmar cambio', _guardando ? null : _guardar, cargando: _guardando),
      ],
    );
  }

  Widget _filaResumen(Paleta p, IconData icono, String etiqueta, String valor, {VoidCallback? alCambiar}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            Icon(icono, size: 20, color: Paleta.primario),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta, style: TextStyle(fontSize: 12, color: p.texto2)),
                  const SizedBox(height: 2),
                  Text(valor, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.texto)),
                ],
              ),
            ),
            if (alCambiar != null)
              TextButton(
                onPressed: alCambiar,
                style: TextButton.styleFrom(foregroundColor: Paleta.primario),
                child: const Text('Cambiar'),
              ),
          ],
        ),
      );

  // ---------------- Listo ----------------
  Widget _pasoListo(Paleta p) {
    final r = _resultado;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PalomitaExito(),
            const SizedBox(height: 20),
            Aparecer(
              orden: 2,
              child: Text('¡Cita actualizada!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: p.texto)),
            ),
            if (r != null)
              Aparecer(
                orden: 3,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${Fechas.relativa(r.dia, _hoy)}, ${r.horaInicio} a ${r.horaFin} h',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.texto2, fontSize: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- Comunes ----------------
  Widget _pregunta(Paleta p, String titulo, String ayuda) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: p.texto)),
            const SizedBox(height: 4),
            Text(ayuda, style: TextStyle(color: p.texto2, fontSize: 14)),
          ],
        ),
      );

  Widget _pie(Paleta p, String texto, VoidCallback? alTocar, {bool cargando = false}) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(color: p.fondo, border: Border(top: BorderSide(color: p.linea))),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: alTocar,
            style: FilledButton.styleFrom(
              backgroundColor: Paleta.primario,
              foregroundColor: Colors.white,
              disabledBackgroundColor: p.superficie2,
              disabledForegroundColor: p.texto3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: cargando
                  ? const SizedBox(
                      key: ValueKey('cargando'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(texto, key: ValueKey<String>(texto)),
            ),
          ),
        ),
      );
}
