import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dentalink_movil/features/home/views/prescriptions_view.dart';
import 'package:dentalink_movil/features/home/views/appointment_history_view.dart';
import 'package:dentalink_movil/features/auth/views/login_view.dart';

class HomeView extends StatefulWidget {
  final String userEmail;
  const HomeView({super.key, this.userEmail = 'luis1@gmail.com'});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final Color primaryColor = const Color(0xFF00A8B5);
  final Color cardBgColor = const Color(0xFFE8F7F8);
  final Color badgeGreenColor = const Color(0xFF7CB342);

  String patientName = 'Cargando...';
  String statusText = 'Pendiente';
  Color statusColor = const Color(0xFF00A8B5);
  String appointmentDate = 'Cargando cita...';
  String appointmentTime = '--:--';
  String treatmentName = 'Consulta general';
  int? currentAppointmentId;

  List<Map<String, String>> pastAppointments = [];
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPatientAndAppointments();
  }

  // Método para extraer datos reales de 'pacientes' y sus 'citas' en Supabase
  Future<void> _loadPatientAndAppointments() async {
    try {
      final supabase = Supabase.instance.client;

      print('DEBUG HOME: Buscando paciente con correo: ${widget.userEmail}');

      // 1. Obtener datos del paciente usando el correo
      final patientResponse = await supabase
          .from('pacientes')
          .select()
          .eq('correo', widget.userEmail)
          .maybeSingle();

      if (patientResponse == null) {
        print('DEBUG HOME: No se encontró ningún paciente con este correo.');
        setState(() {
          patientName = 'Paciente no encontrado';
          appointmentDate = 'Sin registro';
        });
        return;
      }

      final int patientId = patientResponse['id'];
      final String nombre = patientResponse['nombre'] ?? '';
      final String apellidos = patientResponse['apellidos'] ?? '';
      final String direccion = patientResponse['direccion'] ?? 'Sin dirección';

      print('DEBUG HOME: Paciente encontrado -> ID: $patientId, Nombre: $nombre $apellidos');

      // 2. Consultar todas las citas asociadas a este pacienteId
      final List<dynamic> citasResponse = await supabase
          .from('citas')
          .select()
          .eq('pacienteId', patientId);

      print('DEBUG HOME: Citas encontradas en la BD para este ID: $citasResponse');

      setState(() {
        patientName = '$nombre $apellidos';
      });

      if (citasResponse.isNotEmpty) {
        // Conversión segura de la lista dinámica a Map<String, dynamic>
        final List<Map<String, dynamic>> listaCitas =
            citasResponse.map((c) => Map<String, dynamic>.from(c)).toList();

        // Selección robusta de la próxima cita sin errores de tipo
        Map<String, dynamic>? proximaCita;
        try {
          proximaCita = listaCitas.firstWhere(
            (c) => ['pendiente', 'confirmada', 'programada']
                .contains(c['estado']?.toString().toLowerCase()),
          );
        } catch (_) {
          proximaCita = listaCitas.last;
        }

        print('DEBUG HOME: Próxima cita seleccionada para mostrar: $proximaCita');

        setState(() {
          currentAppointmentId = proximaCita?['id'];
          appointmentDate = proximaCita?['fecha']?.toString() ?? 'Fecha por definir';
          appointmentTime = proximaCita?['hora_inicio']?.toString() ?? '--:--';
          treatmentName = proximaCita?['motivo']?.toString() ?? 'Consulta general';

          final String estadoDb = proximaCita?['estado']?.toString() ?? 'Pendiente';
          statusText = estadoDb;

          if (estadoDb.toLowerCase() == 'confirmada' ||
              estadoDb.toLowerCase() == 'completada') {
            statusColor = badgeGreenColor;
          } else if (estadoDb.toLowerCase() == 'pendiente' ||
              estadoDb.toLowerCase() == 'programada') {
            statusColor = primaryColor;
          } else {
            statusColor = Colors.orange;
          }

          // Rellenar historial con todas las citas del paciente
          pastAppointments = listaCitas.map((c) {
            return {
              'date': c['fecha']?.toString() ?? '',
              'time': c['hora_inicio']?.toString() ?? '',
              'detail':
                  'Motivo: ${c['motivo']} · Estado: ${c['estado']} · Dir: $direccion',
            };
          }).toList();
        });
      } else {
        print('DEBUG HOME: Este paciente no tiene citas registradas en la tabla citas.');
        setState(() {
          statusText = 'Sin citas';
          appointmentDate = 'No hay citas registradas';
          appointmentTime = '--:--';
          treatmentName = 'Ninguno';
        });
      }
    } catch (e) {
      print('DEBUG HOME EXCEPTION: $e');
      debugPrint('Error al consultar datos en Supabase: $e');
    }
  }

  void _openRescheduleDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RescheduleAppointmentView()),
    );

    if (result != null && result is Map<String, String>) {
      final nuevaFecha = result['date']!;
      final nuevaHora = result['time']!;

      if (currentAppointmentId != null) {
        try {
          await Supabase.instance.client
              .from('citas')
              .update({
                'fecha': nuevaFecha,
                'hora_inicio': nuevaHora,
                'estado': 'Pendiente',
              })
              .eq('id', currentAppointmentId!);
        } catch (e) {
          debugPrint('Error al actualizar cita en Supabase: $e');
        }
      }

      setState(() {
        appointmentDate = nuevaFecha;
        appointmentTime = nuevaHora;
        statusText = 'Pendiente';
        statusColor = primaryColor;
      });

      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '¡Cita Reagendada!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'Tu cita ha sido cambiada con éxito para el $appointmentDate a las $appointmentTime.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Aceptar',
                style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmAttendance() async {
    if (currentAppointmentId != null) {
      try {
        await Supabase.instance.client
            .from('citas')
            .update({'estado': 'Confirmada'})
            .eq('id', currentAppointmentId!);
      } catch (e) {
        debugPrint('Error al confirmar asistencia: $e');
      }
    }

    setState(() {
      statusText = 'Confirmada';
      statusColor = badgeGreenColor;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Has confirmado tu asistencia a la cita!'),
        backgroundColor: Color(0xFF455A64),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // CAMBIO INTEGRADO: Se pasa el correo del usuario actual a la vista de recetas
    final List<Widget> pages = <Widget>[
      _buildHomeContent(),
      PrescriptionsView(userEmail: widget.userEmail),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.local_hospital, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Dentalink',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black45),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginView()),
              );
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Próxima cita',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Recetario',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, $patientName!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Organiza tu día y acompaña cada sonrisa.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
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
                      'Próxima Cita',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(appointmentDate, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(appointmentTime, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.medical_services_outlined, size: 16, color: primaryColor),
                    const SizedBox(width: 10),
                    Text(treatmentName, style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _confirmAttendance,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Confirmar', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _openRescheduleDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Reagendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AppointmentHistoryView(appointments: pastAppointments),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Registro de citas',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 14, color: primaryColor),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${pastAppointments.length} citas registradas en el historial',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Toca para ver el detalle completo de tus visitas anteriores.',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
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

class RescheduleAppointmentView extends StatefulWidget {
  const RescheduleAppointmentView({super.key});

  @override
  State<RescheduleAppointmentView> createState() => _RescheduleAppointmentViewState();
}

class _RescheduleAppointmentViewState extends State<RescheduleAppointmentView> {
  final Color primaryColor = const Color(0xFF00A8B5);
  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedTime) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hours = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
    final minutes = selectedTime.minute.toString().padLeft(2, '0');
    final period = selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
    final formattedTimeString = '$hours:$minutes $period';
    
    final dbTimeString = '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}:00';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Reagendar Cita', style: TextStyle(fontSize: 18)),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona un nuevo día:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CalendarDatePicker(
                  initialDate: selectedDate,
                  firstDate: DateTime(2026, 1, 1),
                  lastDate: DateTime(2026, 12, 31),
                  onDateChanged: (date) {
                    setState(() => selectedDate = date);
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Selecciona la hora de tu cita:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _selectTime(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time_filled, color: primaryColor),
                          const SizedBox(width: 12),
                          Text(
                            formattedTimeString,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Cambiar hora',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final formattedDate =
                        "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
                    Navigator.pop(context, {
                      'date': formattedDate,
                      'time': dbTimeString,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirmar Reagendamiento', style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}