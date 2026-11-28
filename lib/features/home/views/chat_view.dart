import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dentalink_movil/core/animaciones.dart';
import 'package:dentalink_movil/core/api.dart';
import 'package:dentalink_movil/core/tema.dart';
import 'package:dentalink_movil/features/home/views/home_view.dart';

/// Chat del paciente con su clínica (misma conversación que ve la web en "Mensajes").
/// Se actualiza solo cada 3 segundos mientras la app está abierta.
class ChatView extends StatefulWidget {
  final String? clinica;

  /// Se llama cuando los mensajes de la clínica quedan leídos (para quitar la bolita roja).
  final VoidCallback? alLeer;

  const ChatView({super.key, this.clinica, this.alLeer});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  static const int _maxTexto = 2000;

  final List<Mensaje> _mensajes = [];
  final Set<int> _ids = <int>{};
  final TextEditingController _texto = TextEditingController();
  final FocusNode _foco = FocusNode();

  int _ultimoId = 0;
  int _leidoHasta = 0;
  int _idInicial = 0; // los mensajes posteriores a este entran animados
  int _temporal = 0;
  bool _cargando = true;
  bool _revisando = false;
  bool _enPrimerPlano = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _texto.addListener(() => setState(() {})); // activa/desactiva el botón de enviar
    _cargar();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _revisar());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _texto.dispose();
    _foco.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No consulta mientras la app está en segundo plano; al volver, revisa al instante
    _enPrimerPlano = state == AppLifecycleState.resumed;
    if (_enPrimerPlano) _revisar();
  }

  void _agregar(List<Mensaje> nuevos) {
    for (final m in nuevos) {
      if (_ids.add(m.id)) _mensajes.add(m);
      if (m.id > _ultimoId) _ultimoId = m.id;
    }
    // Los que se están enviando (id negativo) siempre al final
    _mensajes.sort((a, b) {
      if (a.pendiente != b.pendiente) return a.pendiente ? 1 : -1;
      return a.pendiente ? 0 : a.id.compareTo(b.id);
    });
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await Api.mensajes();
      if (!mounted) return;
      setState(() {
        _agregar(d.mensajes);
        _leidoHasta = d.leidoHasta;
        _idInicial = _ultimoId;
      });
      widget.alLeer?.call();
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.sesionInvalida) return salirAlLogin(context, aviso: e.mensaje);
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _revisar() async {
    if (_revisando || _cargando || !_enPrimerPlano || !mounted) return;
    _revisando = true;
    try {
      final d = await Api.mensajes(despues: _ultimoId);
      if (!mounted) return;
      final deClinica = d.mensajes.any((m) => !m.mio);
      if (d.mensajes.isNotEmpty || d.leidoHasta != _leidoHasta) {
        setState(() {
          _agregar(d.mensajes);
          _leidoHasta = d.leidoHasta;
        });
      }
      if (deClinica) {
        HapticFeedback.lightImpact();
        widget.alLeer?.call();
      }
    } on ApiError catch (e) {
      if (mounted && e.sesionInvalida) salirAlLogin(context, aviso: e.mensaje);
      // Sin conexión: se reintenta en el siguiente ciclo
    } finally {
      _revisando = false;
    }
  }

  Future<void> _enviar() async {
    final t = _texto.text.trim();
    if (t.isEmpty) return;
    HapticFeedback.selectionClick();
    final temporal = Mensaje(
      id: -(++_temporal),
      remitente: 'paciente',
      texto: t,
      fecha: DateTime.now(),
      pendiente: true,
    );
    setState(() {
      _mensajes.add(temporal);
      _texto.clear();
    });
    try {
      final m = await Api.enviarMensaje(t);
      if (!mounted) return;
      setState(() {
        _mensajes.remove(temporal);
        _agregar([m]);
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.sesionInvalida) return salirAlLogin(context, aviso: e.mensaje);
      setState(() {
        _mensajes.remove(temporal);
        if (_texto.text.isEmpty) _texto.text = t; // devuelve el texto para reintentar
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensaje), backgroundColor: Paleta.peligro, behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    return Column(
      children: [
        _encabezado(p),
        Expanded(child: _cuerpo(p)),
        _redactor(p),
      ],
    );
  }

  Widget _encabezado(Paleta p) => Container(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        decoration: BoxDecoration(color: p.fondo, border: Border(bottom: BorderSide(color: p.linea))),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: p.tinte, shape: BoxShape.circle),
              child: Icon(Icons.local_hospital_outlined, color: p.tinteTexto, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.clinica ?? 'Mi clínica',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: p.texto)),
                  Text('Chat con tu clínica', style: TextStyle(color: p.texto2, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _cuerpo(Paleta p) {
    if (_cargando && _mensajes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          Align(alignment: Alignment.centerLeft, child: Esqueleto(alto: 44, ancho: 210)),
          SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: Esqueleto(alto: 44, ancho: 170)),
          SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: Esqueleto(alto: 64, ancho: 240)),
        ],
      );
    }
    if (_error != null && _mensajes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: p.lineaFuerte),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: p.texto2)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (_mensajes.isEmpty) {
      return Center(
        child: Aparecer(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: p.tinte, shape: BoxShape.circle),
                  child: Icon(Icons.chat_bubble_outline_rounded, size: 38, color: p.tinteTexto),
                ),
                const SizedBox(height: 16),
                Text('Escríbele a tu clínica',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.texto)),
                const SizedBox(height: 6),
                Text(
                  'Pregunta por tus citas, los cuidados después de un tratamiento o cualquier duda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.texto2, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Lista invertida: lo más nuevo abajo y pegado al teclado, como en WhatsApp
    final items = <Object>[]; // DateTime = separador de día, Mensaje = burbuja
    DateTime? diaAnterior;
    for (final m in _mensajes) {
      final dia = Fechas.soloDia(m.fecha);
      if (diaAnterior == null || dia != diaAnterior) {
        items.add(dia);
        diaAnterior = dia;
      }
      items.add(m);
    }
    final invertidos = items.reversed.toList();

    return GestureDetector(
      onTap: () => _foco.unfocus(),
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        itemCount: invertidos.length,
        itemBuilder: (context, i) {
          final item = invertidos[i];
          if (item is DateTime) return _separador(p, item);
          final m = item as Mensaje;
          // Burbujas seguidas del mismo lado van más juntas (en la lista invertida, el de arriba es i + 1)
          final anterior = i + 1 < invertidos.length ? invertidos[i + 1] : null;
          final pegado = anterior is Mensaje && anterior.mio == m.mio;
          final burbuja = _burbuja(p, m, pegado);
          final nuevo = m.pendiente || m.id > _idInicial;
          return nuevo ? Aparecer(key: ValueKey<int>(m.id), desplazamiento: 10, child: burbuja) : burbuja;
        },
      ),
    );
  }

  Widget _separador(Paleta p, DateTime dia) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: p.superficie,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.linea),
            ),
            child: Text(Fechas.separadorChat(dia),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.texto2)),
          ),
        ),
      );

  Widget _burbuja(Paleta p, Mensaje m, bool pegado) {
    final mio = m.mio;
    final ancho = MediaQuery.of(context).size.width * 0.78;
    const r = Radius.circular(16);
    const pico = Radius.circular(4);

    Widget? estado;
    if (mio) {
      if (m.pendiente) {
        estado = Icon(Icons.schedule_rounded, size: 13, color: p.texto3);
      } else if (m.id <= _leidoHasta) {
        estado = const Icon(Icons.done_all_rounded, size: 15, color: Color(0xFF34B7F1));
      } else {
        estado = Icon(Icons.done_rounded, size: 15, color: p.texto3);
      }
    }

    return Padding(
      padding: EdgeInsets.only(top: pegado ? 2 : 8),
      child: Align(
        alignment: mio ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: ancho),
          child: AnimatedOpacity(
            opacity: m.pendiente ? 0.7 : 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
              decoration: BoxDecoration(
                color: mio ? p.tinte : p.superficie,
                border: mio ? null : Border.all(color: p.linea),
                borderRadius: BorderRadius.only(
                  topLeft: !mio && !pegado ? pico : r,
                  topRight: mio && !pegado ? pico : r,
                  bottomLeft: r,
                  bottomRight: r,
                ),
              ),
              // IntrinsicWidth: la burbuja mide lo que el texto (o la hora), no todo el ancho
              child: IntrinsicWidth(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.texto, style: TextStyle(fontSize: 15, color: p.texto, height: 1.35)),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(Fechas.hora(m.fecha), style: TextStyle(fontSize: 11, color: p.texto3)),
                      if (estado != null) ...[const SizedBox(width: 4), estado],
                    ],
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _redactor(Paleta p) {
    final hayTexto = _texto.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(color: p.superficie, border: Border(top: BorderSide(color: p.linea))),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _texto,
                focusNode: _foco,
                minLines: 1,
                maxLines: 5,
                maxLength: _maxTexto,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: p.texto, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje',
                  hintStyle: TextStyle(color: p.texto3),
                  counterText: '',
                  filled: true,
                  fillColor: p.superficie2,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Paleta.primario, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: hayTexto ? 1 : 0.85,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: hayTexto ? 1 : 0.45,
                duration: const Duration(milliseconds: 180),
                child: Material(
                  color: Paleta.primario,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: hayTexto ? _enviar : null,
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 21),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
