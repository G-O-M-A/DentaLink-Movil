import 'package:flutter/material.dart';
import 'package:dentalink_movil/core/animaciones.dart';
import 'package:dentalink_movil/core/api.dart';
import 'package:dentalink_movil/core/tema.dart';
import 'package:dentalink_movil/features/home/views/home_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  int _sacudidas = 0; // cada error sacude la tarjeta

  void _mostrarError(String mensaje) {
    setState(() {
      _errorMessage = mensaje;
      _sacudidas++;
    });
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _mostrarError('Ingresa tu correo y tu contraseña.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // La contraseña se verifica dentro de Supabase (función movil_login);
      // la app nunca recibe el hash ni datos de otros pacientes.
      final paciente = await Api.login(email, password);
      if (!mounted) return;
      _passwordController.clear();
      Navigator.pushReplacement(context, rutaSuave(HomeView(nombre: '${paciente['nombre'] ?? ''}')));
    } on ApiError catch (e) {
      if (mounted) _mostrarError(e.mensaje);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Paleta.of(context);

    return Scaffold(
      backgroundColor: p.oscuro ? p.fondo : Paleta.primario,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(top: 4, right: 4, child: BotonTema(color: p.oscuro ? p.texto2 : Colors.white)),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Aparecer(child: _logo()),
                      const SizedBox(height: 14),
                      Aparecer(orden: 1, child: _titulo(p)),
                      const SizedBox(height: 28),
                      Aparecer(
                        orden: 3,
                        desplazamiento: 28,
                        child: Sacudir(disparo: _sacudidas, child: _tarjeta(p)),
                      ),
                      const SizedBox(height: 24),
                      Aparecer(
                        orden: 5,
                        child: Text(
                          'DentaLink © 2026 · Todos los derechos reservados',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: p.oscuro ? p.texto3 : const Color(0xCCFFFFFF)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logo() => Center(
        child: Container(
          width: 92,
          height: 92,
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: Image.asset(
            'img/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.medical_services, color: Paleta.primario, size: 40),
          ),
        ),
      );

  Widget _titulo(Paleta p) => Column(
        children: [
          const Text(
            'DENTALINK',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
          ),
          Text(
            'Portal de Pacientes',
            style: TextStyle(fontSize: 13, color: p.oscuro ? p.texto2 : const Color(0xE6FFFFFF)),
          ),
        ],
      );

  Widget _tarjeta(Paleta p) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.superficie,
          borderRadius: BorderRadius.circular(22),
          border: p.oscuro ? Border.all(color: p.linea) : null,
          boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¡Bienvenido de nuevo!',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Paleta.primario),
              ),
              const SizedBox(height: 4),
              Text('Entra para ver tus citas y recetas.', style: TextStyle(fontSize: 13, color: p.texto2)),
              const SizedBox(height: 22),
              _etiqueta(p, 'Correo electrónico'),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: p.texto),
                decoration: _campo(p, 'paciente@correo.com', Icons.mail_outline_rounded),
              ),
              const SizedBox(height: 16),
              _etiqueta(p, 'Contraseña'),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!_isLoading) _handleLogin();
                },
                style: TextStyle(color: p.texto),
                decoration: _campo(
                  p,
                  '••••••••',
                  Icons.lock_outline_rounded,
                  sufijo: IconButton(
                    tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: p.texto3,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: _errorMessage == null
                    ? const SizedBox(width: double.infinity, height: 20)
                    : Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: p.peligroFondo, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: p.peligroTexto, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMessage!, style: TextStyle(color: p.peligroTexto, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
              ),
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: Paleta.primario,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Paleta.primario,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _isLoading
                        ? const SizedBox(
                            key: ValueKey('cargando'),
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                          )
                        : const Text('Entrar', key: ValueKey('texto'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _etiqueta(Paleta p, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.texto2)),
      );

  InputDecoration _campo(Paleta p, String hint, IconData icono, {Widget? sufijo}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.texto3, fontSize: 14),
        prefixIcon: Icon(icono, color: p.texto3, size: 20),
        filled: true,
        fillColor: p.oscuro ? p.superficie2 : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.lineaFuerte),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Paleta.primario, width: 2),
        ),
        suffixIcon: sufijo,
      );
}
