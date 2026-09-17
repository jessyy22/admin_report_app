import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'operator.dart';

class OperatorsListScreen extends StatefulWidget {
  const OperatorsListScreen({super.key});

  @override
  State<OperatorsListScreen> createState() =>
      _OperatorsListScreenState();
}

class _OperatorsListScreenState extends State<OperatorsListScreen> {
  final supabase = Supabase.instance.client;

  // =========================================================
  // CONTROLLERS
  // =========================================================

  final TextEditingController _searchController =
      TextEditingController();
final ScrollController _horizontalController =
    ScrollController();

final ScrollController _verticalController =
    ScrollController();

  // =========================================================
  // FILTER VALUES
  // =========================================================

  String search = '';
  String driverFilter = 'all';

  // =========================================================
  // COLORS
  // =========================================================

  static const Color backgroundColor = Color(0xffF6F8F5);

  static const Color primaryGreen = Color(0xff006B2D);

  // =========================================================
  // LIFECYCLE
  // =========================================================

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      if (!mounted) return;

      setState(() {
        search = _searchController.text;
      });
    });
  }

 @override
void dispose() {
  _searchController.dispose();
  _horizontalController.dispose();
  _verticalController.dispose();
  super.dispose();
}

  // =========================================================
  // FILTER HELPERS
  // =========================================================

  bool get _hasActiveFilters {
    return search.trim().isNotEmpty ||
        driverFilter != 'all';
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      search = '';
      driverFilter = 'all';
    });
  }

  // =========================================================
  // SEARCH
  // =========================================================

  bool _matchesSearch(
    Map<String, dynamic> operator,
  ) {
    final query = search.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    final values = [
      operator['operator_id'],
      operator['name'],
      operator['contact'],
      operator['address'],
    ];

    return values.any(
      (value) =>
          value?.toString().toLowerCase().contains(query) ??
          false,
    );
  }

  // =========================================================
  // CHECK DRIVER ASSIGNMENT
  // =========================================================

  bool _operatorHasDriver(
    Map<String, dynamic> operator,
    List<Map<String, dynamic>> drivers,
  ) {
    final operatorId = operator['operator_id'];

    if (operatorId == null) {
      return false;
    }

    return drivers.any(
      (driver) =>
          driver['operator_id']?.toString() ==
          operatorId.toString(),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('operators')
            .stream(
              primaryKey: ['operator_id'],
            ),

        builder: (context, operatorSnapshot) {
          // ===================================================
          // OPERATOR ERROR
          // ===================================================

          if (operatorSnapshot.hasError) {
            return _buildErrorState(
              'Error loading operators:\n'
              '${operatorSnapshot.error}',
            );
          }

          // ===================================================
          // OPERATOR LOADING
          // ===================================================

          if (!operatorSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final operators = operatorSnapshot.data!;

          // ===================================================
          // DRIVER STREAM
          // ===================================================

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('drivers')
                .stream(
                  primaryKey: ['driver_id'],
                ),

            builder: (context, driverSnapshot) {
              // =================================================
              // DRIVER ERROR
              // =================================================

              if (driverSnapshot.hasError) {
                return _buildErrorState(
                  'Error loading driver assignments:\n'
                  '${driverSnapshot.error}',
                );
              }

              // =================================================
              // DRIVER LOADING
              // =================================================

              if (!driverSnapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final drivers = driverSnapshot.data!;

              // =================================================
              // FILTER OPERATORS
              // =================================================

              final filtered = operators.where((operator) {
                // SEARCH
                if (!_matchesSearch(operator)) {
                  return false;
                }

                // DRIVER STATUS
                final hasDriver = _operatorHasDriver(
                  operator,
                  drivers,
                );

                if (driverFilter == 'with_drivers' &&
                    !hasDriver) {
                  return false;
                }

                if (driverFilter == 'no_drivers' &&
                    hasDriver) {
                  return false;
                }

                return true;
              }).toList();

              // =================================================
              // MAIN CONTENT
              // =================================================

              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  22,
                  22,
                  22,
                  20,
                ),

                child: Column(
                  children: [
                    // =================================================
                    // SEARCH / FILTER ROW
                    // =================================================

                    _buildSearchAndFilters(),

                    const SizedBox(height: 14),

                    // =================================================
                    // TABLE
                    // =================================================

                    Expanded(
                      child: _buildTableContainer(
                        filtered,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),

      // =========================================================
      // REGISTER OPERATOR BUTTON
      // =========================================================

      floatingActionButton:
          FloatingActionButton.extended(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,

        elevation: 5,

        icon: const Icon(
          Icons.person_add,
          size: 19,
        ),

        label: const Text(
          'Register Operator',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),

        onPressed: _showRegistrationDialog,
      ),

      floatingActionButtonLocation:
          FloatingActionButtonLocation.endFloat,
    );
  }

  // =========================================================
  // ERROR STATE
  // =========================================================

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 50,
              color: Colors.red.shade300,
            ),

            const SizedBox(height: 12),

            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SEARCH + FILTERS
  // =========================================================

  Widget _buildSearchAndFilters() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // =====================================================
        // MOBILE
        // =====================================================

        if (width < 600) {
          return Column(
            children: [
              _buildSearchField(),

              const SizedBox(height: 7),

              Row(
                children: [
                  Expanded(
                    child: _buildDriverFilter(),
                  ),

                  const SizedBox(width: 7),

                  _buildFilterButton(),
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
              child: _buildSearchField(),
            ),

            const SizedBox(width: 7),

            SizedBox(
              width: 170,
              child: _buildDriverFilter(),
            ),

            const SizedBox(width: 7),

            _buildFilterButton(),
          ],
        );
      },
    );
  }

  // =========================================================
  // SEARCH FIELD
  // =========================================================

  Widget _buildSearchField() {
    return SizedBox(
      height: 44,

      child: TextField(
        controller: _searchController,

        style: const TextStyle(
          fontSize: 12,
        ),

        decoration: InputDecoration(
          hintText:
              'Search ID, name, contact, address...',

          hintStyle: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),

          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: Colors.grey.shade600,
          ),

          suffixIcon:
              search.trim().isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',

                      icon: Icon(
                        Icons.clear,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),

                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,

          filled: true,
          fillColor: Colors.white,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),

            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),

            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),

            borderSide: BorderSide(
              color: primaryGreen,
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // DRIVER FILTER
  // =========================================================

  Widget _buildDriverFilter() {
    return SizedBox(
      height: 44,

      child: DropdownButtonFormField<String>(
        initialValue: driverFilter,

        isExpanded: true,

        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 17,
        ),

        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
        ),

        decoration: InputDecoration(
          labelText: 'Driver Status',

          labelStyle: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),

          filled: true,
          fillColor: Colors.white,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 0,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),

            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),

            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(8),

            borderSide: BorderSide(
              color: primaryGreen,
              width: 1.2,
            ),
          ),
        ),

        items: const [
          DropdownMenuItem(
            value: 'all',
            child: Text(
              'All Operators',
              style: TextStyle(
                fontSize: 11,
              ),
            ),
          ),

          DropdownMenuItem(
            value: 'with_drivers',
            child: Text(
              'With Drivers',
              style: TextStyle(
                fontSize: 11,
              ),
            ),
          ),

          DropdownMenuItem(
            value: 'no_drivers',
            child: Text(
              'No Drivers',
              style: TextStyle(
                fontSize: 11,
              ),
            ),
          ),
        ],

        onChanged: (value) {
          if (value == null) return;

          setState(() {
            driverFilter = value;
          });
        },
      ),
    );
  }

  // =========================================================
  // FILTER BUTTON
  // =========================================================

  Widget _buildFilterButton() {
    return SizedBox(
      height: 44,
      width: 44,

      child: OutlinedButton(
        onPressed:
            _hasActiveFilters
                ? _clearFilters
                : null,

        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,

          minimumSize:
              const Size(44, 44),

          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(8),
          ),

          side: BorderSide(
            color: Colors.grey.shade300,
          ),

          backgroundColor: Colors.white,

          disabledBackgroundColor:
              Colors.white,
        ),

        child: Icon(
          _hasActiveFilters
              ? Icons.clear_all
              : Icons.filter_list,

          size: 18,

          color: _hasActiveFilters
              ? Colors.grey.shade700
              : Colors.grey.shade500,
        ),
      ),
    );
  }

  // =========================================================
  // TABLE CONTAINER
  // =========================================================

  Widget _buildTableContainer(
    List<Map<String, dynamic>> filtered,
  ) {
    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(.05),

            blurRadius: 8,

            offset:
                const Offset(0, 3),
          ),
        ],
      ),

      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(18),

        child: filtered.isEmpty
            ? _buildEmptyState()
            : _buildDataTable(filtered),
      ),
    );
  }
// =========================================================
// DATA TABLE
// =========================================================

// =====================================================
// OPERATOR RECORDS
// =====================================================

Widget _buildDataTable(
  List<Map<String, dynamic>> filtered,
) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,

        child: SizedBox(
          width: constraints.maxWidth < 900
              ? 900
              : constraints.maxWidth,

          child: Column(
            children: [
              // =================================================
              // TABLE HEADER
              // =================================================

              Container(
                height: 58,

                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                ),

                child: Row(
                  children: [
                    // ID
                    SizedBox(
                      width: 80,

                      child: const Text(
                        'ID',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // NAME
                    SizedBox(
                      width: 200,

                      child: const Text(
                        'Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // CONTACT
                    SizedBox(
                      width: 180,

                      child: const Text(
                        'Contact',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // ADDRESS
                    Expanded(
                      child: const Text(
                        'Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // ACTIONS
                    SizedBox(
                      width: 120,

                      child: const Text(
                        'Actions',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // =================================================
              // HEADER DIVIDER
              // =================================================

              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade300,
              ),

              // =================================================
              // ROWS
              // =================================================

              Expanded(
                child: ListView.builder(
                  controller: _verticalController,

                  itemCount: filtered.length,

                  itemBuilder: (context, index) {
                    final op = filtered[index];

                    return Container(
                      height: 62,

                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 26,
                      ),

                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),

                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.center,

                        children: [
                          // =====================================
                          // ID
                          // =====================================

                          SizedBox(
                            width: 80,

                            child: Text(
                              op['operator_id']
                                      ?.toString() ??
                                  '',

                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                          ),

                          // =====================================
                          // NAME
                          // =====================================

                          SizedBox(
                            width: 200,

                            child: Text(
                              op['name']
                                      ?.toString() ??
                                  '',

                              maxLines: 1,

                              overflow:
                                  TextOverflow.ellipsis,

                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),

                          // =====================================
                          // CONTACT
                          // =====================================

                          SizedBox(
                            width: 180,

                            child: Text(
                              op['contact']
                                      ?.toString() ??
                                  '',

                              maxLines: 1,

                              overflow:
                                  TextOverflow.ellipsis,

                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ),

                          // =====================================
                          // ADDRESS
                          // =====================================

                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(
                                right: 20,
                              ),

                              child: Text(
                                op['address']
                                        ?.toString() ??
                                    '',

                                maxLines: 1,

                                overflow:
                                    TextOverflow.ellipsis,

                                style: const TextStyle(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),

                          // =====================================
                          // ACTIONS
                          // =====================================

                          SizedBox(
                            width: 120,

                            child:
                                _buildActionButtons(
                              op,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
  // =========================================================
  // ACTION BUTTONS
  // =========================================================

  Widget _buildActionButtons(
    Map<String, dynamic> op,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,

      children: [
        // =======================================================
        // EDIT
        // =======================================================

        Container(
          width: 39,
          height: 39,

          decoration: BoxDecoration(
            color:
                Colors.blue.shade50,

            borderRadius:
                BorderRadius.circular(9),
          ),

          child: IconButton(
            tooltip:
                'Edit operator',

            padding:
                EdgeInsets.zero,

            icon: const Icon(
              Icons.edit_outlined,

              color: Colors.blue,

              size: 20,
            ),

            onPressed: () =>
                _editOperator(op),
          ),
        ),

        const SizedBox(width: 7),

        // =======================================================
        // DELETE
        // =======================================================

        Container(
          width: 39,
          height: 39,

          decoration: BoxDecoration(
            color:
                Colors.red.shade50,

            borderRadius:
                BorderRadius.circular(9),
          ),

          child: IconButton(
            tooltip:
                'Delete operator',

            padding:
                EdgeInsets.zero,

            icon: const Icon(
              Icons.delete_outline,

              color: Colors.red,

              size: 20,
            ),

            onPressed: () =>
                _deleteOperator(op),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Icon(
              _hasActiveFilters
                  ? Icons.filter_alt_off
                  : Icons.people_outline,

              size: 55,

              color:
                  Colors.grey.shade400,
            ),

            const SizedBox(height: 12),

            Text(
              _hasActiveFilters
                  ? 'No operators match your filters'
                  : 'No operators registered',

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                fontSize: 16,

                color:
                    Colors.grey.shade600,

                fontWeight:
                    FontWeight.w500,
              ),
            ),

            if (_hasActiveFilters) ...[
              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed:
                    _clearFilters,

                icon: const Icon(
                  Icons.clear_all,
                  size: 17,
                ),

                label: const Text(
                  'Clear Filters',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // EDIT OPERATOR
  // =========================================================

  Future<void> _editOperator(
    Map<String, dynamic> op,
  ) async {
    final result =
        await showDialog<bool>(
      context: context,

      builder: (_) =>
          OperatorRegistrationScreen(
        operatorToEdit: op,
      ),
    );

    if (result == true &&
        mounted) {
      setState(() {});
    }
  }

  // =========================================================
  // DELETE OPERATOR
  // =========================================================

  Future<void> _deleteOperator(
    Map<String, dynamic> op,
  ) async {
    final name =
        op['name']?.toString() ??
            'this operator';

    final confirm =
        await showDialog<bool>(
      context: context,

      builder: (_) =>
          AlertDialog(
        title: const Text(
          'Delete Operator',
        ),

        content: Text(
          'Are you sure you want to delete $name?',
        ),

        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),

            child: const Text(
              'Cancel',
            ),
          ),

          ElevatedButton(
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  Colors.red,

              foregroundColor:
                  Colors.white,
            ),

            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),

            child: const Text(
              'Delete',
            ),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await supabase
          .from('operators')
          .delete()
          .eq(
            'operator_id',
            op['operator_id'],
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Operator deleted successfully',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete operator: $e',
          ),

          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // =========================================================
  // REGISTER OPERATOR
  // =========================================================

  Future<void>
      _showRegistrationDialog() async {
    final result =
        await showDialog<bool>(
      context: context,

      builder: (context) =>
          const OperatorRegistrationScreen(),
    );

    if (result == true &&
        mounted) {
      setState(() {});
    }
  }
}