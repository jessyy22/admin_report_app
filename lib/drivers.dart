import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'driver.dart';

/// Screen for managing driver records with CRUD operations
class DriversListScreen extends StatefulWidget {
  const DriversListScreen({super.key});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  // MARK: - Constants
  static const String _driverTable = 'drivers';

  // MARK: - Dependencies
  final SupabaseClient _supabase = Supabase.instance.client;

  // MARK: - State
  String _searchQuery = '';

  String _statusFilter = 'all';
  String _operatorFilter = 'all';
  String _permitFilter = 'all';

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _drivers = [];

  // MARK: - Lifecycle

  @override
  void initState() {
    super.initState();
    _loadDrivers();
  }

  // MARK: - Data Loading

  Future<void> _loadDrivers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await _supabase.from(_driverTable).select('''
        driver_id,
        name,
        contact,
        license_number,
        permit_number,
        permit_address,
        permit_license_number,
        permit_issued_date,
        permit_valid_until,
        permit_control_no,
        permit_or_no,
        permit_amount,
        permit_payment_date,
        operator_id,
        tricycle_id,
        status,
        operators!operator_id (
          name
        ),
        tricycles!tricycle_id (
          body_number
        )
      ''');

      final List<Map<String, dynamic>> driversList = [];

      for (final item in response) {
        if (item is Map<String, dynamic>) {
          final Map<String, dynamic> processedItem = {
            'driver_id': item['driver_id'],
            'name': item['name'],
            'contact': item['contact'],
            'license_number': item['license_number'],

            // Driver's Permit
            'permit_number': item['permit_number'],
            'permit_address': item['permit_address'],
            'permit_license_number': item['permit_license_number'],
            'permit_issued_date': item['permit_issued_date'],
            'permit_valid_until': item['permit_valid_until'],
            'permit_control_no': item['permit_control_no'],
            'permit_or_no': item['permit_or_no'],
            'permit_amount': item['permit_amount'],
            'permit_payment_date': item['permit_payment_date'],

            'operator_id': item['operator_id'],
            'tricycle_id': item['tricycle_id'],
            'status': item['status'],
            'operators': item['operators'],
            'tricycles': item['tricycles'],
          };

          driversList.add(processedItem);
        }
      }

      if (!mounted) return;

      setState(() {
        _drivers = driversList;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('Error loading drivers: $e');

      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load drivers: ${e.toString()}';
        _isLoading = false;
        _drivers = [];
      });
    }
  }

  // MARK: - CRUD Operations

  Future<void> _deleteDriver(int id) async {
    if (!mounted) return;

    try {
      await _supabase
          .from(_driverTable)
          .delete()
          .eq('driver_id', id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver deleted successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      await _loadDrivers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete driver: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _editDriver(
    Map<String, dynamic> driver,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DriverRegistrationScreen(
        driverToEdit: driver,
      ),
    );

    if (result == true && mounted) {
      await _loadDrivers();
    }
  }

  Future<void> _showRegistrationDialog() async {
    if (!mounted) return;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) =>
            const DriverRegistrationScreen(),
        barrierDismissible: false,
      );

      if (result == true && mounted) {
        await _loadDrivers();
      }
    } catch (e) {
      debugPrint(
        'Error showing registration dialog: $e',
      );
    }
  }

  // MARK: - Computed Properties

  int get _totalCount => _drivers.length;

  int get _activeCount => _drivers.where((d) {
        return d['status']
                ?.toString()
                .toLowerCase()
                .trim() ==
            'active';
      }).length;

  int get _inactiveCount => _drivers.where((d) {
        return d['status']
                ?.toString()
                .toLowerCase()
                .trim() ==
            'inactive';
      }).length;

  int get _suspendedCount => _drivers.where((d) {
        return d['status']
                ?.toString()
                .toLowerCase()
                .trim() ==
            'suspended';
      }).length;

  /// Returns all unique operator names.
  List<String> get _operatorNames {
    final names = <String>{};

    for (final driver in _drivers) {
      final name = _getOperatorName(driver);

      if (name != 'N/A' && name.trim().isNotEmpty) {
        names.add(name.trim());
      }
    }

    final result = names.toList();

    result.sort(
      (a, b) => a.toLowerCase().compareTo(
            b.toLowerCase(),
          ),
    );

    return result;
  }

  /// Returns drivers after applying all filters.
  List<Map<String, dynamic>> get _filteredDrivers {
    return _drivers.where((driver) {
      // -----------------------------------------
      // SEARCH FILTER
      // -----------------------------------------

      if (!_matchesSearch(driver)) {
        return false;
      }

      // -----------------------------------------
      // STATUS FILTER
      // -----------------------------------------

      final status = driver['status']
              ?.toString()
              .toLowerCase()
              .trim() ??
          '';

      if (_statusFilter != 'all' &&
          status != _statusFilter) {
        return false;
      }

      // -----------------------------------------
      // OPERATOR FILTER
      // -----------------------------------------

      if (_operatorFilter != 'all') {
        final operatorName =
            _getOperatorName(driver)
                .toLowerCase()
                .trim();

        if (operatorName !=
            _operatorFilter.toLowerCase().trim()) {
          return false;
        }
      }

      // -----------------------------------------
      // PERMIT FILTER
      // -----------------------------------------

      if (!_matchesPermitFilter(driver)) {
        return false;
      }

      return true;
    }).toList();
  }

  // MARK: - Search Filtering

  bool _matchesSearch(
    Map<String, dynamic> driver,
  ) {
    final query = _searchQuery
        .toLowerCase()
        .trim();

    if (query.isEmpty) {
      return true;
    }

    final values = [
      driver['name'],
      driver['contact'],
      driver['license_number'],
      driver['permit_number'],
      driver['permit_license_number'],
      driver['permit_control_no'],
      driver['permit_or_no'],
      driver['permit_address'],
      driver['permit_issued_date'],
      driver['permit_valid_until'],
      driver['permit_amount'],
      driver['permit_payment_date'],
      driver['driver_id'],
      driver['tricycle_id'],
      _getBodyNumber(driver),
      _getOperatorName(driver),
    ];

    return values.any(
      (value) =>
          value?.toString().toLowerCase().contains(query) ??
          false,
    );
  }

  // MARK: - Permit Filtering

  bool _matchesPermitFilter(
    Map<String, dynamic> driver,
  ) {
    if (_permitFilter == 'all') {
      return true;
    }

    final validUntil =
        _parseDate(driver['permit_valid_until']);

    final permitNumber =
        driver['permit_number']?.toString().trim();

    final hasPermit =
        permitNumber != null &&
        permitNumber.isNotEmpty;

    // No permit
    if (_permitFilter == 'no_permit') {
      return !hasPermit || validUntil == null;
    }

    // If permit exists but date is missing,
    // it cannot be classified as valid/expired.
    if (validUntil == null) {
      return false;
    }

    final today = _dateOnly(DateTime.now());

    final difference =
        validUntil.difference(today).inDays;

    // Expired
    if (_permitFilter == 'expired') {
      return difference < 0;
    }

    // Expiring within the next 30 days
    if (_permitFilter == 'expiring') {
      return difference >= 0 && difference <= 30;
    }

    // Valid = more than 30 days remaining
    if (_permitFilter == 'valid') {
      return difference > 30;
    }

    return true;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // MARK: - Filter Helpers

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _statusFilter != 'all' ||
        _operatorFilter != 'all' ||
        _permitFilter != 'all';
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _statusFilter = 'all';
      _operatorFilter = 'all';
      _permitFilter = 'all';
    });
  }

  // MARK: - Helper Methods for Data Extraction

  String _getOperatorName(
    Map<String, dynamic> driver,
  ) {
    try {
      final operators = driver['operators'];

      if (operators == null) {
        return 'N/A';
      }

      if (operators is Map<String, dynamic>) {
        return operators['name']?.toString() ?? 'N/A';
      }

      if (operators is List &&
          operators.isNotEmpty) {
        final first = operators.first;

        if (first is Map<String, dynamic>) {
          return first['name']?.toString() ?? 'N/A';
        }
      }

      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getBodyNumber(
    Map<String, dynamic> driver,
  ) {
    try {
      final tricycles = driver['tricycles'];

      if (tricycles == null) {
        return 'N/A';
      }

      if (tricycles is Map<String, dynamic>) {
        return tricycles['body_number']
                ?.toString() ??
            'N/A';
      }

      if (tricycles is List &&
          tricycles.isNotEmpty) {
        final first = tricycles.first;

        if (first is Map<String, dynamic>) {
          return first['body_number']
                  ?.toString() ??
              'N/A';
        }
      }

      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  String _getPermitNumber(
    Map<String, dynamic> driver,
  ) {
    final permitNumber =
        driver['permit_number']
            ?.toString()
            .trim();

    if (permitNumber == null ||
        permitNumber.isEmpty) {
      return 'N/A';
    }

    return permitNumber;
  }

  String _getPermitValidUntil(
    Map<String, dynamic> driver,
  ) {
    final validUntil =
        driver['permit_valid_until']
            ?.toString()
            .trim();

    if (validUntil == null ||
        validUntil.isEmpty) {
      return 'N/A';
    }

    return validUntil;
  }

  // =====================================================
  // TABLE CELL HELPER
  // =====================================================

  Widget _buildTableCell(dynamic value) {
    final text = value?.toString().trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text == null || text.isEmpty
              ? 'N/A'
              : text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  // =====================================================
  // VIEW DRIVER INFORMATION
  // =====================================================

  Future<void> _showDriverInformation(
    Map<String, dynamic> driver,
  ) async {
    final tricycleId = driver['tricycle_id'];

    if (tricycleId == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This driver does not have a tricycle assigned.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      return;
    }

    try {
      final response = await _supabase
          .from('reports')
          .select('''
            report_id,
            tricycle_id,
            violation,
            location,
            incidentdate,
            incidenttime,
            evidence_url,
            status,
            complainantname,
            address,
            contact,
            created_at,
            updated_at,
            action_taken,
            reviewed_at,
            assigned_staff,
            report_type,
            late_report_reason,
            driver_feedback
          ''')
          .eq('tricycle_id', tricycleId)
          .order(
            'created_at',
            ascending: false,
          );

      if (!mounted) return;

      final violations =
          List<Map<String, dynamic>>.from(
        response,
      );

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(
              driver['name']?.toString() ??
                  'Driver Information',
            ),
            content: SizedBox(
              width: 700,
              height: 550,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Driver Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    Text(
                      'Driver ID: ${driver['driver_id']}',
                    ),

                    Text(
                      'Name: ${driver['name'] ?? 'N/A'}',
                    ),

                    Text(
                      'Contact: ${driver['contact'] ?? 'N/A'}',
                    ),

                    Text(
                      'License: ${driver['license_number'] ?? 'N/A'}',
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Driver\'s Permit',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Permit No.: ${driver['permit_number'] ?? 'N/A'}',
                    ),

                    Text(
                      'Permit Address: ${driver['permit_address'] ?? 'N/A'}',
                    ),

                    Text(
                      'Permit License No.: ${driver['permit_license_number'] ?? 'N/A'}',
                    ),

                    Text(
                      'Issued Date: ${driver['permit_issued_date'] ?? 'N/A'}',
                    ),

                    Text(
                      'Valid Until: ${driver['permit_valid_until'] ?? 'N/A'}',
                    ),

                    Text(
                      'Control No.: ${driver['permit_control_no'] ?? 'N/A'}',
                    ),

                    Text(
                      'O.R. No.: ${driver['permit_or_no'] ?? 'N/A'}',
                    ),

                    Text(
                      'Amount: ${driver['permit_amount'] ?? 'N/A'}',
                    ),

                    Text(
                      'Payment Date: ${driver['permit_payment_date'] ?? 'N/A'}',
                    ),

                    Text(
                      'Operator: ${_getOperatorName(driver)}',
                    ),

                    Text(
                      'Body Number: ${_getBodyNumber(driver)}',
                    ),

                    Text(
                      'Tricycle ID: ${driver['tricycle_id'] ?? 'N/A'}',
                    ),

                    Text(
                      'Status: ${driver['status'] ?? 'N/A'}',
                    ),

                    const SizedBox(height: 20),

                    const Divider(),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                        ),

                        const SizedBox(width: 8),

                        Text(
                          'Total Violations: ${violations.length}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: violations.isEmpty
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    if (violations.isEmpty)
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(
                          vertical: 20,
                        ),
                        child: Text(
                          'No violations recorded for this tricycle.',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      ...violations
                          .asMap()
                          .entries
                          .map(
                        (entry) {
                          return _buildViolationCard(
                            entry.key + 1,
                            entry.value,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load violations: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // =====================================================
  // VIOLATION FIELD FORMATTER
  // =====================================================

  String _formatViolationField(
    String field,
  ) {
    switch (field) {
      case 'report_id':
        return 'Report ID';

      case 'tricycle_id':
        return 'Tricycle ID';

      case 'violation':
        return 'Violation';

      case 'location':
        return 'Location';

      case 'incidentdate':
        return 'Incident Date';

      case 'incidenttime':
        return 'Incident Time';

      case 'evidence_url':
        return 'Evidence';

      case 'status':
        return 'Status';

      case 'complainantname':
        return 'Complainant';

      case 'address':
        return 'Address';

      case 'contact':
        return 'Contact';

      case 'created_at':
        return 'Created At';

      case 'updated_at':
        return 'Updated At';

      case 'action_taken':
        return 'Action Taken';

      case 'reviewed_at':
        return 'Reviewed At';

      case 'assigned_staff':
        return 'Assigned Staff';

      case 'report_type':
        return 'Report Type';

      case 'late_report_reason':
        return 'Late Report Reason';

      case 'driver_feedback':
        return 'Driver Feedback';

      default:
        return field
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  // =====================================================
  // VIOLATION CARD
  // =====================================================

  Widget _buildViolationCard(
    int number,
    Map<String, dynamic> violation,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text('$number'),
                ),

                const SizedBox(width: 10),

                const Text(
                  'Violation Record',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const Divider(),

            ...violation.entries.map(
              (entry) {
                if (entry.value == null) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 6,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          _formatViolationField(
                            entry.key,
                          ),
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w600,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                      Expanded(
                        child: Text(
                          entry.value.toString(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - UI Building

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton:
          _buildFloatingActionButton(),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading drivers...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Column(
        children: [
          _buildSummaryCards(),

          const SizedBox(height: 20),

          _buildSearchAndFilters(),

          const SizedBox(height: 14),

          Expanded(
            child: _buildDataTable(),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ERROR WIDGET
  // =====================================================

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),

            const SizedBox(height: 16),

            Text(
              _errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _loadDrivers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // SUMMARY CARDS
  // =====================================================

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final cards = [
          _buildStatCard(
            'Total',
            _totalCount.toString(),
            Colors.blue,
          ),
          _buildStatCard(
            'Active',
            _activeCount.toString(),
            Colors.green,
          ),
          _buildStatCard(
            'Inactive',
            _inactiveCount.toString(),
            Colors.orange,
          ),
          _buildStatCard(
            'Suspended',
            _suspendedCount.toString(),
            Colors.red,
          ),
        ];

        // Desktop
        if (width >= 1000) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          );
        }

        // Tablet
        if (width >= 600) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        // Mobile
        return Column(
          children: [
            cards[0],
            const SizedBox(height: 10),
            cards[1],
            const SizedBox(height: 10),
            cards[2],
            const SizedBox(height: 10),
            cards[3],
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 14,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.grey.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
// =====================================================
// SEARCH + FILTERS
// =====================================================

Widget _buildSearchAndFilters() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;

      if (width < 600) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSearchField(),
            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: _buildFilterDropdown(
                    label: 'Status',
                    value: _statusFilter,
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive'),
                      ),
                      DropdownMenuItem(
                        value: 'suspended',
                        child: Text('Suspended'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _statusFilter = value;
                      });
                    },
                  ),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: _buildOperatorDropdown(),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Row(
              children: [
                Expanded(
                  child: _buildPermitDropdown(),
                ),

                const SizedBox(width: 6),

                _buildClearFiltersButton(),
              ],
            ),
          ],
        );
      }

      return Row(
        children: [
          Expanded(
            flex: 4,
            child: _buildSearchField(),
          ),

          const SizedBox(width: 6),

          SizedBox(
            width: 115,
            child: _buildFilterDropdown(
              label: 'Status',
              value: _statusFilter,
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All'),
                ),
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Active'),
                ),
                DropdownMenuItem(
                  value: 'inactive',
                  child: Text('Inactive'),
                ),
                DropdownMenuItem(
                  value: 'suspended',
                  child: Text('Suspended'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _statusFilter = value;
                });
              },
            ),
          ),

          const SizedBox(width: 6),

          SizedBox(
            width: 150,
            child: _buildOperatorDropdown(),
          ),

          const SizedBox(width: 6),

          SizedBox(
            width: 145,
            child: _buildPermitDropdown(),
          ),

          const SizedBox(width: 6),

          _buildClearFiltersButton(),
        ],
      );
    },
  );
}


// =====================================================
// SMALL SEARCH FIELD
// =====================================================

Widget _buildSearchField() {
  return SizedBox(
    height: 40,
    child: TextField(
      decoration: InputDecoration(
        hintText: 'Search drivers...',
        hintStyle: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade500,
        ),

        prefixIcon: Icon(
          Icons.search,
          size: 17,
          color: Colors.grey.shade600,
        ),

        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.clear,
                  size: 15,
                  color: Colors.grey.shade600,
                ),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,

        filled: true,
        fillColor: Colors.grey.shade50,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.2,
          ),
        ),
      ),

      style: const TextStyle(
        fontSize: 12,
      ),

      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    ),
  );
}


// =====================================================
// SMALL FILTER DROPDOWN
// =====================================================

Widget _buildFilterDropdown({
  required String label,
  required String value,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?> onChanged,
}) {
  return SizedBox(
    height: 40,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,

      icon: const Icon(
        Icons.keyboard_arrow_down,
        size: 16,
      ),

      style: const TextStyle(
        fontSize: 11,
        color: Colors.black87,
      ),

      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 10,
          color: Colors.grey.shade600,
        ),

        filled: true,
        fillColor: Colors.grey.shade50,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 0,
        ),

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 1.2,
          ),
        ),
      ),

      items: items,
      onChanged: onChanged,
    ),
  );
}


// =====================================================
// OPERATOR DROPDOWN
// =====================================================

Widget _buildOperatorDropdown() {
  final items = <DropdownMenuItem<String>>[
    const DropdownMenuItem(
      value: 'all',
      child: Text('All Operators'),
    ),
  ];

  for (final operator in _operatorNames) {
    items.add(
      DropdownMenuItem(
        value: operator,
        child: Text(
          operator,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  return _buildFilterDropdown(
    label: 'Operator',
    value: _operatorFilter,
    items: items,
    onChanged: (value) {
      if (value == null) return;

      setState(() {
        _operatorFilter = value;
      });
    },
  );
}


// =====================================================
// PERMIT DROPDOWN
// =====================================================

Widget _buildPermitDropdown() {
  return _buildFilterDropdown(
    label: 'Permit',
    value: _permitFilter,
    items: const [
      DropdownMenuItem(
        value: 'all',
        child: Text('All'),
      ),
      DropdownMenuItem(
        value: 'valid',
        child: Text('Valid'),
      ),
      DropdownMenuItem(
        value: 'expiring',
        child: Text('Expiring'),
      ),
      DropdownMenuItem(
        value: 'expired',
        child: Text('Expired'),
      ),
      DropdownMenuItem(
        value: 'no_permit',
        child: Text('No Permit'),
      ),
    ],
    onChanged: (value) {
      if (value == null) return;

      setState(() {
        _permitFilter = value;
      });
    },
  );
}


// =====================================================
// SMALL CLEAR BUTTON
// =====================================================

Widget _buildClearFiltersButton() {
  return SizedBox(
    height: 40,
    child: OutlinedButton(
      onPressed: _hasActiveFilters
          ? _clearFilters
          : null,

      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
        ),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
        ),
        side: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),

      child: const Icon(
        Icons.clear_all,
        size: 16,
      ),
    ),
  );
}

  // =====================================================
  // DATA TABLE
  // =====================================================

  Widget _buildDataTable() {
    final filteredDrivers =
        _filteredDrivers;

    if (filteredDrivers.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Icon(
                  _hasActiveFilters
                      ? Icons.filter_alt_off
                      : Icons.person_off,
                  size: 64,
                  color:
                      Colors.grey.shade400,
                ),

                const SizedBox(height: 16),

                Text(
                  _hasActiveFilters
                      ? 'No drivers match the selected filters'
                      : 'No drivers registered',
                  style: TextStyle(
                    fontSize: 18,
                    color:
                        Colors.grey.shade600,
                    fontWeight:
                        FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (_hasActiveFilters)
                  Padding(
                    padding:
                        const EdgeInsets.only(
                      top: 6,
                    ),
                    child: Text(
                      'Try changing or clearing your filters.',
                      style: TextStyle(
                        color:
                            Colors.grey.shade400,
                      ),
                      textAlign:
                          TextAlign.center,
                    ),
                  ),

                if (!_hasActiveFilters) ...[
                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed:
                        _showRegistrationDialog,
                    icon: const Icon(
                      Icons.person_add,
                    ),
                    label: const Text(
                      'Register First Driver',
                    ),
                  ),
                ],

                if (_hasActiveFilters) ...[
                  const SizedBox(height: 16),

                  OutlinedButton.icon(
                    onPressed:
                        _clearFilters,
                    icon: const Icon(
                      Icons.clear_all,
                    ),
                    label: const Text(
                      'Clear Filters',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(14),
        child: LayoutBuilder(
          builder:
              (context, constraints) {
            final width =
                constraints.maxWidth;

            final bool isMobile =
                width < 700;

            final bool isTablet =
                width >= 700 &&
                    width < 1100;

            // =====================================================
            // HEADER CELL
            // =====================================================

            Widget headerCell(
              String title, {
              required int flex,
            }) {
              return Expanded(
                flex: flex,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 5,
                  ),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              );
            }

            // =====================================================
            // DESKTOP HEADER
            // =====================================================

            Widget desktopHeader() {
              return Container(
                height: 52,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                color:
                    Colors.grey.shade100,
                child: Row(
                  children: [
                    headerCell(
                      'Name',
                      flex: 4,
                    ),
                    headerCell(
                      'Body #',
                      flex: 2,
                    ),
                    headerCell(
                      'License No.',
                      flex: 3,
                    ),
                    headerCell(
                      'Permit No.',
                      flex: 2,
                    ),
                    headerCell(
                      'Permit Address',
                      flex: 3,
                    ),
                    headerCell(
                      'Permit License No.',
                      flex: 3,
                    ),
                    headerCell(
                      'Issued Date',
                      flex: 2,
                    ),
                    headerCell(
                      'Valid Until',
                      flex: 2,
                    ),
                    headerCell(
                      'Control No.',
                      flex: 2,
                    ),
                    headerCell(
                      'O.R. No.',
                      flex: 2,
                    ),
                    headerCell(
                      'Amount',
                      flex: 2,
                    ),
                    headerCell(
                      'Payment Date',
                      flex: 2,
                    ),
                    headerCell(
                      'Operator',
                      flex: 3,
                    ),
                    headerCell(
                      'Status',
                      flex: 2,
                    ),
                    headerCell(
                      'Actions',
                      flex: 3,
                    ),
                  ],
                ),
              );
            }

            // =====================================================
            // TABLET HEADER
            // =====================================================

            Widget tabletHeader() {
              return Container(
                height: 52,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                color:
                    Colors.grey.shade100,
                child: Row(
                  children: [
                    headerCell(
                      'Name',
                      flex: 4,
                    ),
                    headerCell(
                      'Body #',
                      flex: 2,
                    ),
                    headerCell(
                      'License',
                      flex: 3,
                    ),
                    headerCell(
                      'Permit No.',
                      flex: 3,
                    ),
                    headerCell(
                      'Valid Until',
                      flex: 3,
                    ),
                    headerCell(
                      'Operator',
                      flex: 3,
                    ),
                    headerCell(
                      'Status',
                      flex: 2,
                    ),
                    headerCell(
                      'Actions',
                      flex: 3,
                    ),
                  ],
                ),
              );
            }

            // =====================================================
            // MOBILE HEADER
            // =====================================================

            Widget mobileHeader() {
              return Container(
                height: 50,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                color:
                    Colors.grey.shade100,
                child: Row(
                  children: [
                    headerCell(
                      'Name',
                      flex: 4,
                    ),
                    headerCell(
                      'Body #',
                      flex: 2,
                    ),
                    headerCell(
                      'Status',
                      flex: 2,
                    ),
                    headerCell(
                      'Actions',
                      flex: 4,
                    ),
                  ],
                ),
              );
            }

            // =====================================================
            // DESKTOP ROW
            // =====================================================

            Widget desktopRow(
              Map<String, dynamic> driver,
            ) {
              return SizedBox(
                height: 68,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildTableCell(
                        driver['name'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        _getBodyNumber(
                          driver,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        driver[
                            'license_number'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        driver[
                            'permit_number'],
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        driver[
                            'permit_address'],
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        driver[
                            'permit_license_number'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        driver[
                            'permit_issued_date'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        driver[
                            'permit_valid_until'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        driver[
                            'permit_control_no'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        driver[
                            'permit_or_no'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        driver[
                            'permit_amount'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        driver[
                            'permit_payment_date'],
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        _getOperatorName(
                          driver,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment:
                            Alignment.centerLeft,
                        child:
                            _buildStatusChip(
                          driver['status'],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child:
                          _buildActionButtons(
                        driver,
                      ),
                    ),
                  ],
                ),
              );
            }

            // =====================================================
            // TABLET ROW
            // =====================================================

            Widget tabletRow(
              Map<String, dynamic> driver,
            ) {
              return SizedBox(
                height: 68,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildTableCell(
                        driver['name'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        _getBodyNumber(
                          driver,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        driver[
                            'license_number'],
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        driver[
                            'permit_number'],
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        driver[
                            'permit_valid_until'],
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child: _buildTableCell(
                        _getOperatorName(
                          driver,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment:
                            Alignment.centerLeft,
                        child:
                            _buildStatusChip(
                          driver['status'],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 3,
                      child:
                          _buildActionButtons(
                        driver,
                      ),
                    ),
                  ],
                ),
              );
            }

            // =====================================================
            // MOBILE ROW
            // =====================================================

            Widget mobileRow(
              Map<String, dynamic> driver,
            ) {
              return SizedBox(
                height: 62,
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildTableCell(
                        driver['name'],
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: _buildTableCell(
                        _getBodyNumber(
                          driver,
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment:
                            Alignment.centerLeft,
                        child:
                            _buildStatusChip(
                          driver['status'],
                        ),
                      ),
                    ),

                    Expanded(
                      flex: 4,
                      child:
                          _buildActionButtons(
                        driver,
                      ),
                    ),
                  ],
                ),
              );
            }

            // =====================================================
            // HEADER
            // =====================================================

            Widget header;

            if (isMobile) {
              header = mobileHeader();
            } else if (isTablet) {
              header = tabletHeader();
            } else {
              header = desktopHeader();
            }

            // =====================================================
            // ROW
            // =====================================================

            Widget buildRow(
              Map<String, dynamic> driver,
            ) {
              if (isMobile) {
                return mobileRow(driver);
              }

              if (isTablet) {
                return tabletRow(driver);
              }

              return desktopRow(driver);
            }

            // =====================================================
            // TABLE
            // =====================================================

            return Column(
              children: [
                // Fixed header
                header,

                // ONLY UP/DOWN SCROLL
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      padding:
                          EdgeInsets.zero,
                      itemCount:
                          filteredDrivers.length,
                      separatorBuilder:
                          (context, index) {
                        return Divider(
                          height: 1,
                          thickness: 1,
                          color: Colors
                              .grey
                              .shade200,
                        );
                      },
                      itemBuilder:
                          (context, index) {
                        return buildRow(
                          filteredDrivers[
                              index],
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // =====================================================
  // STATUS CHIP
  // =====================================================

  Widget _buildStatusChip(
    dynamic status,
  ) {
    final statusString = status
            ?.toString()
            .toLowerCase()
            .trim() ??
        '';

    Color color;
    String label;

    switch (statusString) {
      case 'active':
        color = Colors.green;
        label = 'ACTIVE';
        break;

      case 'inactive':
        color = Colors.orange;
        label = 'INACTIVE';
        break;

      case 'suspended':
        color = Colors.red;
        label = 'SUSPENDED';
        break;

      default:
        color = Colors.grey;
        label = statusString.isEmpty
            ? 'UNKNOWN'
            : statusString.toUpperCase();
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withOpacity(0.10),
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              color.withOpacity(0.30),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow:
            TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight:
              FontWeight.w600,
        ),
      ),
    );
  }

  // =====================================================
  // ACTION BUTTONS
  // =====================================================

  Widget _buildActionButtons(
    Map<String, dynamic> driver,
  ) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // VIEW
          Tooltip(
            message:
                'View driver information',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green
                    .withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(
                  6,
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons
                      .visibility_outlined,
                  color: Colors.green,
                  size: 18,
                ),
                onPressed: () =>
                    _showDriverInformation(
                  driver,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                splashRadius: 16,
              ),
            ),
          ),

          const SizedBox(width: 3),

          // EDIT
          Tooltip(
            message: 'Edit driver',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue
                    .withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(
                  6,
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.blue,
                  size: 18,
                ),
                onPressed: () =>
                    _editDriver(driver),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                splashRadius: 16,
              ),
            ),
          ),

          const SizedBox(width: 3),

          // DELETE
          Tooltip(
            message: 'Delete driver',
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red
                    .withOpacity(0.08),
                borderRadius:
                    BorderRadius.circular(
                  6,
                ),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons
                      .delete_outline,
                  color: Colors.red,
                  size: 18,
                ),
                onPressed: () =>
                    _showDeleteConfirmation(
                  driver['driver_id'],
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                splashRadius: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // DELETE CONFIRMATION
  // =====================================================

  Future<void> _showDeleteConfirmation(
    int driverId,
  ) async {
    if (!mounted) return;

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
        title:
            const Text('Delete Driver'),
        content: const Text(
          'Are you sure you want to delete this driver? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),
            child:
                const Text('Cancel'),
          ),

          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),
            style:
                TextButton.styleFrom(
              foregroundColor:
                  Colors.red,
              backgroundColor:
                  Colors.red
                      .withOpacity(0.05),
            ),
            child:
                const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true &&
        mounted) {
      await _deleteDriver(
        driverId,
      );
    }
  }

  // =====================================================
  // FLOATING ACTION BUTTON
  // =====================================================

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed:
          _showRegistrationDialog,
      icon: const Icon(
        Icons.person_add,
        size: 20,
      ),
      label: const Text(
        'Register Driver',
        style: TextStyle(
          fontSize: 12,
          fontWeight:
              FontWeight.w500,
        ),
      ),
      backgroundColor:
          Theme.of(context)
              .primaryColor,
      foregroundColor:
          Colors.white,
      elevation: 4,
    );
  }
}