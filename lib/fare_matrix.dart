import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminFareMatrixScreen extends StatefulWidget {
  const AdminFareMatrixScreen({super.key});

  @override
  State<AdminFareMatrixScreen> createState() => _AdminFareMatrixScreenState();
}

class _AdminFareMatrixScreenState extends State<AdminFareMatrixScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _zones = [];
  Map<String, List<Map<String, dynamic>>> _placesByZone = {};

  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFareMatrix();
  }

  Future<void> _loadFareMatrix() async {
    setState(() => _isLoading = true);

    try {
      final fareData = await _supabase
          .from('fare_matrix')
          .select()
          .order('zone_category');

      final villageData = await _supabase
          .from('villages')
          .select('id, village_name, zone_category')
          .order('village_name');

      final Map<String, List<Map<String, dynamic>>> places = {};

      for (final village in villageData) {
        final zone = village['zone_category']?.toString() ?? '';
        places.putIfAbsent(zone, () => []);
        places[zone]!.add(village);
      }

      if (!mounted) return;

      setState(() {
        _zones = List<Map<String, dynamic>>.from(fareData);
        _placesByZone = places;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fare matrix error: $e');

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load fare matrix: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredZones {
    if (_searchQuery.trim().isEmpty) return _zones;

    final query = _searchQuery.toLowerCase();

    return _zones.where((zone) {
      final zoneName = zone['zone_category']?.toString().toLowerCase() ?? '';
      final fareCategory =
          zone['fare_category']?.toString().toLowerCase() ?? '';
      final places = _placesByZone[zone['zone_category']] ?? [];

      final hasMatchingPlace = places.any(
        (place) =>
            place['village_name']?.toString().toLowerCase().contains(query) ??
            false,
      );

      return zoneName.contains(query) ||
          fareCategory.contains(query) ||
          hasMatchingPlace;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.green.shade700;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F9),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPageHeader(primaryColor),
                Expanded(
                  child: _filteredZones.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadFareMatrix,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            child: _buildFareMatrixTable(primaryColor),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        onPressed: _showAddZoneDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Zone'),
      ),
    );
  }

  Widget _buildPageHeader(Color primaryColor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        
          const SizedBox(height: 14),
          TextField(
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
            decoration: InputDecoration(
              hintText: 'Search zone or place...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.clear),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFF3F5F7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareMatrixTable(Color primaryColor) {
    final zones = _filteredZones;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // IMPORTANT:
          // The table is locked to the available page width.
          // There is NO horizontal SingleChildScrollView.
          // Only the rows scroll vertically.
          final width = constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(
              width: width,
              child: DataTable(
                headingRowHeight: 72,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 58,
                columnSpacing: 6,
                horizontalMargin: 8,
                dividerThickness: 0.6,
                headingRowColor: MaterialStateProperty.all(
                  const Color(0xffF8FAFC),
                ),
                columns: [
                  _fareHeader('ID', 42),
                  _fareHeader('ZONE', 100),
                  _fareHeader('FARE\nCATEGORY', 105),
                  _fareHeader('SINGLE\nDAY', 78),
                  _fareHeader('SINGLE\nNIGHT', 78),
                  _fareHeader('SINGLE\nDISCOUNT\nDAY', 86),
                  _fareHeader('SINGLE\nDISCOUNT\nNIGHT', 86),
                  _fareHeader('SHARED\nDAY', 78),
                  _fareHeader('SHARED\nNIGHT', 78),
                  _fareHeader('SHARED\nDISCOUNT\nDAY', 86),
                  _fareHeader('SHARED\nDISCOUNT\nNIGHT', 86),
                  _fareHeader('PLACES', 58),
                  _fareHeader('ACTIONS', 105),
                ],
                rows: zones.map((zone) {
                  final zoneName =
                      zone['zone_category']?.toString() ?? 'Unnamed Zone';
                  final fareCategory =
                      zone['fare_category']?.toString() ?? 'No category';
                  final places = _placesByZone[zoneName] ?? [];

                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 42,
                          child: Text(
                            zone['id']?.toString() ?? '-',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff64748B),
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 100,
                          child: Text(
                            zoneName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff1E293B),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 105,
                          child: Text(
                            fareCategory,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xff64748B),
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      DataCell(_compactFareCell(zone['single_day_fare'], 78)),
                      DataCell(_compactFareCell(zone['single_night_fare'], 78)),
                      DataCell(
                        _compactFareCell(
                          zone['single_discounted_fare_day'],
                          86,
                        ),
                      ),
                      DataCell(
                        _compactFareCell(
                          zone['single_discounted_fare_night'],
                          86,
                        ),
                      ),
                      DataCell(_compactFareCell(zone['shared_day_fare'], 78)),
                      DataCell(
                        _compactFareCell(zone['shared_night_fare'], 78),
                      ),
                      DataCell(
                        _compactFareCell(
                          zone['shared_discounted_fare_day'],
                          86,
                        ),
                      ),
                      DataCell(
                        _compactFareCell(
                          zone['shared_discounted_fare_night'],
                          86,
                        ),
                      ),
                      DataCell(
                        Container(
                          width: 42,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffE8F5ED),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${places.length}',
                            style: const TextStyle(
                              color: Color(0xff005C2A),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 105,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _tableActionButton(
                                icon: Icons.place_outlined,
                                color: primaryColor,
                                background: const Color(0xffF0FDF4),
                                tooltip: 'Manage places',
                                onTap: () => _openManagePlaces(zone),
                              ),
                              const SizedBox(width: 5),
                              _tableActionButton(
                                icon: Icons.edit_outlined,
                                color: const Color(0xff2563EB),
                                background: const Color(0xffEFF6FF),
                                tooltip: 'Edit fare',
                                onTap: () => _showEditFareDialog(zone),
                              ),
                              const SizedBox(width: 5),
                              _tableActionButton(
                                icon: Icons.delete_outline,
                                color: const Color(0xffDC2626),
                                background: const Color(0xffFEF2F2),
                                tooltip: 'Delete zone',
                                onTap: () => _confirmDeleteZone(zone),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  DataColumn _fareHeader(String title, double width) {
    return DataColumn(
      label: SizedBox(
        width: width,
        height: 58,
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.05,
              fontWeight: FontWeight.w700,
              color: Color(0xff1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compactFareCell(dynamic value, double width) {
    final display = _formatFare(value);

    return SizedBox(
      width: width,
      child: Text(
        display == '-' ? '-' : '₱$display',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Color(0xff1E293B),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _tableActionButton({
    required IconData icon,
    required Color color,
    required Color background,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: color,
            size: 15,
          ),
        ),
      ),
    );
  }

  Widget _fareCell(dynamic value) {
    final display = _formatFare(value);

    return SizedBox(
      width: 115,
      child: Text(
        display == '-' ? '-' : '₱$display',
        style: const TextStyle(
          color: Color(0xff1E293B),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _fareTableValue(dynamic day, dynamic night) {
    return SizedBox(
      width: 125,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '₱${_formatFare(day)}',
            style: const TextStyle(
              color: Color(0xff1E293B),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Night  ₱${_formatFare(night)}',
            style: const TextStyle(
              color: Color(0xff64748B),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> zone, Color primaryColor) {
    final zoneName = zone['zone_category']?.toString() ?? 'Unnamed Zone';
    final fareCategory = zone['fare_category']?.toString() ?? 'No category';
    final places = _placesByZone[zoneName] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: zone info + menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.location_on_outlined, color: primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zoneName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fareCategory,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditFareDialog(zone);
                    } else if (value == 'places') {
                      _openManagePlaces(zone);
                    } else if (value == 'delete') {
                      _confirmDeleteZone(zone);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit Fare'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'places',
                      child: ListTile(
                        leading: Icon(Icons.place_outlined),
                        title: Text('Manage Places'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Delete Zone'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Places preview
            _buildPlacesPreview(places, primaryColor),

            const SizedBox(height: 14),

            // Fare summary
            _buildFareSummary(zone, primaryColor),

            const SizedBox(height: 14),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openManagePlaces(zone),
                    icon: const Icon(Icons.place_outlined),
                    label: Text('Places (${places.length})'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEditFareDialog(zone),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Fare'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesPreview(
    List<Map<String, dynamic>> places,
    Color primaryColor,
  ) {
    if (places.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No places assigned to this zone.',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final visiblePlaces = places.take(3).toList();
    final remaining = places.length - visiblePlaces.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.place_outlined, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...visiblePlaces.map(
                  (place) =>
                      _placeChip(place['village_name']?.toString() ?? ''),
                ),
                if (remaining > 0) _placeChip('+$remaining more'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFareSummary(Map<String, dynamic> zone, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _fareMiniCard(
                'Single',
                zone['single_day_fare'],
                zone['single_night_fare'],
                Icons.person_outline,
                primaryColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _fareMiniCard(
                'Shared',
                zone['shared_day_fare'],
                zone['shared_night_fare'],
                Icons.groups_outlined,
                primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Regular fare • Day / Night',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _fareMiniCard(
    String title,
    dynamic day,
    dynamic night,
    IconData icon,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₱${_formatFare(day)} / ₱${_formatFare(night)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFare(dynamic value) {
    if (value == null) return '0.00';
    final number = double.tryParse(value.toString()) ?? 0;
    return number.toStringAsFixed(2);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'No zones found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Try another zone or place name.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ======================== EDIT FARE ========================

  void _showEditFareDialog(Map<String, dynamic> zone) {
    final fields = <String, TextEditingController>{};

    final fieldNames = {
      'single_day_fare': 'Single • Day',
      'single_night_fare': 'Single • Night',
      'single_discounted_fare_day': 'Single Discounted • Day',
      'single_discounted_fare_night': 'Single Discounted • Night',
      'shared_day_fare': 'Shared • Day',
      'shared_night_fare': 'Shared • Night',
      'shared_discounted_fare_day': 'Shared Discounted • Day',
      'shared_discounted_fare_night': 'Shared Discounted • Night',
    };

    for (final key in fieldNames.keys) {
      fields[key] = TextEditingController(text: _formatFare(zone[key]));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Edit ${zone['zone_category']}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
                      children: [
                        _buildSectionTitle('Regular Fare'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _fareField(
                                'Single Day',
                                fields['single_day_fare']!,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _fareField(
                                'Single Night',
                                fields['single_night_fare']!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _fareField(
                                'Shared Day',
                                fields['shared_day_fare']!,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _fareField(
                                'Shared Night',
                                fields['shared_night_fare']!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        _buildSectionTitle('Discounted Fare'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _fareField(
                                'Single Day',
                                fields['single_discounted_fare_day']!,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _fareField(
                                'Single Night',
                                fields['single_discounted_fare_night']!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _fareField(
                                'Shared Day',
                                fields['shared_discounted_fare_day']!,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _fareField(
                                'Shared Night',
                                fields['shared_discounted_fare_night']!,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await _updateFare(zone, fields);
                              if (context.mounted) Navigator.pop(context);
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text(
                              'Save Changes',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    );
  }

  Widget _fareField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: '₱ ',
        filled: true,
        fillColor: const Color(0xFFF6F8FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Future<void> _updateFare(
    Map<String, dynamic> zone,
    Map<String, TextEditingController> fields,
  ) async {
    try {
      final Map<String, dynamic> updateData = {};

      for (final entry in fields.entries) {
        updateData[entry.key] = double.tryParse(entry.value.text.trim()) ?? 0;
      }

      await _supabase
          .from('fare_matrix')
          .update(updateData)
          .eq('id', zone['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fare updated successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadFareMatrix();
    } catch (e) {
      debugPrint('Update fare error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update fare: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ======================== MANAGE PLACES (POPUP) ========================

  void _openManagePlaces(Map<String, dynamic> zone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PlacesForZoneSheet(
        zone: zone,
        supabase: _supabase,
        onPlacesChanged: _loadFareMatrix,
      ),
    );
  }

  // ======================== ADD ZONE ========================

  void _showAddZoneDialog() {
    final zoneController = TextEditingController();
    final categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Fare Zone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: zoneController,
                decoration: const InputDecoration(
                  labelText: 'Zone Name',
                  hintText: 'e.g. AYUSAN CLUSTER',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Fare Category',
                  hintText: 'e.g. AYUSAN_CLUSTER',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final zoneName = zoneController.text.trim();
                final category = categoryController.text.trim();

                if (zoneName.isEmpty || category.isEmpty) return;

                try {
                  await _supabase.from('fare_matrix').insert({
                    'zone_category': zoneName,
                    'fare_category': category,
                    'single_day_fare': 0,
                    'single_night_fare': 0,
                    'single_discounted_fare_day': 0,
                    'single_discounted_fare_night': 0,
                    'shared_day_fare': 0,
                    'shared_night_fare': 0,
                    'shared_discounted_fare_day': 0,
                    'shared_discounted_fare_night': 0,
                  });

                  if (!context.mounted) return;

                  Navigator.pop(context);
                  await _loadFareMatrix();
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to add zone: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // ======================== DELETE ZONE ========================

  void _confirmDeleteZone(Map<String, dynamic> zone) {
    final zoneName = zone['zone_category']?.toString() ?? 'this zone';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Zone?'),
          content: Text('Are you sure you want to delete "$zoneName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                   await _supabase
                      .from('fare_matrix')
                      .delete()
                      .eq('id', zone['id']);

                  if (!context.mounted) return;

                  Navigator.pop(context);
                  await _loadFareMatrix();
                } catch (e) {
                  if (!context.mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not delete zone: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

// ======================== PLACES FOR ZONE POPUP (TABLE STYLE) ========================

class _PlacesForZoneSheet extends StatefulWidget {
  final Map<String, dynamic> zone;
  final SupabaseClient supabase;
  final VoidCallback onPlacesChanged;

  const _PlacesForZoneSheet({
    required this.zone,
    required this.supabase,
    required this.onPlacesChanged,
  });

  @override
  State<_PlacesForZoneSheet> createState() => _PlacesForZoneSheetState();
}

class _PlacesForZoneSheetState extends State<_PlacesForZoneSheet> {
  bool _loading = true;
  String _search = '';
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _allPlaces = [];

  String get zoneName => widget.zone['zone_category']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => _loading = true);

    try {
      final places = await widget.supabase
          .from('villages')
          .select('id, village_name, zone_category')
          .eq('zone_category', zoneName)
          .order('village_name');

      final allPlaces = await widget.supabase
          .from('villages')
          .select('id, village_name, zone_category')
          .order('village_name');

      if (!mounted) return;

      setState(() {
        _places = List<Map<String, dynamic>>.from(places);
        _allPlaces = List<Map<String, dynamic>>.from(allPlaces);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load places: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    if (_search.trim().isEmpty) return _places;

    final q = _search.toLowerCase();
    return _places
        .where(
          (p) =>
              (p['village_name']?.toString() ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Colors.green.shade700;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zoneName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_places.length} places',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search places...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        onPressed: () => setState(() => _search = ''),
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF3F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPlaces.isEmpty
                ? _buildEmpty(primaryColor)
                : _buildPlacesTable(primaryColor),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _showAddPlace(),
                icon: const Icon(Icons.add),
                label: const Text('Add Place'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 55,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            const Text(
              'No places yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Add places to this zone.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlacesTable(Color primaryColor) {
    final places = _filteredPlaces;

    return Column(
      children: [
        // Table header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 40), // space for icon column
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Place / Barangay',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Zone Category',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 40), // space for actions
            ],
          ),
        ),
        const Divider(height: 1),
        // Table rows
        Expanded(
          child: ListView.separated(
            itemCount: places.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final place = places[index];
              return _buildPlaceRow(place, primaryColor);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceRow(Map<String, dynamic> place, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Icon column
          SizedBox(
            width: 40,
            child: Icon(
              Icons.location_on_outlined,
              color: primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Place name
          Expanded(
            flex: 1,
            child: Text(
              place['village_name']?.toString() ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Zone category
          Expanded(
            flex: 1,
            child: Text(
              place['zone_category']?.toString() ?? 'Unassigned',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'remove') _removePlace(place);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'remove',
                child: Text(
                  'Remove from zone',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert, size: 20),
          ),
        ],
      ),
    );
  }

  void _showAddPlace() {
    final available = _allPlaces
        .where((p) => p['zone_category'] != zoneName)
        .toList();

    String? selectedId;

    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.6,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Add Place to Zone',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (_, i) {
                        final p = available[i];
                        final id = p['id'].toString();
                        return RadioListTile<String>(
                          value: id,
                          groupValue: selectedId,
                          onChanged: (v) {
                            setS(() => selectedId = v);
                          },
                          title: Text(
                            p['village_name']?.toString() ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                          subtitle: Text(
                            p['zone_category']?.toString() ?? 'Unassigned',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: selectedId == null
                            ? null
                            : () async {
                                await _assignPlace(selectedId!);
                                if (ctx.mounted) Navigator.pop(ctx);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Add Place'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _assignPlace(String id) async {
    try {
      await widget.supabase
          .from('villages')
          .update({'zone_category': zoneName})
          .eq('id', id);

      await _loadPlaces();
      widget.onPlacesChanged();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place added to zone.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add place: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removePlace(Map<String, dynamic> place) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Place?'),
        content: Text('Remove "${place['village_name']}" from $zoneName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.supabase
          .from('villages')
          .update({'zone_category': null})
          .eq('id', place['id']);

      await _loadPlaces();
      widget.onPlacesChanged();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Place removed from zone.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to remove place: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
