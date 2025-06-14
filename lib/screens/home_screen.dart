import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/time_tracking_service.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TimeTrackingService _timeService = TimeTrackingService();
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final userData = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No hay usuario autenticado'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _signOut,
                child: const Text('Volver al inicio de sesión'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DRP Clock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<DocumentSnapshot?>(
              stream: Stream.fromFuture(
                _timeService.getActiveTimeRecord(_userData!['uid']),
              ),
              builder: (context, snapshot) {
                final hasActiveRecord = snapshot.hasData && snapshot.data != null;
                return Column(
                  children: [
                    Text(
                      hasActiveRecord ? 'Actualmente Registrado' : 'No Registrado',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                if (hasActiveRecord) {
                                  await _timeService.clockOut(snapshot.data!.id);
                                } else {
                                  await _timeService.clockIn(_userData!['uid']);
                                }
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        backgroundColor: hasActiveRecord
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary,
                      ),
                      child: Text(
                        hasActiveRecord ? 'Registrar Salida' : 'Registrar Entrada',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _timeService.getUserTimeRecords(_userData!['uid']),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Algo salió mal'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data?.docs ?? [];

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index].data() as Map<String, dynamic>;
                    final clockIn = (record['clockIn'] as Timestamp).toDate();
                    final clockOut = record['clockOut'] != null
                        ? (record['clockOut'] as Timestamp).toDate()
                        : null;

                    return ListTile(
                      title: Text(
                        'Entrada: ${clockIn.toString().split('.')[0]}',
                      ),
                      subtitle: clockOut != null
                          ? Text(
                              'Salida: ${clockOut.toString().split('.')[0]}',
                            )
                          : const Text('Actualmente Activo'),
                      trailing: clockOut == null
                          ? const Icon(Icons.timer, color: Colors.green)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 