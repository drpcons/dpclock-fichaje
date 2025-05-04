import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registro_jornada.dart';
import '../services/jornada_service.dart';
import '../services/auth_service.dart';
import '../services/logger_service.dart';
import '../utils/platform_utils.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

const bool isWeb = bool.fromEnvironment('dart.library.js_util');

Future<void> downloadExcelWeb(List<int> bytes, String fileName) async {
  final content = base64Encode(bytes);
  final anchor = html.AnchorElement(
    href: 'data:text/csv;charset=utf-8;base64,$content'
  )
    ..setAttribute('download', fileName)
    ..click();
}

class JornadasScreen extends StatefulWidget {
  const JornadasScreen({super.key});

  @override
  State<JornadasScreen> createState() => _JornadasScreenState();
}

class _JornadasScreenState extends State<JornadasScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _filterTipo = 'TODOS';
  final List<String> _tiposFichaje = ['TODOS', 'ENTRADA', 'PAUSA', 'SALIDA'];
  
  // Nuevas variables para filtros de columnas
  DateTime? _filterFechaInicio;
  DateTime? _filterFechaFin;
  String _filterNombre = '';
  String _filterEmail = '';
  String _filterUbicacion = '';

  // Nueva variable para manejar registros seleccionados
  final Set<String> _selectedRegistros = {};
  bool _selectAll = false;

  Color _getTipoColor(String tipo) {
    switch (tipo) {
      case 'ENTRADA':
        return Colors.green;
      case 'PAUSA':
        return Colors.orange;
      case 'SALIDA':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildLocationInfo(RegistroJornada registro) {
    LoggerService.info('Construyendo información de ubicación para registro: ${registro.id}');
    LoggerService.info('Dirección: ${registro.locationAddress}');
    LoggerService.info('Coordenadas: ${registro.latitude}, ${registro.longitude}');

    String locationText;
    
    // Primero intentar usar la dirección guardada
    if (registro.locationAddress != null && registro.locationAddress!.trim().isNotEmpty) {
      LoggerService.info('Usando dirección guardada: ${registro.locationAddress}');
      locationText = registro.locationAddress!;
    }
    // Si no hay dirección, pero hay coordenadas, mostrarlas
    else if (registro.latitude != null && registro.longitude != null) {
      locationText = 'Lat: ${registro.latitude!.toStringAsFixed(6)}, Long: ${registro.longitude!.toStringAsFixed(6)}';
      LoggerService.info('Usando coordenadas: $locationText');
    }
    // Si no hay ni dirección ni coordenadas
    else {
      locationText = 'Sin ubicación';
      LoggerService.info('No hay información de ubicación disponible');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ubicación:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          locationText,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildColumnHeader(String label, String tooltip, VoidCallback onFilter) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        IconButton(
          icon: const Icon(Icons.filter_list, size: 20),
          tooltip: tooltip,
          onPressed: onFilter,
          constraints: const BoxConstraints(minWidth: 40),
        ),
      ],
    );
  }

  Future<void> _showDateRangeFilter(BuildContext context) async {
    final DateTimeRange? dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filterFechaInicio != null && _filterFechaFin != null
          ? DateTimeRange(start: _filterFechaInicio!, end: _filterFechaFin!)
          : null,
    );

    if (dateRange != null) {
      setState(() {
        _filterFechaInicio = dateRange.start;
        _filterFechaFin = dateRange.end;
      });
    }
  }

  Future<void> _showFilterOptions(BuildContext context, String title, List<String> options, String currentValue, Function(String) onFilter) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Filtrar por $title'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar $title',
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  // Aquí se podría implementar la búsqueda en tiempo real
                },
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return ListTile(
                      title: Text(option),
                      selected: currentValue == option,
                      onTap: () {
                        Navigator.pop(context);
                        onFilter(option);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onFilter('');
            },
            child: const Text('Limpiar filtro'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  List<String> _getUniqueValues(List<RegistroJornada> registros, String field) {
    final Set<String> uniqueValues = {};
    
    for (var registro in registros) {
      String? value;
      switch (field) {
        case 'tipo':
          value = registro.tipo;
          break;
        case 'nombre':
          value = registro.userName;
          break;
        case 'email':
          value = registro.userEmail;
          break;
        case 'ubicacion':
          value = registro.locationAddress;
          break;
      }
      if (value != null && value.isNotEmpty) {
        uniqueValues.add(value);
      }
    }
    
    final sortedValues = uniqueValues.toList()..sort();
    return sortedValues;
  }

  Future<void> _exportToCSV(List<RegistroJornada> registros) async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando archivo CSV...'),
              ],
            ),
          );
        },
      );

      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      final now = DateTime.now();
      final fileName = 'registros_${DateFormat('yyyyMMdd_HHmm').format(now)}.csv';
      
      // Crear contenido CSV
      final StringBuffer csvContent = StringBuffer();
      
      // Encabezados
      csvContent.writeln('Tipo,Fecha,Nombre,Email,Ubicación');
      
      // Datos
      for (var registro in registros) {
        final List<String> row = [
          registro.tipo,
          dateFormat.format(registro.fecha),
          registro.userName,
          registro.userEmail,
          registro.locationAddress ?? 'Sin ubicación'
        ].map((field) => '"${field.replaceAll('"', '""')}"').toList();
        
        csvContent.writeln(row.join(','));
      }

      // Intentar obtener el directorio de almacenamiento
      Directory? directory;
      try {
        // Primero intentar con almacenamiento externo
        directory = await getExternalStorageDirectory();
      } catch (e) {
        // Si falla, intentar con directorio temporal
        directory = await getTemporaryDirectory();
      }

      if (directory == null) {
        throw Exception('No se pudo acceder al almacenamiento');
      }

      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(csvContent.toString());

      // Cerrar diálogo de progreso
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Compartir archivo
      if (context.mounted) {
        try {
          final result = await Share.shareXFiles(
            [XFile(filePath)],
            subject: 'Registros de Jornada',
          );

          if (result.status == ShareResultStatus.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Archivo exportado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (shareError) {
          // Mostrar diálogo con la ubicación del archivo
          if (context.mounted) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Archivo Generado'),
                  content: SingleChildScrollView(
                    child: Text('El archivo se ha guardado en:\n$filePath'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Aceptar'),
                    ),
                  ],
                );
              },
            );
          }
        }
      }
    } catch (e) {
      // Cerrar diálogo de progreso si hay error
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Mostrar error
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error al exportar'),
              content: SingleChildScrollView(
                child: Text('No se pudo exportar el archivo: $e'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _exportToExcel(List<RegistroJornada> registros) async {
    try {
      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando archivo Excel...'),
              ],
            ),
          );
        },
      );

      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      final now = DateTime.now();
      final fileName = 'registros_${DateFormat('yyyyMMdd_HHmm').format(now)}.csv';
      
      // Crear contenido CSV
      final StringBuffer csvContent = StringBuffer();
      
      // Encabezados
      csvContent.writeln('Tipo,Fecha,Nombre,Email,Ubicación');
      
      // Datos
      for (var registro in registros) {
        final List<String> row = [
          registro.tipo,
          dateFormat.format(registro.fecha),
          registro.userName,
          registro.userEmail,
          registro.locationAddress ?? 'Sin ubicación'
        ].map((field) => '"${field.replaceAll('"', '""')}"').toList();
        
        csvContent.writeln(row.join(','));
      }

      // Cerrar diálogo de progreso
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Convertir a bytes
      final bytes = csvContent.toString().codeUnits;

      if (isWeb) {
        // En la web, usar el método de descarga web
        await downloadExcelWeb(bytes, fileName);
      } else {
        // En móvil, usar el método de compartir
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsString(csvContent.toString());

        if (context.mounted) {
          try {
            final result = await Share.shareXFiles(
              [XFile(file.path)],
              subject: 'Registros de Jornada',
            );

            if (result.status == ShareResultStatus.success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Archivo exportado correctamente'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (shareError) {
            // Mostrar diálogo con la ubicación del archivo
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Archivo Generado'),
                    content: SingleChildScrollView(
                      child: Text('El archivo se ha guardado en:\n${file.path}'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Aceptar'),
                      ),
                    ],
                  );
                },
              );
            }
          }
        }
      }
    } catch (e) {
      // Cerrar diálogo de progreso si hay error
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      // Mostrar error
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Error al exportar'),
              content: SingleChildScrollView(
                child: Text('No se pudo exportar el archivo: $e'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Aceptar'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _confirmarEliminarRegistro(RegistroJornada registro) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¿Está seguro de que desea eliminar este registro?'),
                const SizedBox(height: 16),
                Text('Tipo: ${registro.tipo}'),
                Text('Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(registro.fecha)}'),
                Text('Usuario: ${registro.userName}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  Navigator.of(context).pop();
                  // Mostrar indicador de progreso
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Eliminando registro...'),
                          ],
                        ),
                      );
                    },
                  );
                  
                  // Eliminar registro
                  await JornadaService().deleteRegistro(registro.id);
                  
                  // Cerrar diálogo de progreso
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    // Mostrar mensaje de éxito
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Registro eliminado correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  // Cerrar diálogo de progreso si está abierto
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    // Mostrar error
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Error'),
                          content: Text('No se pudo eliminar el registro: $e'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Aceptar'),
                            ),
                          ],
                        );
                      },
                    );
                  }
                }
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _eliminarRegistrosSeleccionados() async {
    if (_selectedRegistros.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Está seguro que desea eliminar ${_selectedRegistros.length} registros seleccionados?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Mostrar indicador de progreso
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Eliminando registros...'),
                ],
              ),
            );
          },
        );

        // Eliminar registros
        for (var registroId in _selectedRegistros) {
          await JornadaService().deleteRegistro(registroId);
        }

        // Limpiar selección
        setState(() {
          _selectedRegistros.clear();
          _selectAll = false;
        });

        // Cerrar diálogo de progreso
        if (context.mounted) {
          Navigator.of(context).pop();
          // Mostrar mensaje de éxito
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registros eliminados correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Cerrar diálogo de progreso si hay error
        if (context.mounted) {
          Navigator.of(context).pop();
          // Mostrar mensaje de error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar registros: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildAdminView(List<RegistroJornada> registros) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currentUserEmail = _auth.currentUser?.email;
    final isAdmin = currentUserEmail == 'd.romeral.perulero@gmail.com';
    
    // Filtrar registros
    var filteredRegistros = registros.where((registro) {
      // Filtro por tipo
      if (_filterTipo != 'TODOS' && registro.tipo != _filterTipo) {
        return false;
      }

      // Filtro por fecha
      if (_filterFechaInicio != null && _filterFechaFin != null) {
        if (registro.fecha.isBefore(_filterFechaInicio!) || 
            registro.fecha.isAfter(_filterFechaFin!.add(const Duration(days: 1)))) {
          return false;
        }
      }

      // Filtro por nombre
      if (_filterNombre.isNotEmpty && 
          !registro.userName.toLowerCase().contains(_filterNombre.toLowerCase())) {
        return false;
      }

      // Filtro por email
      if (_filterEmail.isNotEmpty && 
          !registro.userEmail.toLowerCase().contains(_filterEmail.toLowerCase())) {
        return false;
      }

      // Filtro por ubicación
      if (_filterUbicacion.isNotEmpty) {
        final hasLocation = registro.locationAddress?.toLowerCase().contains(_filterUbicacion.toLowerCase()) ?? false;
        if (!hasLocation) return false;
      }

      return true;
    }).toList();

    return Column(
      children: [
        if (isAdmin) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _selectAll,
                      onChanged: (bool? value) {
                        setState(() {
                          _selectAll = value ?? false;
                          if (_selectAll) {
                            _selectedRegistros.addAll(filteredRegistros.map((r) => r.id));
                          } else {
                            _selectedRegistros.clear();
                          }
                        });
                      },
                    ),
                    const Text('Seleccionar todo'),
                    const SizedBox(width: 16),
                    if (_selectedRegistros.isNotEmpty)
                      FilledButton.icon(
                        onPressed: _eliminarRegistrosSeleccionados,
                        icon: const Icon(Icons.delete),
                        label: Text('Eliminar (${_selectedRegistros.length})'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
                FilledButton.icon(
                  onPressed: filteredRegistros.isEmpty 
                    ? null 
                    : () => _exportToExcel(filteredRegistros),
                  icon: const Icon(Icons.file_download),
                  label: const Text('Exportar Excel'),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              child: DataTable(
                columns: [
                  if (isAdmin)
                    const DataColumn(
                      label: SizedBox.shrink(),
                    ),
                  DataColumn(
                    label: _buildColumnHeader('Tipo', 'Filtrar por tipo', 
                      () => _showFilterOptions(
                        context,
                        'tipo',
                        _getUniqueValues(registros, 'tipo'),
                        _filterTipo,
                        (value) => setState(() => _filterTipo = value.isEmpty ? 'TODOS' : value),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: _buildColumnHeader('Fecha/Hora', 'Filtrar por rango de fechas',
                      () => _showDateRangeFilter(context)),
                  ),
                  DataColumn(
                    label: _buildColumnHeader('Nombre', 'Filtrar por nombre',
                      () => _showFilterOptions(
                        context,
                        'nombre',
                        _getUniqueValues(registros, 'nombre'),
                        _filterNombre,
                        (value) => setState(() => _filterNombre = value),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: _buildColumnHeader('Email', 'Filtrar por email',
                      () => _showFilterOptions(
                        context,
                        'email',
                        _getUniqueValues(registros, 'email'),
                        _filterEmail,
                        (value) => setState(() => _filterEmail = value),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: _buildColumnHeader('Ubicación', 'Filtrar por ubicación',
                      () => _showFilterOptions(
                        context,
                        'ubicacion',
                        _getUniqueValues(registros, 'ubicacion'),
                        _filterUbicacion,
                        (value) => setState(() => _filterUbicacion = value),
                      ),
                    ),
                  ),
                ],
                rows: filteredRegistros.map((registro) {
                  return DataRow(
                    selected: isAdmin && _selectedRegistros.contains(registro.id),
                    onSelectChanged: isAdmin ? (bool? selected) {
                      if (selected != null) {
                        setState(() {
                          if (selected) {
                            _selectedRegistros.add(registro.id);
                          } else {
                            _selectedRegistros.remove(registro.id);
                          }
                          _selectAll = _selectedRegistros.length == filteredRegistros.length;
                        });
                      }
                    } : null,
                    cells: [
                      if (isAdmin)
                        DataCell(
                          Checkbox(
                            value: _selectedRegistros.contains(registro.id),
                            onChanged: (bool? selected) {
                              if (selected != null) {
                                setState(() {
                                  if (selected) {
                                    _selectedRegistros.add(registro.id);
                                  } else {
                                    _selectedRegistros.remove(registro.id);
                                  }
                                  _selectAll = _selectedRegistros.length == filteredRegistros.length;
                                });
                              }
                            },
                          ),
                        ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              registro.tipo == 'ENTRADA'
                                  ? Icons.login
                                  : registro.tipo == 'PAUSA'
                                      ? Icons.pause
                                      : Icons.logout,
                              color: _getTipoColor(registro.tipo),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(registro.tipo),
                          ],
                        ),
                        onTap: isAdmin ? () => _confirmarEliminarRegistro(registro) : null,
                      ),
                      DataCell(
                        Text(dateFormat.format(registro.fecha)),
                        onTap: isAdmin ? () => _confirmarEliminarRegistro(registro) : null,
                      ),
                      DataCell(
                        Text(registro.userName),
                        onTap: isAdmin ? () => _confirmarEliminarRegistro(registro) : null,
                      ),
                      DataCell(
                        Text(registro.userEmail),
                        onTap: isAdmin ? () => _confirmarEliminarRegistro(registro) : null,
                      ),
                      DataCell(
                        _buildLocationInfo(registro),
                        onTap: isAdmin ? () => _confirmarEliminarRegistro(registro) : null,
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserView(List<RegistroJornada> registros) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return ListView.builder(
      itemCount: registros.length,
      itemBuilder: (context, index) {
        final registro = registros[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _getTipoColor(registro.tipo),
                      child: Icon(
                        registro.tipo == 'ENTRADA'
                            ? Icons.login
                            : registro.tipo == 'PAUSA'
                                ? Icons.pause
                                : Icons.logout,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            registro.tipo,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(registro.fecha),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (registro.locationAddress != null || 
                    (registro.latitude != null && registro.longitude != null)) ...[
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildLocationInfo(registro),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  int _getSortColumnIndex(String column) {
    switch (column) {
      case 'tipo':
        return 1;
      case 'fecha':
        return 2;
      case 'nombre':
        return 3;
      case 'email':
        return 4;
      case 'ubicacion':
        return 5;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jornadaService = JornadaService();
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<bool>(
          future: authService.isCurrentUserAdmin(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              LoggerService.error('Error al verificar permisos de administrador', snapshot.error);
              return const Text('Registro de Jornadas');
            }
            final isAdmin = snapshot.data ?? false;
            return Text(isAdmin ? 'Registro de Jornadas' : 'Mis Jornadas');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FutureBuilder<bool>(
          future: authService.isCurrentUserAdmin(),
          builder: (context, adminSnapshot) {
            if (adminSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error al verificar permisos:\n${adminSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacementNamed('/jornadas');
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            if (!adminSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final isAdmin = adminSnapshot.data ?? false;

            return StreamBuilder<List<RegistroJornada>>(
              stream: isAdmin 
                ? jornadaService.getRegistros()
                : jornadaService.getRegistrosUsuario(_auth.currentUser?.uid ?? ''),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  LoggerService.error('Error al cargar registros', snapshot.error);
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Error al cargar los registros:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/jornadas');
                          },
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final registros = snapshot.data!;

                if (registros.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAdmin ? Icons.group_off : Icons.history_toggle_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isAdmin
                              ? 'No hay registros de ningún usuario'
                              : 'No tienes registros de fichaje',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return isAdmin 
                  ? _buildAdminView(registros)
                  : _buildUserView(registros);
              },
            );
          },
        ),
      ),
    );
  }
} 