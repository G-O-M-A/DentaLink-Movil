import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentalink_movil/features/home/views/prescription_history_view.dart';

class PrescriptionsView extends StatefulWidget {
  final String userEmail;
  const PrescriptionsView({super.key, this.userEmail = 'luis1@gmail.com'});

  @override
  State<PrescriptionsView> createState() => _PrescriptionsViewState();
}

class _PrescriptionsViewState extends State<PrescriptionsView> {
  // Colores oficiales de la estética web de Dentalink
  final Color primaryColor = const Color(0xFF00A8B5);
  final Color cardBgColor = const Color(0xFFE8F7F8);

  bool isLoading = true;
  bool hasAssignedPrescription = false;
  
  // Datos puramente de texto para el recordatorio
  String currentFolio = '';
  String reminderText = '';
  String emissionDate = '';

  // Historial de recetas en texto
  List<Map<String, String>> pastPrescriptions = [];
  @override
  void initState() {
    super.initState();
    _loadPrescriptionsFromDatabase();
  }

  // Método para extraer los datos de 'pacientes' y sus 'recetas' en Supabase
  Future<void> _loadPrescriptionsFromDatabase() async {
    try {
      final supabase = Supabase.instance.client;

      print('DEBUG PRESCRIPTIONS: Buscando paciente con correo: ${widget.userEmail}');

      // 1. Obtener datos del paciente usando el correo
      final patientResponse = await supabase
          .from('pacientes')
          .select('id')
          .eq('correo', widget.userEmail)
          .maybeSingle();

      if (patientResponse == null) {
        print('DEBUG PRESCRIPTIONS: No se encontró ningún paciente con este correo.');
        if (mounted) {
          setState(() {
            isLoading = false;
            hasAssignedPrescription = false;
          });
        }
        return;
      }

      final int patientId = patientResponse['id'];
      print('DEBUG PRESCRIPTIONS: Paciente encontrado -> ID: $patientId');

      // 2. Consultar las recetas asociadas a este pacienteId
      final List<dynamic> recetasResponse = await supabase
          .from('recetas')
          .select()
          .eq('pacienteId', patientId)
          .order('createdAt', ascending: false);

      print('DEBUG PRESCRIPTIONS: Recetas encontradas en la BD para este ID: $recetasResponse');

      if (recetasResponse.isNotEmpty) {
        final List<Map<String, dynamic>> listaRecetas =
            recetasResponse.map((r) => Map<String, dynamic>.from(r)).toList();

        final latest = listaRecetas.first;
        final String folio = latest['folio'] ?? 'RX';
        final createdAtStr = latest['createdAt']?.toString() ?? '';
        final fechaFormateada = createdAtStr.isNotEmpty ? createdAtStr.substring(0, 10) : '';

        // Procesamos el JSON de medicamentos
        final meds = latest['medicamentos'];
        String medicinesText = '';
        
        if (meds is List) {
          medicinesText = meds.map((m) {
            final nombre = m['nombre'] ?? '';
            final dosis = m['dosis'] ?? '';
            final frecuencia = m['frecuencia'] ?? '';
            if (dosis.isEmpty && frecuencia.isEmpty) {
              return '• $nombre';
            }
            return '• $nombre\n  Dosis: $dosis\n  Indicación: $frecuencia';
          }).join('\n\n');
        } else {
          medicinesText = meds.toString();
        }

        // Construimos el historial de recetas
       List<Map<String, String>> historyList = listaRecetas.map((item) {
          final f = item['folio'] ?? 'Receta';
          final fecha = item['createdAt']?.toString().substring(0, 10) ?? '';
          return {
            'title': 'Folio: $f ($fecha)',
            'subtitle': 'Recordatorio de medicamentos recetados',
          };
        }).toList();

        if (mounted) {
          setState(() {
            hasAssignedPrescription = true;
            currentFolio = folio;
            reminderText = medicinesText.isNotEmpty ? medicinesText : 'Sin indicaciones especificadas';
            emissionDate = 'Fecha de emisión: $fechaFormateada';
            pastPrescriptions = historyList;
            isLoading = false;
          });
        }
      } else {
        print('DEBUG PRESCRIPTIONS: Este paciente no tiene recetas registradas.');
        if (mounted) {
          setState(() {
            hasAssignedPrescription = false;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('DEBUG PRESCRIPTIONS EXCEPTION: $e');
      debugPrint('Error al cargar recetas: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ENCABEZADO ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emisión de Recetas',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Recordatorio de medicamentos e indicaciones prescritas.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- SECCIÓN: RECETA ACTUAL ---
          Container(
            padding: const EdgeInsets.all(18),
            width: double.infinity,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Receta actual ${currentFolio.isNotEmpty ? "($currentFolio)" : ""}',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                isLoading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(color: Color(0xFF00A8B5)),
                        ),
                      )
                    : hasAssignedPrescription
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reminderText,
                                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      emissionDate,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Nota: Este texto es meramente un recordatorio. Para surtir medicamentos, presenta tu receta física firmada.',
                                style: TextStyle(color: Colors.black54, fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ],
                          )
                        : Center(
                            child: Column(
                              children: [
                                const SizedBox(height: 12),
                                Icon(Icons.description_outlined, size: 48, color: primaryColor.withOpacity(0.5)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No hay recetas registradas actualmente.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Las indicaciones de tus medicamentos aparecerán aquí como recordatorio.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // --- SECCIÓN: HISTORIAL DE RECETAS ---
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PrescriptionHistoryView(
                    prescriptions: pastPrescriptions,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(18),
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Registro de recetas',
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${pastPrescriptions.length} recetas en el historial de recordatorios',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Toca para ver el detalle de tus indicaciones anteriores.',
                    style: TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}