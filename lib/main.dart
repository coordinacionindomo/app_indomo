import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:signature/signature.dart';

// -----------------------------------------------------------------------------
// REEMPLAZA ESTOS DOS VALORES CON TUS LLAVES DE SUPABASE
// -----------------------------------------------------------------------------
const String SUPABASE_URL = 'https://nicplvxjguerokhwzvww.supabase.co/rest/v1/';
const String SUPABASE_ANON_KEY = 'sb_publishable_MRtcj7I0qhuGFVPD8XaYiw_O5a2xn3p';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trabajo Indomo - Salud',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA 1: INICIO DE SESIÓN (LOGIN)
// -----------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final response = await supabase
          .from('usuarios')
          .select()
          .eq('email', email)
          .eq('password_hash', password)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Credenciales incorrectas')),
          );
        }
      } else {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PatientsListPage(user: response),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar sesión: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAlignment.stretch,
          children: [
            const Icon(Icons.local_hospital, size: 80, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              'Trabajo Indomo Salud',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Correo Electrónico',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('INGRESAR', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA 2: LISTA DE PACIENTES ASIGNADOS
// -----------------------------------------------------------------------------
class PatientsListPage extends StatefulWidget {
  final Map<String, dynamic> user;
  const PatientsListPage({super.key, required this.user});

  @override
  State<PatientsListPage> createState() => _PatientsListPageState();
}

class _PatientsListPageState extends State<PatientsListPage> {
  List<dynamic> _pacientes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPacientes();
  }

  Future<void> _fetchPacientes() async {
    try {
      final response = await supabase.from('pacientes').select().eq('activo', true);
      setState(() {
        _pacientes = response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${widget.user['nombre_completo']}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pacientes.isEmpty
              ? const Center(child: Text('No hay pacientes de prueba cargados'))
              : ListView.builder(
                  itemCount: _pacientes.length,
                  itemBuilder: (context, index) {
                    final p = _pacientes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(p['nombre_completo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p['tipo_internacion'] ?? 'Domiciliaria'} - ${p['modulo'] ?? 'Módulo 1'}\nDNI: ${p['dni']}'),
                        trailing: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FichajePage(
                                  paciente: p,
                                  profesional: widget.user,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                          child: const Text('Fichar', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA 3: FICHAJE (GPS + 100M FLEXIBLE + CAPTURA PRIMERA VISITA + FIRMA)
// -----------------------------------------------------------------------------
class FichajePage extends StatefulWidget {
  final Map<String, dynamic> paciente;
  final Map<String, dynamic> profesional;

  const FichajePage({super.key, required this.paciente, required this.profesional});

  @override
  State<FichajePage> createState() => _FichajePageState();
}

class _FichajePageState extends State<FichajePage> {
  Position? _currentPosition;
  bool _isGettingGps = false;
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final _nombreFirmanteController = TextEditingController();

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'El GPS está desactivado en el dispositivo';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permisos de GPS denegados';
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error GPS: $e')));
    } finally {
      setState(() => _isGettingGps = false);
    }
  }

  Future<void> _guardarAtencion() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero captura la ubicación GPS')),
      );
      return;
    }

    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor solicita la firma del paciente/familiar')),
      );
      return;
    }

    double? latPaciente = widget.paciente['latitud_domicilio'];
    double? lonPaciente = widget.paciente['longitud_domicilio'];

    String estadoFichaje = 'COMPLETADO';
    double distanciaCalculada = 0;
    String mensajeExito = '🟢 Atención registrada correctamente.';

    // CASO 1: PRIMERA VISITA (Auto-captura del domicilio del paciente)
    if (latPaciente == null || lonPaciente == null) {
      await supabase.from('pacientes').update({
        'latitud_domicilio': _currentPosition!.latitude,
        'longitud_domicilio': _currentPosition!.longitude,
      }).eq('id', widget.paciente['id']);

      mensajeExito = '🟢 Domicilio registrado por primera vez y atención guardada.';
    } 
    // CASO 2: VISITAS POSTERIORES (Margen de tolerancia de 100 metros)
    else {
      distanciaCalculada = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        latPaciente,
        lonPaciente,
      );

      if (distanciaCalculada > 100.0) {
        estadoFichaje = 'ALERTA_DISTANCIA';
        mensajeExito = '⚠️ Atención registrada fuera de rango (${distanciaCalculada.round()}m). Alerta enviada al administrador.';
      } else {
        mensajeExito = '🟢 Atención registrada correctamente en el domicilio.';
      }
    }

    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final base64Signature = base64Encode(signatureBytes!);

      await supabase.from('asistencia_prestacion').insert({
        'profesional_id': widget.profesional['id'],
        'paciente_id': widget.paciente['id'],
        'rol_prestacion': widget.profesional['rol'],
        'fecha_hora_inicio': DateTime.now().toIso8601String(),
        'fecha_hora_fin': DateTime.now().toIso8601String(),
        'latitud_inicio': _currentPosition!.latitude,
        'longitud_inicio': _currentPosition!.longitude,
        'nombre_firmante': _nombreFirmanteController.text,
        'firma_url': 'data:image/png;base64,$base64Signature',
        'estado': estadoFichaje,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeExito),
            backgroundColor: estadoFichaje == 'ALERTA_DISTANCIA' ? Colors.orange : Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fichaje: ${widget.paciente['nombre_completo']}'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.location_on, size: 40, color: Colors.teal),
                    const SizedBox(height: 8),
                    Text(
                      _currentPosition == null
                          ? 'Ubicación GPS no capturada'
                          : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}, Lon: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isGettingGps ? null : _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: Text(_isGettingGps ? 'Obteniendo GPS...' : 'Capturar GPS'),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Firma del Paciente o Familiar Responsable:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: Signature(
                controller: _signatureController,
                height: 180,
                backgroundColor: Colors.grey[200]!,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: () => _signatureController.clear(),
                ),
              ],
            ),
            TextField(
              controller: _nombreFirmanteController,
              decoration: const InputDecoration(
                labelText: 'Nombre y Parentesco del Firmante (ej: Juan - Hijo)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardarAtencion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('FINALIZAR Y REGISTRAR ATENCIÓN', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
