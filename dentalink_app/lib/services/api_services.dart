import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://172.18.1.180:3000/api'; 

  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'errorType': 'invalid_credentials'};
      }
    } catch (e) {
      print('Error de conexión en login: $e');
      return {'success': false, 'errorType': 'server_down'};
    }
  }

  static Future<List<dynamic>> getAppointments() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/appointments'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error al obtener citas: $e');
    }
    return [];
  }

  static Future<bool> updateStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/appointments/$id/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'status': status}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error al actualizar estado: $e');
      return false;
    }
  }

  static Future<bool> updateAppointmentTime(int id, String newDate, String newTime) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/appointments/$id/time'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'newDate': newDate, 'newTime': newTime}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error al reagendar cita: $e');
      return false;
    }
  }
}