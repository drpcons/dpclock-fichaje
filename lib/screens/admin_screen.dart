import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'work_log_screen.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedColumns = ['name', 'email', 'supervisor', 'project', 'workLog', 'company', 'identification'];
  final List<String> _availableColumns = [
    'name',
    'email',
    'supervisor',
    'project',
    'workLog',
    'company',
    'identification'
  ];
  
  String? _sortColumn;
  bool _sortAscending = true;
  Map<String, String> _columnFilters = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _showFilterDialog(BuildContext context, String column) {
    final TextEditingController filterController = TextEditingController(
      text: _columnFilters[column] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Filtrar por ${_getColumnTitle(column)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: filterController,
                decoration: InputDecoration(
                  labelText: 'Buscar en ${_getColumnTitle(column)}',
                  border: const OutlineInputBorder(),
                  suffixIcon: filterController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            filterController.clear();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    if (value.isEmpty) {
                      _columnFilters.remove(column);
                    } else {
                      _columnFilters[column] = value;
                    }
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _columnFilters.remove(column);
                });
                Navigator.pop(context);
              },
              child: const Text('Limpiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  String _getColumnTitle(String column) {
    switch (column) {
      case 'name':
        return 'Nombre';
      case 'email':
        return 'Correo';
      case 'createdAt':
        return 'Registro';
      case 'supervisor':
        return 'Encargado';
      case 'project':
        return 'Obra';
      case 'role':
        return 'Rol';
      case 'status':
        return 'Estado';
      case 'lastLogin':
        return 'Último acceso';
      case 'department':
        return 'Departamento';
      case 'position':
        return 'Cargo';
      case 'workLog':
        return 'Registro de trabajo';
      case 'company':
        return 'Empresa';
      case 'identification':
        return 'Identificación';
      default:
        return column;
    }
  }

  bool _matchesFilters(Map<String, dynamic> data) {
    if (_columnFilters.isEmpty) return true;

    return _columnFilters.entries.every((entry) {
      final column = entry.key;
      final filter = entry.value.toLowerCase();
      final value = data[column];

      if (value == null) return false;

      if (value is Timestamp) {
        final dateStr = value.toDate().toString().toLowerCase();
        return dateStr.contains(filter);
      }

      return value.toString().toLowerCase().contains(filter);
    });
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    
    final query = _searchQuery.toLowerCase();
    return _selectedColumns.any((column) {
      final value = data[column];
      if (value == null) return false;
      
      if (value is Timestamp) {
        return value.toDate().toString().toLowerCase().contains(query);
      }
      
      return value.toString().toLowerCase().contains(query);
    });
  }

  Future<void> _updateUserField(String userId, String field, dynamic value) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        field: value,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Campo actualizado correctamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    }
  }

  Widget _buildEditableCell(String userId, String column, String value) {
    final TextEditingController controller = TextEditingController(text: value);
    
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Editar ${_getColumnTitle(column)}'),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: _getColumnTitle(column),
                border: const OutlineInputBorder(),
                hintText: 'Ingrese ${_getColumnTitle(column).toLowerCase()}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _updateUserField(userId, column, controller.text);
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Campo actualizado correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error al actualizar: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          value.isEmpty ? '-' : value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable(List<DocumentSnapshot> users) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: _selectedColumns.map((column) {
          return DataColumn(
            label: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Filtrar por ${_getColumnTitle(column)}'),
                    content: TextField(
                      decoration: InputDecoration(
                        labelText: 'Buscar en ${_getColumnTitle(column)}',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _columnFilters[column] = value;
                        });
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _columnFilters.remove(column);
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Limpiar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getColumnTitle(column)),
                  const SizedBox(width: 4),
                  Icon(
                    _columnFilters[column]?.isNotEmpty == true 
                        ? Icons.filter_list 
                        : Icons.filter_list_outlined,
                    size: 16,
                    color: _columnFilters[column]?.isNotEmpty == true 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
        rows: users.map((user) {
          final userData = user.data() as Map<String, dynamic>;
          return DataRow(
            cells: _selectedColumns.map((column) {
              if (column == 'workLog') {
                return DataCell(
                  IconButton(
                    icon: const Icon(Icons.history),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WorkLogScreen(
                            userId: user.id,
                            companyName: userData['company']?.toString() ?? '',
                            employeeName: userData['name']?.toString() ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                );
              }
              return DataCell(
                _buildEditableCell(
                  user.id,
                  column,
                  userData[column]?.toString() ?? '',
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showColumnSelector,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
              await AuthService().logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al cerrar sesión: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        child: SafeArea(
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                    labelText: 'Buscar en todas las columnas',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (_columnFilters.isNotEmpty)
            Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Wrap(
                spacing: 8,
                children: _columnFilters.entries.map((entry) {
                  return Chip(
                    label: Text('${_getColumnTitle(entry.key)}: ${entry.value}'),
                    onDeleted: () {
                      setState(() {
                        _columnFilters.remove(entry.key);
                      });
                    },
                  );
                }).toList(),
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: ${snapshot.error}'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {});
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No hay usuarios registrados'),
                  );
                }

                    final users = snapshot.data!.docs;
                    final filteredUsers = users.where((user) {
                      try {
                        final data = user.data() as Map<String, dynamic>;
                        return _matchesSearch(data) && _matchesFilters(data);
                      } catch (e) {
                        return false;
                      }
                }).toList();

                    if (filteredUsers.isEmpty) {
                      return const Center(
                        child: Text('No se encontraron usuarios que coincidan con los filtros'),
                      );
                    }

                    return _buildDataTable(filteredUsers);
              },
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  void _showColumnSelector() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar columnas'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _availableColumns.map((column) {
                    return CheckboxListTile(
                      title: Text(_getColumnTitle(column)),
                      value: _selectedColumns.contains(column),
                      onChanged: (bool? value) {
                        setState(() {
                        if (value == true) {
                          _selectedColumns.add(column);
                        } else {
                          _selectedColumns.remove(column);
                        }
                        });
                        this.setState(() {});
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }
} 