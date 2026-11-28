import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dentalink_movil/core/animaciones.dart';
import 'package:dentalink_movil/core/api.dart';
import 'package:dentalink_movil/core/tema.dart';
import 'package:dentalink_movil/features/home/views/home_view.dart';

/// "Mis recetas": una sola lista, de la más reciente a la más antigua.
/// (Antes decía "receta actual / pasadas", pero una receta no caduca.)
/// Cada receta se abre y se cierra al tocarla; la más reciente aparece abierta.
class PrescriptionsView extends StatefulWidget {
  const PrescriptionsView({super.key});

  @override
  State<PrescriptionsView> createState() => _PrescriptionsViewState();
}

class _PrescriptionsViewState extends State<PrescriptionsView> {
  // Se conserva al cambiar de pestaña para que aparezca al instante
  static List<Receta>? _cache;

  List<Receta>? _recetas = _cache;
  String? _error;
  final Set<int> _abiertas = <int>{};

  @override
  void initState() {
    super.initState();
    if (_recetas != null && _recetas!.isNotEmpty) _abiertas.add(_recetas!.first.id);
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final r = await Api.recetas();
      _cache = r;
      if (!mounted) return;
      setState(() {
        if (_recetas == null && r.isNotEmpty) _abiertas.add(r.first.id);
        _recetas = r;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      if (e.sesionInvalida) {
        _cache = null;
        return salirAlLogin(context, aviso: e.mensaje);
      }
      setState(() => _error = e.mensaje);
    }
  }

  void _alternar(int id) {
    HapticFeedback.selectionClick();
    setState(() => _abiertas.contains(id) ? _abiertas.remove(id) : _abiertas.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);
    final recetas = _recetas;

    final List<Widget> contenido;
    if (recetas == null && _error == null) {
      contenido = const [
        Esqueleto(alto: 92),
        SizedBox(height: 12),
        Esqueleto(alto: 92),
        SizedBox(height: 12),
        Esqueleto(alto: 92),
      ];
    } else if (recetas == null) {
      contenido = [_mensaje(p, Icons.wifi_off_rounded, 'No se pudieron cargar', _error ?? '', accion: true)];
    } else if (recetas.isEmpty) {
      contenido = [
        _mensaje(p, Icons.receipt_long_outlined, 'Aún no tienes recetas', 'Cuando tu doctor te recete algo, aparecerá aquí.'),
      ];
    } else {
      contenido = [
        for (var i = 0; i < recetas.length; i++) Aparecer(orden: i + 1, child: _tarjeta(p, recetas[i], i == 0)),
      ];
    }

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
                Text('Mis recetas', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: p.texto)),
                const SizedBox(height: 2),
                Text('Las indicaciones que te ha dado tu doctor.', style: TextStyle(color: p.texto2, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...contenido,
        ],
      ),
    );
  }

  Widget _tarjeta(Paleta p, Receta r, bool reciente) {
    final abierta = _abiertas.contains(r.id);
    final n = r.medicamentos.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: p.superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: abierta ? Paleta.primario : p.linea, width: abierta ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Pulsable(
            escala: 0.98,
            alTocar: () => _alternar(r.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: p.tinte, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.receipt_long_outlined, color: p.tinteTexto, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(Fechas.corta(r.fecha),
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.texto)),
                            ),
                            if (reciente) ...[
                              const SizedBox(width: 8),
                              Etiqueta('Más reciente', fondo: p.tinte, color: p.tinteTexto),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$n ${n == 1 ? 'medicamento' : 'medicamentos'} · ${r.clinica ?? 'Folio ${r.folio}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.texto2, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: abierta ? 0.5 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: Icon(Icons.expand_more_rounded, color: p.texto3),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !abierta
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(height: 1, color: p.linea),
                      if (r.medicamentos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Sin indicaciones registradas.', style: TextStyle(color: p.texto2)),
                        )
                      else
                        for (final m in r.medicamentos) _medicamento(p, m),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: Text('Folio ${r.folio}', style: TextStyle(color: p.texto3, fontSize: 12)),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _medicamento(Paleta p, Medicamento m) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: p.superficie2, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.medication_outlined, size: 19, color: Paleta.primario),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.nombre, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: p.texto)),
                  if (m.dosis.isNotEmpty) Text(m.dosis, style: TextStyle(color: p.texto2, fontSize: 13.5)),
                  if (m.frecuencia.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(Icons.schedule_rounded, size: 15, color: p.tinteTexto),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(m.frecuencia,
                                style: TextStyle(color: p.texto, fontSize: 13.5, height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _mensaje(Paleta p, IconData icono, String titulo, String texto, {bool accion = false}) => Aparecer(
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: p.superficie, borderRadius: BorderRadius.circular(18), border: Border.all(color: p.linea)),
          child: Column(
            children: [
              Icon(icono, size: 46, color: p.lineaFuerte),
              const SizedBox(height: 10),
              Text(titulo, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: p.texto)),
              const SizedBox(height: 4),
              Text(texto, textAlign: TextAlign.center, style: TextStyle(color: p.texto2, fontSize: 13)),
              if (accion) ...[
                const SizedBox(height: 14),
                OutlinedButton(onPressed: _cargar, child: const Text('Reintentar')),
              ],
            ],
          ),
        ),
      );
}
