import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'reports_view.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplaintListPage extends StatefulWidget {
  const ComplaintListPage({super.key});

  @override
  State<ComplaintListPage> createState() =>
      _ComplaintListPageState();
}

class _ComplaintListPageState extends State<ComplaintListPage> {
  // =========================================================
  // CONTROLLERS
  // =========================================================

  final TextEditingController _searchController =
      TextEditingController();

  // =========================================================
  // FILTER STATE
  // =========================================================

  String _searchQuery = '';

  String _statusFilter = 'all';

  String _dateFilter = 'all';

  String _reportTypeFilter = 'all';

  // =========================================================
  // LIFECYCLE
  // =========================================================

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildSearchAndFilters(),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('reports')
                  .stream(
                    primaryKey: ['report_id'],
                  )
                  .order(
                    'created_at',
                    ascending: false,
                  ),

              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Connection Error: ${snapshot.error}',
                    ),
                  );
                }

                final allDocs =
                    snapshot.data ?? [];

                // =====================================================
                // APPLY FILTERS
                // =====================================================

                final filteredDocs =
                    allDocs.where(_matchesFilters).toList();

                return _buildComplaintTable(
                  filteredDocs,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FILTER LOGIC
  // =========================================================

  bool _matchesFilters(
    Map<String, dynamic> data,
  ) {
    // ---------------------------------------------------------
    // SEARCH
    // ---------------------------------------------------------

    if (!_matchesSearch(data)) {
      return false;
    }

    // ---------------------------------------------------------
    // STATUS
    // ---------------------------------------------------------

    if (_statusFilter != 'all') {
      final status =
          (data['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (status != _statusFilter) {
        return false;
      }
    }

    // ---------------------------------------------------------
    // REPORT TYPE
    // ---------------------------------------------------------

    if (_reportTypeFilter != 'all') {
      final reportType =
          (data['report_type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

      if (reportType !=
          _reportTypeFilter.toLowerCase()) {
        return false;
      }
    }

    // ---------------------------------------------------------
    // DATE
    // ---------------------------------------------------------

    if (!_matchesDateFilter(data)) {
      return false;
    }

    return true;
  }

  // =========================================================
  // SEARCH
  // =========================================================

  bool _matchesSearch(
    Map<String, dynamic> data,
  ) {
    final query =
        _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    final values = [
      data['body_number'],
      data['tricycle_id'],
      data['report_name'],
      data['violation'],
      data['location'],
      data['status'],
      data['report_type'],
      data['report_id'],
    ];

    return values.any(
      (value) =>
          value?.toString().toLowerCase().contains(
                query,
              ) ??
          false,
    );
  }

  // =========================================================
  // DATE FILTER
  // =========================================================

  bool _matchesDateFilter(
    Map<String, dynamic> data,
  ) {
    if (_dateFilter == 'all') {
      return true;
    }

    final createdAt =
        _parseDate(data['created_at']);

    if (createdAt == null) {
      return false;
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final date = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );

    // ---------------------------------------------------------
    // TODAY
    // ---------------------------------------------------------

    if (_dateFilter == 'today') {
      return date == today;
    }

    // ---------------------------------------------------------
    // THIS WEEK
    // ---------------------------------------------------------

    if (_dateFilter == 'week') {
      final startOfWeek =
          today.subtract(
        Duration(
          days: today.weekday - 1,
        ),
      );

      final endOfWeek =
          startOfWeek.add(
        const Duration(days: 7),
      );

      return !date.isBefore(startOfWeek) &&
          date.isBefore(endOfWeek);
    }

    // ---------------------------------------------------------
    // THIS MONTH
    // ---------------------------------------------------------

    if (_dateFilter == 'month') {
      return date.year == today.year &&
          date.month == today.month;
    }

    return true;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(text);
  }

  // =========================================================
  // ACTIVE FILTER CHECK
  // =========================================================

  bool get _hasActiveFilters {
    return _searchQuery.trim().isNotEmpty ||
        _statusFilter != 'all' ||
        _dateFilter != 'all' ||
        _reportTypeFilter != 'all';
  }

  // =========================================================
  // CLEAR FILTERS
  // =========================================================

  void _clearFilters() {
    setState(() {
      _searchQuery = '';

      _statusFilter = 'all';

      _dateFilter = 'all';

      _reportTypeFilter = 'all';

      _searchController.clear();
    });
  }

  // =========================================================
  // SEARCH + FILTERS
  // =========================================================

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        6,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth;

          // =====================================================
          // MOBILE
          // =====================================================

          if (width < 700) {
            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                _buildSearchField(),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Expanded(
                      child:
                          _buildStatusDropdown(),
                    ),

                    const SizedBox(width: 6),

                    Expanded(
                      child:
                          _buildDateDropdown(),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Expanded(
                      child:
                          _buildReportTypeDropdown(),
                    ),

                    const SizedBox(width: 6),

                    _buildClearFiltersButton(),
                  ],
                ),
              ],
            );
          }

          // =====================================================
          // DESKTOP / TABLET
          // =====================================================

          return Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildSearchField(),
              ),

              const SizedBox(width: 6),

              SizedBox(
                width: 120,
                child: _buildStatusDropdown(),
              ),

              const SizedBox(width: 6),

              SizedBox(
                width: 125,
                child: _buildDateDropdown(),
              ),

              const SizedBox(width: 6),

              SizedBox(
                width: 140,
                child:
                    _buildReportTypeDropdown(),
              ),

              const SizedBox(width: 6),

              _buildClearFiltersButton(),
            ],
          );
        },
      ),
    );
  }

  // =========================================================
  // SMALL SEARCH FIELD
  // =========================================================

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,

        decoration: InputDecoration(
          hintText:
              'Search body number, reporter, violation...',

          hintStyle: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),

          prefixIcon: Icon(
            Icons.search,
            size: 17,
            color: Colors.grey.shade600,
          ),

          suffixIcon:
              _searchQuery.isNotEmpty
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.clear,
                        size: 15,
                        color:
                            Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                        });
                      },
                    )
                  : null,

          filled: true,

          fillColor: Colors.grey.shade50,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(7),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(7),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(7),
            borderSide: BorderSide(
              color:
                  Theme.of(context).primaryColor,
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

  // =========================================================
  // STATUS DROPDOWN
  // =========================================================

  Widget _buildStatusDropdown() {
    return _buildFilterDropdown(
      label: 'Status',
      value: _statusFilter,
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All'),
        ),

        DropdownMenuItem(
          value: 'pending',
          child: Text('Pending'),
        ),

        DropdownMenuItem(
          value: 'under investigation',
          child: Text(
            'Under Investigation',
          ),
        ),

        DropdownMenuItem(
          value: 'summoned',
          child: Text('Summoned'),
        ),

        DropdownMenuItem(
          value: 'resolved',
          child: Text('Resolved'),
        ),

        DropdownMenuItem(
          value: 'dismissed',
          child: Text('Dismissed'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  // =========================================================
  // DATE DROPDOWN
  // =========================================================

  Widget _buildDateDropdown() {
    return _buildFilterDropdown(
      label: 'Date',
      value: _dateFilter,
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All Dates'),
        ),

        DropdownMenuItem(
          value: 'today',
          child: Text('Today'),
        ),

        DropdownMenuItem(
          value: 'week',
          child: Text('This Week'),
        ),

        DropdownMenuItem(
          value: 'month',
          child: Text('This Month'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _dateFilter = value;
        });
      },
    );
  }

  // =========================================================
  // REPORT TYPE DROPDOWN
  // =========================================================

  Widget _buildReportTypeDropdown() {
    return _buildFilterDropdown(
      label: 'Report Type',
      value: _reportTypeFilter,
      items: const [
        DropdownMenuItem(
          value: 'all',
          child: Text('All Types'),
        ),

        DropdownMenuItem(
          value: 'complaint',
          child: Text('Complaint'),
        ),

        DropdownMenuItem(
          value: 'incident',
          child: Text('Incident'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;

        setState(() {
          _reportTypeFilter = value;
        });
      },
    );
  }

  // =========================================================
  // COMMON FILTER DROPDOWN
  // =========================================================

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

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 0,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(7),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(7),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(7),
            borderSide: BorderSide(
              color:
                  Theme.of(context).primaryColor,
              width: 1.2,
            ),
          ),
        ),

        items: items,

        onChanged: onChanged,
      ),
    );
  }

  // =========================================================
  // SMALL CLEAR BUTTON
  // =========================================================

  Widget _buildClearFiltersButton() {
    final hasFilters =
        _hasActiveFilters;

    return SizedBox(
      height: 40,
      width: 40,
      child: OutlinedButton(
        onPressed:
            hasFilters ? _clearFilters : null,

        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,

          minimumSize:
              const Size(40, 40),

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(7),
          ),

          side: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),

        child: Icon(
          Icons.clear_all,
          size: 16,
          color: hasFilters
              ? Colors.grey.shade700
              : Colors.grey.shade400,
        ),
      ),
    );
  }

  // =========================================================
  // COMPLAINT TABLE
  // =========================================================

  Widget _buildComplaintTable(
    List<Map<String, dynamic>> filteredDocs,
  ) {
    if (filteredDocs.isEmpty) {
      return _buildEmptyState();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),

      child: PaginatedDataTable(
        header: const Text(
          'Complaint Records',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),

        rowsPerPage: 10,

        showCheckboxColumn: false,

        columns: const [
          DataColumn(
            label: Text('Body Number'),
          ),

          DataColumn(
            label: Text('Violation'),
          ),

          DataColumn(
            label: Text('Reported By'),
          ),

          DataColumn(
            label: Text('Location'),
          ),

          DataColumn(
            label: Text('Status'),
          ),

          DataColumn(
            label: Text('Date'),
          ),
        ],

        source: ComplaintDataSource(
          filteredDocs,
          context,
        ),
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [
              Icon(
                _hasActiveFilters
                    ? Icons.filter_alt_off
                    : Icons.report_off,
                size: 64,
                color: Colors.grey.shade400,
              ),

              const SizedBox(height: 16),

              Text(
                _hasActiveFilters
                    ? 'No complaints match the selected filters'
                    : 'No complaint records found',

                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),

                textAlign: TextAlign.center,
              ),

              if (_hasActiveFilters) ...[
                const SizedBox(height: 6),

                Text(
                  'Try changing or clearing your filters.',

                  style: TextStyle(
                    color: Colors.grey.shade400,
                  ),

                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                OutlinedButton.icon(
                  onPressed: _clearFilters,

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
}

// =============================================================
// COMPLAINT DATA SOURCE
// =============================================================

class ComplaintDataSource
    extends DataTableSource {
  final List<Map<String, dynamic>> docs;

  final BuildContext context;

  ComplaintDataSource(
    this.docs,
    this.context,
  );

  // =========================================================
  // ROW
  // =========================================================

  @override
  DataRow? getRow(int index) {
    if (index >= docs.length) {
      return null;
    }

    final data = docs[index];

    final String reporterName =
        _getReporterName(data);

    final String location =
        _getLocation(data);

    return DataRow(
      onSelectChanged: (_) {
        _showComplaintReview(data);
      },

      cells: [
        // =====================================================
        // BODY NUMBER
        // =====================================================

        DataCell(
          Text(
            data['body_number']
                    ?.toString() ??
                'N/A',

            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // =====================================================
        // VIOLATION
        // =====================================================

        DataCell(
          SizedBox(
            width: 150,

            child: Text(
              data['violation']
                      ?.toString() ??
                  'N/A',

              overflow:
                  TextOverflow.ellipsis,
            ),
          ),
        ),

        // =====================================================
        // REPORTED BY
        // =====================================================

        DataCell(
          Row(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons.person,
                size: 18,
                color: Colors.blue,
              ),

              const SizedBox(width: 6),

              SizedBox(
                width: 130,

                child: Text(
                  reporterName,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // =====================================================
        // LOCATION
        // =====================================================

        DataCell(
          Row(
            mainAxisSize:
                MainAxisSize.min,

            children: [
              const Icon(
                Icons.location_on,
                size: 18,
                color: Colors.red,
              ),

              const SizedBox(width: 5),

              SizedBox(
                width: 140,

                child: Text(
                  location,

                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 5),

              if (data['latitude'] != null &&
                  data['longitude'] != null)
                TextButton.icon(
                  onPressed: () {
                    _openIncidentLocation(
                      data['latitude'],
                      data['longitude'],
                    );
                  },

                  icon: const Icon(
                    Icons.map,
                    size: 18,
                  ),

                  label: const Text(
                    'View Map',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // =====================================================
        // STATUS
        // =====================================================

        DataCell(
          _buildStatusChip(
            data['status']
                    ?.toString() ??
                'Pending',
          ),
        ),

        // =====================================================
        // DATE
        // =====================================================

        DataCell(
          Text(
            _formatDate(
              data['created_at'],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // GET REPORTER NAME
  // =========================================================

  String _getReporterName(
    Map<String, dynamic> data,
  ) {
    final reportName =
        data['report_name'];

    if (reportName != null &&
        reportName
            .toString()
            .trim()
            .isNotEmpty &&
        reportName.toString() != 'N/A') {
      return reportName.toString();
    }

    return 'Unknown Reporter';
  }

  // =========================================================
  // GET LOCATION
  // =========================================================

  String _getLocation(
    Map<String, dynamic> data,
  ) {
    final location =
        data['location'];

    if (location != null &&
        location
            .toString()
            .trim()
            .isNotEmpty &&
        location.toString() != 'N/A') {
      return location.toString();
    }

    final latitude =
        data['latitude'];

    final longitude =
        data['longitude'];

    if (latitude != null &&
        longitude != null) {
      return '$latitude, $longitude';
    }

    return 'Location not provided';
  }

  // =========================================================
  // SHOW COMPLAINT REVIEW
  // =========================================================

  void _showComplaintReview(
    Map<String, dynamic> data,
  ) {
    showDialog(
      context: context,

      barrierDismissible: true,

      builder:
          (BuildContext dialogContext) {
        return Dialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),

          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 750,
              maxHeight: 750,
            ),

            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(16),

              child: ComplaintReviewPage(
                documentId:
                    data['report_id']
                        .toString(),

                complaintData: {
                  ...data,

                  'report_name':
                      data['report_name'] ??
                          'Unknown Reporter',

                  'location':
                      data['location'] ??
                          'Location not provided',

                  'latitude':
                      data['latitude'] ??
                          'N/A',

                  'longitude':
                      data['longitude'] ??
                          'N/A',
                },
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // OPEN INCIDENT LOCATION
  // =========================================================

  Future<void> _openIncidentLocation(
    dynamic latitude,
    dynamic longitude,
  ) async {
    if (latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'GPS location is not available for this incident.',
          ),
        ),
      );

      return;
    }

    final double? lat =
        double.tryParse(
      latitude.toString(),
    );

    final double? lng =
        double.tryParse(
      longitude.toString(),
    );

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid GPS coordinates.',
          ),
        ),
      );

      return;
    }

    final Uri mapUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      final bool launched =
          await launchUrl(
        mapUrl,
        mode:
            LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception(
          'Could not open Google Maps',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open map: $e',
          ),
        ),
      );
    }
  }

  // =========================================================
  // FORMAT DATE
  // =========================================================

  String _formatDate(
    dynamic dateString,
  ) {
    if (dateString == null) {
      return 'N/A';
    }

    try {
      return DateFormat(
        'MMM d, yyyy',
      ).format(
        DateTime.parse(
          dateString.toString(),
        ),
      );
    } catch (e) {
      return dateString.toString();
    }
  }

  // =========================================================
  // STATUS CHIP
  // =========================================================

  Widget _buildStatusChip(
    String status,
  ) {
    Color color;

    switch (
        status.toLowerCase().trim()) {
      case 'resolved':
        color = Colors.green;
        break;

      case 'under investigation':
        color = Colors.blue;
        break;

      case 'summoned':
        color = Colors.purple;
        break;

      case 'dismissed':
        color = Colors.red;
        break;

      case 'pending':
        color = Colors.orange;
        break;

      default:
        color = Colors.orange;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(0.1),

        border: Border.all(
          color: color,
        ),

        borderRadius:
            BorderRadius.circular(8),
      ),

      child: Text(
        status,

        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // =========================================================
  // DATATABLESOURCE
  // =========================================================

  @override
  bool get isRowCountApproximate =>
      false;

  @override
  int get rowCount =>
      docs.length;

  @override
  int get selectedRowCount =>
      0;
}