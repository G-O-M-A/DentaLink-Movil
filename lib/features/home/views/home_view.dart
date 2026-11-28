import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dentalink_movil/core/animaciones.dart';
import 'package:dentalink_movil/core/api.dart';
import 'package:dentalink_movil/core/tema.dart';
import 'package:dentalink_movil/features/auth/views/login_view.dart';
import 'package:dentalink_movil/features/home/views/appointment_history_view.dart';
import 'package:dentalink_movil/features/home/views/chat_view.dart';
import 'package:dentalink_movil/features/home/views/prescriptions_view.dart';
import 'package:dentalink_movil/features/home/views/reschedule_view.dart';

/// Cierra la sesión y regresa al login (también cuando el token caduca).
Future<void> salirAlLogin(BuildContext context, {String? aviso}) async {
  await Api.logout();
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  Navigator.of(context).pushAndRemoveUntil(rutaSuave(const LoginView()), (_) => false);
  if (aviso != null) messenger.showSnackBar(SnackBar(content: Text(aviso), behavior: SnackBarBehavior.floating));
}

class HomeView extends StatefulWidget {
  final String nombre;
  const HomeView({super.key, required this.nombre});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  // Pestañas: 0 Inicio · 1 Mensajes · 2 Recetas
  int _tab = 0;
  Inicio? _datos;
  String? _error;
  int _noLeidos = 0;
  Timer? _timerMensajes;

  @override
  void initState() {
    super.initState();
    _cargar();
    _revisarMensajes();
    // Bolita roja: revisa cada 10 s si la clínica escribió (fuera del chat)
    _timerMensajes = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_tab != 1) _revisarMensajes();
    });
  }

  @override
  void dispose() {
    _timerMensajes?.cancel();
    super.dispose();
  }

  Future<void> _revisarMensajes() async {
    try {
      final n = await Api.noLeidos();
      if (!mounted || n == _noLeidos) return;
      if (n > _noLeidos && _noLeidos >= 0 && _tab != 1) HapticFeedback.lightImpact();
      setState(() => _noLeidos = n);
    } on ApiError {
      // Sin conexión o sesión vencida: las otras pantallas se encargan del aviso
    }
  }

  void _irA(int tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = tab);
    if (tab != 1) _revisarMensajes();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final d = await Api.inicio();
      if (mounted) setState(() => _datos = d);
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.sesionInvalida) return salirAlLogin(context, aviso: e.mensaje);
      setState(() => _error = e.mensaje);
    }
  }

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
  }

  Future<void> _reagendar(Cita c) async {
    final nueva = await Navigator.push<Cita>(context, rutaSuave<Cita>(ReagendarView(cita: c, hoy: _datos!.hoy)));
    if (nueva == null || !mounted) return;
    await _cargar();
    if (!mounted) return;
    _aviso('Listo: tu cita quedó para ${Fechas.relativa(nueva.dia, _datos!.hoy).toLowerCase()} a las ${nueva.horaInicio}.');
  }

  void _verClinica() {
    final d = _datos;
    if (d == null || d.clinica == null) return;
    final p = Paleta.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: p.superficie,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(d.clinica!, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: p.texto)),
              const SizedBox(height: 4),
              Text('Tu clínica', style: TextStyle(color: p.texto2)),
              const SizedBox(height: 18),
              if ((d.clinicaTelefono ?? '').isNotEmpty)
                _datoClinica(p, Icons.phone_outlined, d.clinicaTelefono!, copiable: true),
              if ((d.clinicaDireccion ?? '').isNotEmpty) _datoClinica(p, Icons.place_outlined, d.clinicaDireccion!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datoClinica(Paleta p, IconData icono, String texto, {bool copiable = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.tinte, borderRadius: BorderRadius.circular(12)),
              child: Icon(icono, color: p.tinteTexto, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(texto, style: TextStyle(fontSize: 15, color: p.texto))),
            if (copiable)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: texto));
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                  _aviso('Teléfono copiado');
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copiar'),
                style: TextButton.styleFrom(foregroundColor: Paleta.primario),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: p.fondo,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: p.tinte, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.medical_services_outlined, color: p.tinteTexto, size: 20),
            ),
            const SizedBox(width: 10),
            Text('DentaLink', style: TextStyle(color: p.texto, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          BotonTema(color: p.texto2),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: Icon(Icons.logout_rounded, color: p.texto2),
            onPressed: () => salirAlLogin(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: Tween<double>(begin: 0.98, end: 1).animate(anim), child: child),
        ),
        child: switch (_tab) {
          1 => KeyedSubtree(
              key: const ValueKey('mensajes'),
              child: ChatView(
                clinica: _datos?.clinica,
                alLeer: () {
                  if (mounted && _noLeidos != 0) setState(() => _noLeidos = 0);
                },
              ),
            ),
          2 => const KeyedSubtree(key: ValueKey('recetas'), child: PrescriptionsView()),
          _ => KeyedSubtree(key: const ValueKey('inicio'), child: _inicio(p)),
        },
      ),
      // En el chat, con el teclado abierto, se oculta la barra para dar espacio a los mensajes
      bottomNavigationBar: _tab == 1 && MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _irA,
              backgroundColor: p.superficie,
              indicatorColor: p.tinte,
              animationDuration: const Duration(milliseconds: 400),
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: _noLeidos > 0,
                    label: Text(_noLeidos > 99 ? '99+' : '$_noLeidos'),
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  selectedIcon: const Icon(Icons.chat_bubble_rounded),
                  label: 'Mensajes',
                ),
                const NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Recetas'),
              ],
            ),
    );
  }

  // =================== Pestaña Inicio ===================

  Widget _inicio(Paleta p) {
    final d = _datos;

    if (d == null && _error == null) {
      // Esqueleto mientras carga
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Esqueleto(alto: 28, ancho: 180, radio: 8),
          SizedBox(height: 8),
          Esqueleto(alto: 16, ancho: 140, radio: 6),
          SizedBox(height: 22),
          Esqueleto(alto: 230, radio: 24),
          SizedBox(height: 24),
          Row(children: [
            Expanded(child: Esqueleto(alto: 104)),
            SizedBox(width: 12),
            Expanded(child: Esqueleto(alto: 104)),
            SizedBox(width: 12),
            Expanded(child: Esqueleto(alto: 104)),
          ]),
        ],
      );
    }

    if (d == null) {
      return Center(
        child: Aparecer(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 52, color: p.lineaFuerte),
                const SizedBox(height: 12),
                Text('No se pudo cargar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: p.texto)),
                const SizedBox(height: 6),
                Text(_error ?? '', textAlign: TextAlign.center, style: TextStyle(color: p.texto2)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _cargar,
                  style: FilledButton.styleFrom(backgroundColor: Paleta.primario),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final proxima = d.proxima;
    final nombre = d.nombre.isNotEmpty ? d.nombre : widget.nombre;
    final hoyTxt = Fechas.larga(d.hoy, hoy: d.hoy);
    final despues = d.citas
        .where((c) => c.pendiente && c.id != d.proximaId && !c.dia.isBefore(Fechas.soloDia(d.hoy)))
        .toList()
      ..sort((a, b) => '${a.fecha} ${a.horaInicio}'.compareTo('${b.fecha} ${b.horaInicio}'));

    return RefreshIndicator(
      color: Paleta.primario,
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Aparecer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¡Hola, $nombre!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: p.texto)),
                const SizedBox(height: 2),
                Text(hoyTxt[0].toUpperCase() + hoyTxt.substring(1), style: TextStyle(color: p.texto2, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Aparecer(orden: 1, child: proxima != null ? _tarjetaProxima(p, proxima, d.hoy) : _sinProxima(p)),
          const SizedBox(height: 26),
          Aparecer(
            orden: 2,
            child: Text('Accesos rápidos', style: TextStyle(fontWeight: FontWeight.w600, color: p.texto2, fontSize: 13.5)),
          ),
          const SizedBox(height: 10),
          Aparecer(
            orden: 3,
            child: Row(
              children: [
                Expanded(
                  child: _acceso(
                    p,
                    Icons.history_rounded,
                    'Historial',
                    d.citas.isEmpty ? 'Sin citas' : '${d.citas.length} ${d.citas.length == 1 ? 'cita' : 'citas'}',
                    () => Navigator.push(context, rutaSuave(AppointmentHistoryView(citas: d.citas, hoy: d.hoy))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _acceso(
                    p,
                    Icons.chat_bubble_outline_rounded,
                    'Mensajes',
                    _noLeidos > 0 ? '$_noLeidos sin leer' : 'Escríbenos',
                    () => _irA(1),
                    aviso: _noLeidos,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _acceso(
                    p,
                    Icons.local_hospital_outlined,
                    'Mi clínica',
                    d.clinica ?? 'Sin datos',
                    d.clinica == null ? null : _verClinica,
                  ),
                ),
              ],
            ),
          ),
          if (despues.isNotEmpty) ...[
            const SizedBox(height: 26),
            Aparecer(
              orden: 4,
              child: Text('Después', style: TextStyle(fontWeight: FontWeight.w600, color: p.texto2, fontSize: 13.5)),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < despues.length && i < 3; i++)
              Aparecer(orden: 5 + i, child: _filaCita(p, despues[i], d.hoy)),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaProxima(Paleta p, Cita c, DateTime hoy) {
    final colores = p.oscuro
        ? const [Color(0xFF00839B), Color(0xFF00525F)]
        : const [Paleta.primario, Color(0xFF00778D)];
    final relativa = Fechas.relativa(c.dia, hoy);
    final larga = Fechas.larga(c.dia, hoy: hoy);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colores, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: p.oscuro ? null : const [BoxShadow(color: Color(0x3300A5C4), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Tu próxima cita',
                    style: TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0x33FFFFFF), borderRadius: BorderRadius.circular(999)),
                child: Text(Fechas.cuentaRegresiva(c.dia, hoy),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(relativa,
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.05)),
          if (relativa.length <= 6)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(larga, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 15)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text('${c.horaInicio} a ${c.horaFin} h',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.medical_services_outlined, size: 18, color: Color(0xE6FFFFFF)),
              const SizedBox(width: 8),
              Expanded(child: Text(c.motivo, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 15))),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _reagendar(c),
              icon: const Icon(Icons.edit_calendar_outlined, size: 19),
              label: const Text('Cambiar día u hora'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF00778D),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sinProxima(Paleta p) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: p.tinte, borderRadius: BorderRadius.circular(24)),
        child: Column(
          children: [
            Icon(Icons.event_available_rounded, size: 46, color: p.tinteTexto),
            const SizedBox(height: 10),
            Text('No tienes citas próximas',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: p.texto)),
            const SizedBox(height: 4),
            Text('Cuando tu clínica te agende una cita, aparecerá aquí.',
                textAlign: TextAlign.center, style: TextStyle(color: p.texto2, fontSize: 14)),
          ],
        ),
      );

  Widget _acceso(Paleta p, IconData icono, String titulo, String sub, VoidCallback? alTocar, {int aviso = 0}) =>
      Pulsable(
        alTocar: alTocar,
        child: Container(
          height: 112,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.superficie,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.linea),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Badge(
                isLabelVisible: aviso > 0,
                label: Text(aviso > 99 ? '99+' : '$aviso'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: p.tinte, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icono, color: p.tinteTexto, size: 20),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: p.texto)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.texto2, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _filaCita(Paleta p, Cita c, DateTime hoy) => Pulsable(
        alTocar: () => _reagendar(c),
        child: Container(
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
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(color: p.tinte, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text(Fechas.diaSemanaCorto(c.dia), style: TextStyle(fontSize: 11, color: p.tinteTexto)),
                    Text('${c.dia.day}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: p.tinteTexto, height: 1.1)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${c.horaInicio} a ${c.horaFin} h',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: p.texto)),
                    Text(c.motivo, style: TextStyle(color: p.texto2, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.texto3),
            ],
          ),
        ),
      );
}
