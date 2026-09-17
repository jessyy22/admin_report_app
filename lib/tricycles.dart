import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'tricycle.dart';

class TricyclesListScreen extends StatefulWidget {
  const TricyclesListScreen({super.key});

  @override
  State<TricyclesListScreen> createState() => _TricyclesListScreenState();
}

class _TricyclesListScreenState extends State<TricyclesListScreen> {
  final supabase = Supabase.instance.client;

  String search = "";
  String selectedToda = "All TODA Associations";

  static const Color primaryGreen = Color(0xff005C2A);
  static const Color dashboardGreen = Color(0xff079447);
  static const Color backgroundColor = Color(0xffF5F7F6);
  static const Color textDark = Color(0xff1E293B);
  static const Color textMuted = Color(0xff64748B);
  static const Color borderColor = Color(0xffE2E8F0);

  bool get _hasFilters {
    return search.trim().isNotEmpty ||
        selectedToda != "All TODA Associations";
  }

  void _clearFilters() {
    setState(() {
      search = "";
      selectedToda = "All TODA Associations";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('tricycles')
            .stream(primaryKey: ['tricycle_id']),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load tricycles\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: dashboardGreen,
              ),
            );
          }

          final tricycles = snapshot.data!;

          // Get unique TODA associations
          final todaAssociations = tricycles
              .map(
                (t) => t['toda_association']?.toString().trim() ?? "",
              )
              .where((toda) => toda.isNotEmpty)
              .toSet()
              .toList();

          todaAssociations.sort();

          // Apply filters
          final filtered = tricycles.where((tricycle) {
            final bodyNumber =
                tricycle['body_number']?.toString().toLowerCase() ?? "";

            final toda =
                tricycle['toda_association']?.toString() ?? "";

            final matchesSearch = bodyNumber.contains(
              search.trim().toLowerCase(),
            );

            final matchesToda =
                selectedToda == "All TODA Associations" ||
                    toda == selectedToda;

            return matchesSearch && matchesToda;
          }).toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ============================================================
                // FILTER TOOLBAR
                // ============================================================
                Container(
                  padding: const EdgeInsets.all(14),

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.025),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),

                  child: Row(
                    children: [

                      // Search
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 44,

                          child: TextField(
                            onChanged: (value) {
                              setState(() {
                                search = value;
                              });
                            },

                            decoration: InputDecoration(
                              hintText: "Search body number...",
                              hintStyle: const TextStyle(
                                color: textMuted,
                                fontSize: 13,
                              ),

                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: textMuted,
                              ),

                              filled: true,
                              fillColor: const Color(0xffF8FAFC),

                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),

                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: borderColor,
                                ),
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: borderColor,
                                ),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: dashboardGreen,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // TODA Dropdown
                      Expanded(
                        flex: 2,

                        child: SizedBox(
                          height: 44,

                          child: DropdownButtonFormField<String>(
                            value: selectedToda,

                            isExpanded: true,

                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                            ),

                            style: const TextStyle(
                              color: textDark,
                              fontSize: 13,
                            ),

                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.groups_rounded,
                                size: 19,
                                color: textMuted,
                              ),

                              filled: true,
                              fillColor: const Color(0xffF8FAFC),

                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),

                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: borderColor,
                                ),
                              ),

                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: borderColor,
                                ),
                              ),

                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: dashboardGreen,
                                  width: 1.5,
                                ),
                              ),
                            ),

                            items: [
                              const DropdownMenuItem<String>(
                                value: "All TODA Associations",
                                child: Text(
                                  "All TODA Associations",
                                ),
                              ),

                              ...todaAssociations.map(
                                (toda) {
                                  return DropdownMenuItem<String>(
                                    value: toda,
                                    child: Text(
                                      toda,
                                      overflow:
                                          TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                            ],

                            onChanged: (value) {
                              if (value == null) return;

                              setState(() {
                                selectedToda = value;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Clear button
                      SizedBox(
                        height: 44,

                        child: OutlinedButton.icon(
                          onPressed:
                              _hasFilters ? _clearFilters : null,

                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 18,
                          ),

                          label: const Text(
                            "Clear Filters",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          style: OutlinedButton.styleFrom(
                            foregroundColor: textMuted,
                            side: const BorderSide(
                              color: borderColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ============================================================
                // TABLE HEADER
                // ============================================================
                Row(
                  children: [

                    const Text(
                      "Registered Tricycles",
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),

                      decoration: BoxDecoration(
                        color: const Color(0xffE8F5ED),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),

                      child: Text(
                        "${filtered.length}",
                        style: const TextStyle(
                          color: primaryGreen,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const Spacer(),

                    if (_hasFilters)
                      Text(
                        "${filtered.length} result(s)",
                        style: const TextStyle(
                          color: textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 10),

                // ============================================================
                // DATA TABLE
                // ============================================================
                Expanded(
                  child: Container(
                    width: double.infinity,

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(12),

                      border: Border.all(
                        color: borderColor,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withOpacity(0.025),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),

                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(12),

                      child: filtered.isEmpty
                          ? _buildEmptyState()
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                // Keep the same row/header dimensions as
                                // Drivers and Operators, but make the table
                                // fill the available content width.
                                final tableWidth = constraints.maxWidth < 760
                                    ? 760.0
                                    : constraints.maxWidth;

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: tableWidth,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                  // Compact sizing keeps the table proportional
                                  // to the AdminMainLayout content area.
                                  headingRowHeight: 52,

                                  dataRowMinHeight: 58,
                                  dataRowMaxHeight: 58,

                                  columnSpacing: 45,

                                  horizontalMargin: 20,

                                  dividerThickness: 0.7,

                                  headingRowColor:
                                      MaterialStateProperty
                                          .all(
                                    const Color(0xffF8FAFC),
                                  ),

                                  columns: const [
                                    DataColumn(
                                      label: Text(
                                        "ID",
                                        style: TextStyle(
                                          color: textDark,
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),

                                    DataColumn(
                                      label: Text(
                                        "BODY NUMBER",
                                        style: TextStyle(
                                          color: textDark,
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),

                                    DataColumn(
                                      label: Text(
                                        "TODA ASSOCIATION",
                                        style: TextStyle(
                                          color: textDark,
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),

                                    DataColumn(
                                      label: Text(
                                        "ACTIONS",
                                        style: TextStyle(
                                          color: textDark,
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],

                                  rows: filtered.map(
                                    (tri) {
                                      return DataRow(
                                        cells: [

                                          // ID
                                          DataCell(
                                            Text(
                                              tri['tricycle_id']
                                                  .toString(),
                                              style:
                                                  const TextStyle(
                                                color: textMuted,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),

                                          // BODY NUMBER
                                          DataCell(
                                            Text(
                                              tri['body_number']
                                                      ?.toString() ??
                                                  "",
                                              style:
                                                  const TextStyle(
                                                color: textDark,
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                            ),
                                          ),

                                          // TODA
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets
                                                      .symmetric(
                                                horizontal: 10,
                                                vertical: 5,
                                              ),

                                              decoration:
                                                  BoxDecoration(
                                                color:
                                                    const Color(
                                                  0xffF1F5F9,
                                                ),
                                                borderRadius:
                                                    BorderRadius
                                                        .circular(
                                                  6,
                                                ),
                                              ),

                                              child: Text(
                                                tri['toda_association']
                                                        ?.toString() ??
                                                    "—",

                                                style:
                                                    const TextStyle(
                                                  color:
                                                      textDark,
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // ACTIONS
                                          DataCell(
                                            Row(
                                              mainAxisSize:
                                                  MainAxisSize.min,

                                              children: [

                                                // EDIT
                                                Tooltip(
                                                  message:
                                                      "Edit tricycle",

                                                  child:
                                                      InkWell(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                      7,
                                                    ),

                                                    onTap:
                                                        () async {
                                                      final result =
                                                          await showDialog(
                                                        context:
                                                            context,
                                                        builder:
                                                            (_) =>
                                                                TricycleRegistrationScreen(
                                                          tricycleToEdit:
                                                              tri,
                                                        ),
                                                      );

                                                      if (result ==
                                                              true &&
                                                          mounted) {
                                                        setState(
                                                          () {},
                                                        );
                                                      }
                                                    },

                                                    child:
                                                        Container(
                                                      width: 34,
                                                      height: 34,

                                                      decoration:
                                                          BoxDecoration(
                                                        color:
                                                            const Color(
                                                          0xffEFF6FF,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          7,
                                                        ),
                                                      ),

                                                      child:
                                                          const Icon(
                                                        Icons
                                                            .edit_outlined,
                                                        color:
                                                            Color(
                                                          0xff2563EB,
                                                        ),
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                const SizedBox(
                                                  width: 7,
                                                ),

                                                // DELETE
                                                Tooltip(
                                                  message:
                                                      "Delete tricycle",

                                                  child:
                                                      InkWell(
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(
                                                      7,
                                                    ),

                                                    onTap:
                                                        () async {
                                                      await _deleteTricycle(
                                                        tri,
                                                      );
                                                    },

                                                    child:
                                                        Container(
                                                      width: 34,
                                                      height: 34,

                                                      decoration:
                                                          BoxDecoration(
                                                        color:
                                                            const Color(
                                                          0xffFEF2F2,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(
                                                          7,
                                                        ),
                                                      ),

                                                      child:
                                                          const Icon(
                                                        Icons
                                                            .delete_outline,
                                                        color:
                                                            Color(
                                                          0xffDC2626,
                                                        ),
                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ).toList(),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // ================================================================
      // REGISTER TRICYCLE
      // ================================================================
      floatingActionButton:
          FloatingActionButton.extended(
        icon: const Icon(
          Icons.add_rounded,
          size: 20,
        ),

        label: const Text(
          "Register Tricycle",
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),

        backgroundColor: dashboardGreen,
        foregroundColor: Colors.white,

        elevation: 3,

        onPressed: () async {
          final result = await showDialog(
            context: context,
            builder: (context) =>
                const TricycleRegistrationScreen(),
          );

          if (result == true && mounted) {
            setState(() {});
          }
        },
      ),
    );
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Container(
            width: 64,
            height: 64,

            decoration: BoxDecoration(
              color: const Color(0xffE8F5ED),
              borderRadius: BorderRadius.circular(16),
            ),

            child: const Icon(
              Icons.electric_rickshaw_outlined,
              color: primaryGreen,
              size: 32,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            "No tricycles found",
            style: TextStyle(
              color: textDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _hasFilters
                ? "Try changing or clearing your filters."
                : "Registered tricycles will appear here.",
            style: const TextStyle(
              color: textMuted,
              fontSize: 12,
            ),
          ),

          if (_hasFilters) ...[
            const SizedBox(height: 14),

            OutlinedButton(
              onPressed: _clearFilters,
              child: const Text("Clear Filters"),
            ),
          ],
        ],
      ),
    );
  }

  // ================================================================
  // DELETE
  // ================================================================
  Future<void> _deleteTricycle(
    Map<String, dynamic> tri,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,

      builder: (_) => AlertDialog(
        title: const Text(
          "Delete Tricycle",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        content: Text(
          "Are you sure you want to delete Body Number "
          "${tri['body_number']}?",
        ),

        actions: [

          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),

            onPressed: () {
              Navigator.pop(context, true);
            },

            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await supabase
          .from('tricycles')
          .delete()
          .eq(
            'tricycle_id',
            tri['tricycle_id'],
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Tricycle deleted successfully",
          ),
          backgroundColor: primaryGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Failed to delete tricycle: $e",
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}