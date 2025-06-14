import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

class WorkLogScreen extends StatefulWidget {
  final String userId;
  final String companyName;
  final String employeeName;

  const WorkLogScreen({
    Key? key,
    required this.userId,
    required this.companyName,
    required this.employeeName,
  }) : super(key: key);

  @override
  State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
  final AuthService _authService = AuthService();
  String? currentUserRole;
  List<Map<String, dynamic>> records = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadWorkRecords();
  }

  Future<void> _loadUserRole() async {
    final user = await _authService.getCurrentUser();
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user['id'])
          .get();
      if (userDoc.exists) {
        setState(() {
          currentUserRole = userDoc.data()?['role'] as String?;
        });
      }
    }
  }

  Future<void> _loadWorkRecords() async {
    try {
      setState(() {
        isLoading = true;
      });

      final user = _authService.getCurrentUser();
      if (user == null) return;

      final recordsRef = FirebaseFirestore.instance
          .collection('companies')
          .doc(widget.companyName)
          .collection('workers')
          .doc(widget.userId)
          .collection('work_records');

      final snapshot = await recordsRef.get();
      setState(() {
        records = snapshot.docs.map((doc) => doc.data()).toList();
        isLoading = false;
        print('Registros cargados: ' + records.toString());
      });
    } catch (e) {
      print('Error loading work records: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _exportToPdf(BuildContext context, List<QueryDocumentSnapshot> logs, String userName) async {
    print('Registros antes de exportar: ' + records.toString());
    final pdf = pw.Document();
    final tableData = _buildTableData();
    print('Datos que se exportan en la tabla: ' + tableData.toString());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Registro horario mensual',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Empresa: ${widget.companyName}'),
                      pw.Text('CIF/NIF: _________________'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Trabajador: ${widget.employeeName}'),
                      pw.Text('DNI: _________________'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Fecha', 'Entrada', 'Ubicación\nEntrada', 'Pausa', 'Reanudación', 'Salida', 'Ubicación\nSalida', 'Horas\nTrabajadas'],
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                cellStyle: pw.TextStyle(fontSize: 9),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.center,
                  5: pw.Alignment.center,
                  6: pw.Alignment.center,
                  7: pw.Alignment.center,
                },
                columnWidths: {
                  0: pw.FlexColumnWidth(1.2), // Fecha
                  1: pw.FlexColumnWidth(1.0), // Entrada
                  2: pw.FlexColumnWidth(1.5), // Ubicación Entrada
                  3: pw.FlexColumnWidth(1.0), // Pausa
                  4: pw.FlexColumnWidth(1.0), // Reanudación
                  5: pw.FlexColumnWidth(1.0), // Salida
                  6: pw.FlexColumnWidth(1.5), // Ubicación Salida
                  7: pw.FlexColumnWidth(1.0), // Horas Trabajadas
                },
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 0.5,
                ),
              ),
            ],
          );
        },
      ),
    );

    // Añadir página de firmas
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Firma del trabajador:'),
                      pw.SizedBox(height: 50),
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Firma de la empresa:'),
                      pw.SizedBox(height: 50),
                      pw.Container(
                        width: 200,
                        height: 1,
                        color: PdfColors.black,
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 50),
              pw.Center(
                child: pw.Text(
                  'Fecha: _________________',
                  style: pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/registro_horario.pdf');
      await file.writeAsBytes(await pdf.save());
      
      if (context.mounted) {
        try {
          await OpenFile.open(file.path);
        } catch (e) {
          // Si falla la apertura automática, mostrar un mensaje al usuario
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF guardado en: ${file.path}'),
              action: SnackBarAction(
                label: 'Abrir',
                onPressed: () async {
                  try {
                    await OpenFile.open(file.path);
                  } catch (e) {
                    print('Error al abrir el archivo: $e');
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error al guardar el PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar el PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Jornada'),
        backgroundColor: Colors.blue,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _authService.getCurrentUser(),
        builder: (context, currentUserSnapshot) {
          if (currentUserSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (currentUserSnapshot.hasError) {
            print('Error al obtener usuario actual: ${currentUserSnapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Error al cargar los datos del usuario',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Detalles: ${currentUserSnapshot.error}',
                    style: const TextStyle(fontSize: 14, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final currentUser = currentUserSnapshot.data;
          if (currentUser == null) {
            return const Center(
              child: Text('No hay usuario autenticado'),
            );
          }

          final currentUserRole = (currentUser['role'] as String?)?.toLowerCase().trim() ?? '';
          print('=== DEBUG INFO ===');
          print('Usuario actual (admin): $currentUser');
          print('Rol del usuario actual: $currentUserRole');
          print('¿Es administrador?: ${currentUserRole == 'admin'}');
          print('=================');

          return FutureBuilder<Map<String, dynamic>?>(
            future: widget.userId != null 
                ? FirebaseFirestore.instance.collection('users').doc(widget.userId).get().then((doc) => doc.data())
                : Future.value(currentUser),
            builder: (context, targetUserSnapshot) {
              if (targetUserSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final targetUser = targetUserSnapshot.data;
              if (targetUser == null) {
                return const Center(
                  child: Text('No se encontró el usuario'),
                );
              }

              final targetUserId = widget.userId ?? targetUser['id'];
              final targetUserName = targetUser['name'] as String? ?? 'Usuario';

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 24),
                    const SizedBox(width: 8),
                    Text(
                          'Registros de $targetUserName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Botón de exportar a PDF solo para administradores
                        if (currentUserRole == 'admin')
                          Container(
                            margin: const EdgeInsets.only(left: 16),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                print('=== BOTÓN PDF PRESIONADO ===');
                                print('Usuario actual (admin): $currentUser');
                                print('Rol del usuario actual: $currentUserRole');
                                print('ID del trabajador: $targetUserId');
                                print('==========================');
                                FirebaseFirestore.instance
                                    .collection('work_logs')
                                    .where('userId', isEqualTo: targetUserId)
                                    .get()
                                    .then((snapshot) {
                                      print('Número de registros encontrados: ${snapshot.docs.length}');
                                      _exportToPdf(context, snapshot.docs, targetUserName);
                                    });
                              },
                              icon: const Icon(Icons.picture_as_pdf, size: 24),
                              label: const Text(
                                'Exportar a PDF',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('work_logs')
                      .where('userId', isEqualTo: targetUserId)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      print('Error al consultar registros: ${snapshot.error}');
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Error al cargar los registros',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Detalles: ${snapshot.error}',
                              style: const TextStyle(fontSize: 14, color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                (context as Element).markNeedsBuild();
                              },
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final logs = snapshot.data?.docs ?? [];
                    print('Número de registros encontrados: ${logs.length}');
                    print('Primer registro: ${logs.isNotEmpty ? logs.first.data() : 'No hay registros'}');

                    if (logs.isEmpty) {
                      return const Center(
                        child: Text('No hay registros de jornada'),
                      );
                    }

                    // Ordenar los registros por timestamp en memoria
                    logs.sort((a, b) {
                      final aTimestamp = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
                      final bTimestamp = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp;
                      return bTimestamp.compareTo(aTimestamp); // Orden descendente
                    });

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Fecha')),
                              DataColumn(label: Text('Entrada')),
                              DataColumn(label: Text('Ubicación Entrada')),
                              DataColumn(label: Text('Pausa')),
                              DataColumn(label: Text('Reanudación')),
                              DataColumn(label: Text('Salida')),
                              DataColumn(label: Text('Ubicación Salida')),
                              DataColumn(label: Text('Horas Trabajadas')),
                            ],
                            rows: _buildTableRows(logs),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                        );
                      },
                    );
                  },
      ),
    );
  }

  List<DataRow> _buildTableRows(List<QueryDocumentSnapshot> logs) {
    final Map<String, Map<String, String>> groupedRecords = {};
    
    for (var doc in logs) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['timestamp'] as Timestamp).toDate();
      final dateStr = DateFormat('dd/MM/yyyy').format(date);
      final timeStr = DateFormat('HH:mm').format(date);
      
      if (!groupedRecords.containsKey(dateStr)) {
        groupedRecords[dateStr] = {
          'fecha': dateStr,
          'entrada': '-',
          'entrada_address': '-',
          'pausa': '-',
          'reanudar': '-',
          'salida': '-',
          'salida_address': '-',
          'horas_trabajadas': '-',
        };
      }
      
      final records = groupedRecords[dateStr]!;
      final eventType = data['eventType'] as String? ?? data['type'] as String? ?? '';
      switch (eventType) {
        case 'entrada':
          records['entrada'] = timeStr;
          records['entrada_address'] = data['address'] ?? '-';
          break;
        case 'pausa':
          records['pausa'] = timeStr;
          break;
        case 'reanudar':
          records['reanudar'] = timeStr;
          break;
        case 'salida':
          records['salida'] = timeStr;
          records['salida_address'] = data['address'] ?? '-';
          break;
      }
    }

    // Calcular horas trabajadas para cada día
    for (var record in groupedRecords.values) {
      if (record['entrada'] != '-' && record['salida'] != '-') {
        final entrada = _parseTime(record['entrada']!);
        final salida = _parseTime(record['salida']!);
        var horasTrabajadas = _calculateHours(entrada, salida);

        // Restar tiempo de pausa si existe
        if (record['pausa'] != '-' && record['reanudar'] != '-') {
          final pausa = _parseTime(record['pausa']!);
          final reanudar = _parseTime(record['reanudar']!);
          final tiempoPausa = _calculateHours(pausa, reanudar);
          horasTrabajadas = horasTrabajadas - tiempoPausa;
        }

        record['horas_trabajadas'] = _formatHours(horasTrabajadas);
      }
    }

    return groupedRecords.entries.map((entry) {
      final record = entry.value;
      return DataRow(
        cells: [
          DataCell(Text(record['fecha'] ?? '-')),
          DataCell(
            currentUserRole == 'admin'
                ? _buildEditableTimeCell(
                    record['entrada']!,
                    (newValue) async {
                      record['entrada'] = newValue;
                      // Recalcular horas trabajadas
                      if (record['entrada'] != '-' && record['salida'] != '-') {
                        final entrada = _parseTime(record['entrada']!);
                        final salida = _parseTime(record['salida']!);
                        var horasTrabajadas = _calculateHours(entrada, salida);
                        if (record['pausa'] != '-' && record['reanudar'] != '-') {
                          final pausa = _parseTime(record['pausa']!);
                          final reanudar = _parseTime(record['reanudar']!);
                          final tiempoPausa = _calculateHours(pausa, reanudar);
                          horasTrabajadas = horasTrabajadas - tiempoPausa;
                        }
                        record['horas_trabajadas'] = _formatHours(horasTrabajadas);
                      }
                      setState(() {});
                    },
                  )
                : Text(record['entrada']!),
          ),
          DataCell(Text(record['entrada_address'] ?? '-')),
          DataCell(
            currentUserRole == 'admin'
                ? _buildEditableTimeCell(
                    record['pausa']!,
                    (newValue) async {
                      record['pausa'] = newValue;
                      // Recalcular horas trabajadas
                      if (record['entrada'] != '-' && record['salida'] != '-') {
                        final entrada = _parseTime(record['entrada']!);
                        final salida = _parseTime(record['salida']!);
                        var horasTrabajadas = _calculateHours(entrada, salida);
                        if (record['pausa'] != '-' && record['reanudar'] != '-') {
                          final pausa = _parseTime(record['pausa']!);
                          final reanudar = _parseTime(record['reanudar']!);
                          final tiempoPausa = _calculateHours(pausa, reanudar);
                          horasTrabajadas = horasTrabajadas - tiempoPausa;
                        }
                        record['horas_trabajadas'] = _formatHours(horasTrabajadas);
                      }
                      setState(() {});
                    },
                  )
                : Text(record['pausa']!),
          ),
          DataCell(
            currentUserRole == 'admin'
                ? _buildEditableTimeCell(
                    record['reanudar']!,
                    (newValue) async {
                      record['reanudar'] = newValue;
                      // Recalcular horas trabajadas
                      if (record['entrada'] != '-' && record['salida'] != '-') {
                        final entrada = _parseTime(record['entrada']!);
                        final salida = _parseTime(record['salida']!);
                        var horasTrabajadas = _calculateHours(entrada, salida);
                        if (record['pausa'] != '-' && record['reanudar'] != '-') {
                          final pausa = _parseTime(record['pausa']!);
                          final reanudar = _parseTime(record['reanudar']!);
                          final tiempoPausa = _calculateHours(pausa, reanudar);
                          horasTrabajadas = horasTrabajadas - tiempoPausa;
                        }
                        record['horas_trabajadas'] = _formatHours(horasTrabajadas);
                      }
                      setState(() {});
                    },
                  )
                : Text(record['reanudar']!),
          ),
          DataCell(
            currentUserRole == 'admin'
                ? _buildEditableTimeCell(
                    record['salida']!,
                    (newValue) async {
                      record['salida'] = newValue;
                      // Recalcular horas trabajadas
                      if (record['entrada'] != '-' && record['salida'] != '-') {
                        final entrada = _parseTime(record['entrada']!);
                        final salida = _parseTime(record['salida']!);
                        var horasTrabajadas = _calculateHours(entrada, salida);
                        if (record['pausa'] != '-' && record['reanudar'] != '-') {
                          final pausa = _parseTime(record['pausa']!);
                          final reanudar = _parseTime(record['reanudar']!);
                          final tiempoPausa = _calculateHours(pausa, reanudar);
                          horasTrabajadas = horasTrabajadas - tiempoPausa;
                        }
                        record['horas_trabajadas'] = _formatHours(horasTrabajadas);
                      }
                      setState(() {});
                    },
                  )
                : Text(record['salida']!),
          ),
          DataCell(Text(record['salida_address'] ?? '-')),
          DataCell(Text(record['horas_trabajadas'] ?? '-')),
        ],
      );
    }).toList();
  }

  Widget _buildEditableTimeCell(String currentValue, Function(String) onChanged) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            String newValue = currentValue;
            return AlertDialog(
              title: const Text('Editar Hora'),
              content: TextField(
                controller: TextEditingController(text: currentValue),
                decoration: const InputDecoration(
                  hintText: 'HH:mm',
                  labelText: 'Nueva hora',
                ),
                onChanged: (value) {
                  newValue = value;
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    if (_isValidTimeFormat(newValue)) {
                      onChanged(newValue);
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Formato de hora inválido. Use HH:mm'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Guardar'),
              ),
            ],
          );
        },
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(currentValue),
            const SizedBox(width: 4),
            const Icon(Icons.edit, size: 16, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  bool _isValidTimeFormat(String time) {
    if (time == '-') return true;
    final RegExp timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(time);
  }

  DateTime _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  double _calculateHours(DateTime start, DateTime end) {
    return end.difference(start).inMinutes / 60;
  }

  String _formatHours(double hours) {
    final hoursInt = hours.floor();
    final minutes = ((hours - hoursInt) * 60).round();
    return '$hoursInt:${minutes.toString().padLeft(2, '0')}';
  }

  List<List<String>> _buildTableData() {
    Map<String, Map<String, dynamic>> groupedRecords = {};
    for (var record in records) {
      String fecha = record['fecha']?.toString() ?? '';
      if (!groupedRecords.containsKey(fecha)) {
        groupedRecords[fecha] = {
          'fecha': fecha,
          'entrada': record['entrada']?.toString() ?? '-',
          'ubicacion_entrada': record['ubicacion_entrada']?.toString() ?? record['entrada_address']?.toString() ?? '-',
          'pausa': record['pausa']?.toString() ?? '-',
          'reanudar': record['reanudar']?.toString() ?? '-',
          'salida': record['salida']?.toString() ?? '-',
          'ubicacion_salida': record['ubicacion_salida']?.toString() ?? record['salida_address']?.toString() ?? '-',
          'horas_trabajadas': record['horas_trabajadas']?.toString() ?? '-',
        };
      }
    }
    // Calcular horas totales
    String horasTotales = '00:00';
    double totalMinutos = 0;
    for (var record in groupedRecords.values) {
      String horas = record['horas_trabajadas']?.toString() ?? '00:00';
      if (horas != '-') {
        List<String> partes = horas.split(':');
        if (partes.length == 2) {
          totalMinutos += int.parse(partes[0]) * 60 + int.parse(partes[1]);
        }
      }
    }
    int horas = (totalMinutos / 60).floor();
    int minutos = (totalMinutos % 60).round();
    horasTotales = '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}';

    // Preparar datos para la tabla
    List<List<String>> tableData = groupedRecords.values.map((record) => [
      record['fecha']?.toString() ?? '-',
      record['entrada']?.toString() ?? '-',
      record['ubicacion_entrada']?.toString() ?? '-',
      record['pausa']?.toString() ?? '-',
      record['reanudar']?.toString() ?? '-',
      record['salida']?.toString() ?? '-',
      record['ubicacion_salida']?.toString() ?? '-',
      record['horas_trabajadas']?.toString() ?? '-',
    ]).toList();

    // Añadir fila de total
    tableData.add(['Total', '', '', '', '', '', '', horasTotales]);

    return tableData;
  }
} 