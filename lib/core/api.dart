import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Error con un mensaje listo para mostrarse al paciente.
class ApiError implements Exception {
  final String codigo;
  final String mensaje;
  const ApiError(this.codigo, this.mensaje);

  bool get sesionInvalida => codigo == 'SESION_INVALIDA';

  @override
  String toString() => mensaje;
}

/// Toda la comunicación con Supabase pasa por aquí.
/// La app NO lee tablas directamente: solo llama las funciones seguras movil_*
/// (archivo supabase/01_funciones_movil.sql), que validan el token del paciente.
class Api {
  Api._();

  static String? _token;
  static bool get conSesion => _token != null;

  // La sesión se guarda en el celular para no iniciar sesión cada vez que se abre la app.
  // Solo se guarda el token (nunca la contraseña); en el servidor caduca tras 60 días sin uso.
  static const String _claveToken = 'dentalink_token';

  /// Recupera la sesión guardada. Devuelve true si había una (la valida el servidor al cargar el inicio).
  static Future<bool> restaurarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_claveToken);
    } catch (_) {
      _token = null;
    }
    return _token != null;
  }

  static Future<void> _guardarToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null) {
        await prefs.remove(_claveToken);
      } else {
        await prefs.setString(_claveToken, token);
      }
    } catch (_) {
      // Si no se puede guardar, la app sigue funcionando; solo pedirá iniciar sesión la próxima vez.
    }
  }

  static SupabaseClient get _db => Supabase.instance.client;

  static const Map<String, String> _mensajes = {
    'CREDENCIALES': 'Correo o contraseña incorrectos.',
    'DEMASIADOS_INTENTOS': 'Demasiados intentos. Espera 15 minutos e inténtalo de nuevo.',
    'SESION_INVALIDA': 'Tu sesión terminó. Vuelve a iniciar sesión.',
    'CITA_NO_ENCONTRADA': 'No encontramos esa cita.',
    'CITA_NO_EDITABLE': 'Esta cita ya no se puede modificar.',
    'FECHA_PASADA': 'Esa fecha u hora ya pasó. Elige otra.',
    'FUERA_DE_HORARIO': 'Ese horario está fuera del horario de atención.',
    'HORARIO_OCUPADO': 'Ese horario se acaba de ocupar. Elige otro.',
    'MENSAJE_VACIO': 'Escribe un mensaje.',
    'MENSAJE_LARGO': 'El mensaje es demasiado largo.',
  };

  static ApiError _error(String codigo) => ApiError(
        codigo,
        _mensajes[codigo] ?? 'No se pudo completar la acción. Inténtalo de nuevo.',
      );

  static Future<dynamic> _rpc(String funcion, Map<String, dynamic> params) async {
    try {
      return await _db.rpc(funcion, params: params);
    } on PostgrestException catch (e) {
      final codigo = _mensajes.keys.firstWhere(
        (k) => e.message.contains(k),
        orElse: () => 'DESCONOCIDO',
      );
      if (codigo == 'SESION_INVALIDA') {
        _token = null;
        _guardarToken(null);
      }
      throw _error(codigo);
    } on ApiError {
      rethrow;
    } catch (_) {
      throw const ApiError('CONEXION', 'Sin conexión. Revisa tu internet e inténtalo de nuevo.');
    }
  }

  static Map<String, dynamic> _mapa(dynamic r) => Map<String, dynamic>.from(r as Map);

  // ---------------- Sesión ----------------

  /// Devuelve los datos del paciente. Lanza ApiError si el correo o la contraseña no coinciden.
  static Future<Map<String, dynamic>> login(String correo, String password) async {
    final r = _mapa(await _rpc('movil_login', {'p_correo': correo, 'p_password': password}));
    if (r['error'] != null) throw _error('${r['error']}');
    _token = '${r['token']}';
    await _guardarToken(_token);
    return _mapa(r['paciente']);
  }

  static Future<void> logout() async {
    final t = _token;
    _token = null;
    await _guardarToken(null);
    if (t == null) return;
    try {
      await _db.rpc('movil_logout', params: {'p_token': t});
    } catch (_) {
      // Si no hay conexión, el token caduca solo en 30 días.
    }
  }

  // ---------------- Citas ----------------

  static Future<Inicio> inicio() async =>
      Inicio.fromJson(_mapa(await _rpc('movil_inicio', {'p_token': _token})));

  /// Horarios ocupados de un día en la clínica (sin datos de otros pacientes).
  static Future<Horarios> horarios(DateTime fecha, {int? excluir}) async => Horarios.fromJson(_mapa(
        await _rpc('movil_horarios', {'p_token': _token, 'p_fecha': Fechas.iso(fecha), 'p_excluir': excluir}),
      ));

  /// Cambia el día y la hora; la duración la conserva la clínica.
  static Future<Cita> reagendar(int citaId, DateTime fecha, int inicioMin) async => Cita.fromJson(_mapa(
        await _rpc('movil_reagendar', {
          'p_token': _token,
          'p_cita': citaId,
          'p_fecha': Fechas.iso(fecha),
          'p_inicio': Fechas.hhmm(inicioMin),
        }),
      ));

  // ---------------- Mensajes (chat con la clínica) ----------------

  /// Historial completo (o solo lo nuevo con `despues`). Marca como leídos los mensajes de la clínica.
  static Future<ChatDatos> mensajes({int despues = 0}) async =>
      ChatDatos.fromJson(_mapa(await _rpc('movil_mensajes', {'p_token': _token, 'p_despues': despues})));

  static Future<Mensaje> enviarMensaje(String texto) async =>
      Mensaje.fromJson(_mapa(await _rpc('movil_enviar_mensaje', {'p_token': _token, 'p_texto': texto})));

  /// Cuántos mensajes de la clínica no ha leído el paciente (para la bolita roja).
  static Future<int> noLeidos() async {
    final r = await _rpc('movil_no_leidos', {'p_token': _token});
    return (r as num?)?.toInt() ?? 0;
  }

  // ---------------- Recetas ----------------

  static Future<List<Receta>> recetas() async {
    final r = await _rpc('movil_recetas', {'p_token': _token});
    return (r as List).map((e) => Receta.fromJson(_mapa(e))).toList();
  }
}

// =====================================================================
// Modelos
// =====================================================================

class Cita {
  final int id;
  final String fecha; // YYYY-MM-DD
  final String horaInicio; // HH:MM
  final String horaFin; // HH:MM
  final String motivo;
  final String estado; // Pendiente | Completada | Cancelada

  const Cita({
    required this.id,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.motivo,
    required this.estado,
  });

  factory Cita.fromJson(Map<String, dynamic> j) => Cita(
        id: (j['id'] as num).toInt(),
        fecha: '${j['fecha'] ?? ''}',
        horaInicio: _hm(j['hora_inicio']),
        horaFin: _hm(j['hora_fin']),
        motivo: '${j['motivo'] ?? 'Consulta'}',
        estado: '${j['estado'] ?? 'Pendiente'}',
      );

  static String _hm(dynamic v) {
    final s = '${v ?? ''}';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  DateTime get dia => DateTime.parse(fecha);
  int get inicioMin => Fechas.minutos(horaInicio);
  int get finMin => Fechas.minutos(horaFin);
  int get duracion => finMin > inicioMin ? finMin - inicioMin : 30;
  bool get pendiente => estado == 'Pendiente';
}

class Inicio {
  final String nombre;
  final String apellidos;
  final String? clinica;
  final String? clinicaTelefono;
  final String? clinicaDireccion;
  final DateTime hoy;
  final int? proximaId;
  final List<Cita> citas; // de la más reciente a la más antigua

  const Inicio({
    required this.nombre,
    required this.apellidos,
    required this.clinica,
    required this.clinicaTelefono,
    required this.clinicaDireccion,
    required this.hoy,
    required this.proximaId,
    required this.citas,
  });

  factory Inicio.fromJson(Map<String, dynamic> j) {
    final p = Map<String, dynamic>.from((j['paciente'] ?? {}) as Map);
    final c = j['clinica'] == null ? <String, dynamic>{} : Map<String, dynamic>.from(j['clinica'] as Map);
    return Inicio(
      nombre: '${p['nombre'] ?? ''}',
      apellidos: '${p['apellidos'] ?? ''}',
      clinica: c['nombre'] as String?,
      clinicaTelefono: c['telefono'] as String?,
      clinicaDireccion: c['direccion'] as String?,
      hoy: DateTime.parse('${j['hoy']}'),
      proximaId: (j['proximaId'] as num?)?.toInt(),
      citas: ((j['citas'] ?? []) as List).map((e) => Cita.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }

  Cita? get proxima {
    for (final c in citas) {
      if (c.id == proximaId) return c;
    }
    return null;
  }
}

class Horarios {
  final DateTime hoy;
  final int ahoraMin;
  final List<List<int>> ocupados; // [inicioMin, finMin]

  const Horarios({required this.hoy, required this.ahoraMin, required this.ocupados});

  factory Horarios.fromJson(Map<String, dynamic> j) => Horarios(
        hoy: DateTime.parse('${j['hoy']}'),
        ahoraMin: Fechas.minutos('${j['ahora']}'),
        ocupados: ((j['ocupados'] ?? []) as List).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return [Fechas.minutos('${m['inicio']}'), Fechas.minutos('${m['fin']}')];
        }).toList(),
      );

  bool choca(int inicio, int fin) => ocupados.any((o) => inicio < o[1] && fin > o[0]);
}

class Mensaje {
  final int id;
  final String remitente; // 'paciente' (yo) o 'clinica'
  final String texto;
  final DateTime fecha;
  final bool pendiente; // enviándose (aún sin respuesta del servidor)

  const Mensaje({
    required this.id,
    required this.remitente,
    required this.texto,
    required this.fecha,
    this.pendiente = false,
  });

  bool get mio => remitente == 'paciente';

  factory Mensaje.fromJson(Map<String, dynamic> j) => Mensaje(
        id: (j['id'] as num).toInt(),
        remitente: '${j['remitente'] ?? ''}',
        texto: '${j['texto'] ?? ''}',
        fecha: DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
      );
}

class ChatDatos {
  final List<Mensaje> mensajes;
  final int leidoHasta; // mis mensajes con id <= a este ya los leyó la clínica

  const ChatDatos({required this.mensajes, required this.leidoHasta});

  factory ChatDatos.fromJson(Map<String, dynamic> j) => ChatDatos(
        mensajes: ((j['mensajes'] ?? []) as List)
            .map((e) => Mensaje.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        leidoHasta: (j['leidoHasta'] as num?)?.toInt() ?? 0,
      );
}

class Medicamento {
  final String nombre;
  final String dosis;
  final String frecuencia;
  const Medicamento(this.nombre, this.dosis, this.frecuencia);
}

class Receta {
  final int id;
  final String folio;
  final DateTime fecha;
  final String? clinica;
  final List<Medicamento> medicamentos;

  const Receta({required this.id, required this.folio, required this.fecha, required this.clinica, required this.medicamentos});

  factory Receta.fromJson(Map<String, dynamic> j) {
    final meds = j['medicamentos'];
    return Receta(
      id: (j['id'] as num).toInt(),
      folio: '${j['folio'] ?? 'RX'}',
      fecha: DateTime.tryParse('${j['fecha']}')?.toLocal() ?? DateTime.now(),
      clinica: j['clinica'] as String?,
      medicamentos: meds is List
          ? meds.map((m) {
              final x = Map<String, dynamic>.from(m as Map);
              return Medicamento('${x['nombre'] ?? ''}', '${x['dosis'] ?? ''}', '${x['frecuencia'] ?? ''}');
            }).toList()
          : <Medicamento>[],
    );
  }
}

// =====================================================================
// Fechas en español (sin paquetes extra)
// =====================================================================

class Fechas {
  Fechas._();

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
  ];

  static String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int minutos(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  static String hhmm(int min) => '${(min ~/ 60).toString().padLeft(2, '0')}:${(min % 60).toString().padLeft(2, '0')}';

  static DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// "sábado 28 de noviembre" (+ año si no es el actual)
  static String larga(DateTime d, {DateTime? hoy}) {
    final ref = hoy ?? DateTime.now();
    final base = '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';
    return d.year == ref.year ? base : '$base de ${d.year}';
  }

  /// "Hoy", "Mañana" o "sábado 28 de noviembre"
  static String relativa(DateTime d, DateTime hoy) {
    final dif = soloDia(d).difference(soloDia(hoy)).inDays;
    if (dif == 0) return 'Hoy';
    if (dif == 1) return 'Mañana';
    final t = larga(d, hoy: hoy);
    return t[0].toUpperCase() + t.substring(1);
  }

  static String corta(DateTime d) => '${d.day} de ${_meses[d.month - 1]} de ${d.year}';

  static String diaSemanaCorto(DateTime d) => const ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'][d.weekday - 1];

  static String mesCorto(DateTime d) =>
      const ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'][d.month - 1];

  static String hora(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Separador del chat: "Hoy", "Ayer", "Martes" o "24 de noviembre de 2026"
  static String separadorChat(DateTime d) {
    final dif = soloDia(DateTime.now()).difference(soloDia(d)).inDays;
    if (dif <= 0) return 'Hoy';
    if (dif == 1) return 'Ayer';
    if (dif < 7) {
      final t = _dias[d.weekday - 1];
      return t[0].toUpperCase() + t.substring(1);
    }
    return corta(d);
  }

  /// "Hoy", "Mañana", "En 3 días", "En 2 semanas"…
  static String cuentaRegresiva(DateTime d, DateTime hoy) {
    final dif = soloDia(d).difference(soloDia(hoy)).inDays;
    if (dif <= 0) return 'Hoy';
    if (dif == 1) return 'Mañana';
    if (dif < 14) return 'En $dif días';
    if (dif < 60) return 'En ${dif ~/ 7} semanas';
    return 'En ${dif ~/ 30} meses';
  }
}
