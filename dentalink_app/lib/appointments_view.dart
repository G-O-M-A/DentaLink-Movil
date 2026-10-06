import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, this.userName = 'Juan Pérez'});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _appointmentDate = 'Jueves, 15 de Octubre de 2026';
  String _appointmentTime = '10:00 AM';
  String _appointmentStatus = 'Confirmada';
  Color _statusColor = Colors.green;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portal del Paciente', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            tooltip: 'Cerrar sesión',
            onPressed: () {
              Navigator.pop(context);
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, ${widget.userName}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Aquí tienes los detalles de tu próxima cita.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Próxima Cita',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                        ),
                        Chip(
                          label: Text(_appointmentStatus, style: const TextStyle(color: Colors.white, fontSize: 12)),
                          backgroundColor: _statusColor,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(_appointmentDate, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 18, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(_appointmentTime, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.medical_services, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text('Limpieza y Revisión General', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.blue),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              setState(() {
                                _appointmentStatus = 'Confirmada';
                                _statusColor = Colors.green;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('¡Has confirmado tu asistencia a la cita!')),
                              );
                            },
                            child: const Text('Confirmar', style: TextStyle(color: Colors.blue)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RescheduleSectionView()),
                              );

                              if (result != null && result is Map<String, String>) {
                                setState(() {
                                  _appointmentDate = result['date']!;
                                  _appointmentTime = result['time']!;
                                  _appointmentStatus = 'Reagendada';
                                  _statusColor = Colors.orange;
                                });
                              }
                            },
                            child: const Text('Reagendar', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RescheduleSectionView extends StatefulWidget {
  const RescheduleSectionView({super.key});

  @override
  State<RescheduleSectionView> createState() => _RescheduleSectionViewState();
}

class _RescheduleSectionViewState extends State<RescheduleSectionView> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;

  final List<String> _availableTimes = [
    '09:00 AM',
    '11:30 AM',
    '02:00 PM',
    '04:30 PM',
    '06:00 PM',
  ];

  String _formatDate(DateTime date) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    const weekdays = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    String weekday = weekdays[date.weekday - 1];
    String month = months[date.month - 1];
    return '$weekday, ${date.day} de $month de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reagendar Cita'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona un nuevo día:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                onDateChanged: (DateTime newDate) {
                  setState(() {
                    _selectedDate = newDate;
                    _selectedTime = null;
                  });
                },
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Horarios disponibles (${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}):',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _availableTimes.map((time) {
                final isSelected = _selectedTime == time;
                return ChoiceChip(
                  label: Text(time),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade600,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedTime = time;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _selectedTime == null
                    ? null 
                    : () {
                        final formattedDateString = _formatDate(_selectedDate);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('¡Cita Reagendada!'),
                            content: Text(
                              'Tu cita ha sido cambiada con éxito para el $formattedDateString a las $_selectedTime.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); 
                                  Navigator.pop(context, {
                                    'date': formattedDateString,
                                    'time': _selectedTime!,
                                  });
                                },
                                child: const Text('Aceptar'),
                              ),
                            ],
                          ),
                        );
                      },
                child: const Text(
                  'Confirmar Reagendamiento',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}