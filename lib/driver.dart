import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? driverToEdit;

  const DriverRegistrationScreen({
    super.key,
    this.driverToEdit,
  });

  @override
  State<DriverRegistrationScreen> createState() =>
      _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState
    extends State<DriverRegistrationScreen> {
  // =====================================================
  // FORM
  // =====================================================

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _licenseController = TextEditingController();
  final _operatorController = TextEditingController();
  final _bodyNumberController = TextEditingController();
  final TextEditingController _permitNumberController =
    TextEditingController();

final TextEditingController _permitAddressController =
    TextEditingController();

final TextEditingController _permitLicenseNumberController =
    TextEditingController();

final TextEditingController _permitIssuedDateController =
    TextEditingController();

final TextEditingController _permitValidUntilController =
    TextEditingController();

final TextEditingController _permitControlNoController =
    TextEditingController();

final TextEditingController _permitOrNoController =
    TextEditingController();

final TextEditingController _permitAmountController =
    TextEditingController();

final TextEditingController _permitPaymentDateController =
    TextEditingController();

  // =====================================================
  // DATA
  // =====================================================

  List<Map<String, dynamic>> _operators = [];
  List<Map<String, dynamic>> _allTricycles = [];
  List<Map<String, dynamic>> _filteredTricycles = [];

  String? _selectedOperatorId;
  String? _selectedTricycleId;

  // IMPORTANT:
  // Must be lowercase because the dropdown values are lowercase.
 String? _selectedStatus = 'Active';

  bool _isLoading = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.driverToEdit != null;

  // =====================================================
  // LIFECYCLE
  // =====================================================

  @override
  void initState() {
    super.initState();
    _fetchFormDataAndInitialize();
  }

 @override
void dispose() {
  _nameController.dispose();
  _contactController.dispose();
  _licenseController.dispose();
  _operatorController.dispose();
  _bodyNumberController.dispose();

  // Driver's Permit
  _permitNumberController.dispose();
  _permitAddressController.dispose();
  _permitLicenseNumberController.dispose();
  _permitIssuedDateController.dispose();
  _permitValidUntilController.dispose();
  _permitControlNoController.dispose();
  _permitOrNoController.dispose();
  _permitAmountController.dispose();
  _permitPaymentDateController.dispose();

  super.dispose();
}

  // =====================================================
  // LOAD OPERATORS AND TRICYCLES
  // =====================================================

  Future<void> _fetchFormDataAndInitialize() async {
    final supabase = Supabase.instance.client;

    try {
      final opRes = await supabase
          .from('operators')
          .select('operator_id, name')
          .order('name');

      final triRes = await supabase
          .from('tricycles')
          .select('tricycle_id, body_number, operator_id')
          .order('body_number');

      if (!mounted) return;

      final operators =
          List<Map<String, dynamic>>.from(opRes);

      final tricycles =
          List<Map<String, dynamic>>.from(triRes);

      setState(() {
        _operators = operators;
        _allTricycles = tricycles;

        // =================================================
        // EDIT MODE
        // =================================================

        if (_isEditing) {
          final driver = widget.driverToEdit!;

          _nameController.text =
              driver['name']?.toString() ?? '';

          _contactController.text =
              driver['contact']?.toString() ?? '';

          _licenseController.text =
              driver['license_number']?.toString() ?? '';
 // -------------------------------------------------
// Driver's Permit
// -------------------------------------------------

_permitNumberController.text =
    driver['permit_number']?.toString() ?? '';

_permitAddressController.text =
    driver['permit_address']?.toString() ?? '';

_permitLicenseNumberController.text =
    driver['permit_license_number']?.toString() ?? '';

_permitIssuedDateController.text =
    driver['permit_issued_date']?.toString() ?? '';

_permitValidUntilController.text =
    driver['permit_valid_until']?.toString() ?? '';

_permitControlNoController.text =
    driver['permit_control_no']?.toString() ?? '';

_permitOrNoController.text =
    driver['permit_or_no']?.toString() ?? '';

_permitAmountController.text =
    driver['permit_amount']?.toString() ?? '';

_permitPaymentDateController.text =
    driver['permit_payment_date']?.toString() ?? '';

          // -------------------------------------------------
          // Operator
          // -------------------------------------------------

          final operatorData = driver['operators'];

          if (operatorData is Map) {
            _operatorController.text =
                operatorData['name']?.toString() ?? '';
          } else if (operatorData is List &&
              operatorData.isNotEmpty) {
            _operatorController.text =
                operatorData.first['name']?.toString() ?? '';
          }

          _selectedOperatorId =
              driver['operator_id']?.toString();

          // -------------------------------------------------
          // Status
          // -------------------------------------------------

     final status = driver['status']?.toString().trim().toLowerCase();

if (status == 'active') {
  _selectedStatus = 'Active';
} else if (status == 'inactive') {
  _selectedStatus = 'Inactive';
} else if (status == 'suspended') {
  _selectedStatus = 'Suspended';
} else {
  _selectedStatus = 'Active';
}
          // -------------------------------------------------
          // Tricycle
          // -------------------------------------------------

          _selectedTricycleId =
              driver['tricycle_id']?.toString();

          // Filter tricycles by selected operator
          if (_selectedOperatorId != null) {
            _filteredTricycles = _allTricycles
                .where(
                  (tricycle) =>
                      tricycle['operator_id']?.toString() ==
                      _selectedOperatorId,
                )
                .toList();

            // Remove duplicate tricycle IDs
            _filteredTricycles =
                _removeDuplicateTricycles(
              _filteredTricycles,
            );
          }

          // Get body number for editing
          final tricycleData = driver['tricycles'];

          if (tricycleData is Map) {
            _bodyNumberController.text =
                tricycleData['body_number']?.toString() ?? '';
          } else if (tricycleData is List &&
              tricycleData.isNotEmpty) {
            _bodyNumberController.text =
                tricycleData.first['body_number']?.toString() ?? '';
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load data: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );

      Navigator.pop(context);
    }
  }

  // =====================================================
  // REMOVE DUPLICATE TRICYCLE IDs
  // =====================================================

  List<Map<String, dynamic>> _removeDuplicateTricycles(
    List<Map<String, dynamic>> tricycles,
  ) {
    final Map<String, Map<String, dynamic>> unique = {};

    for (final tricycle in tricycles) {
      final id =
          tricycle['tricycle_id']?.toString();

      if (id != null && id.isNotEmpty) {
        unique[id] = tricycle;
      }
    }

    return unique.values.toList();
  }

  // =====================================================
  // GET UNIQUE TRICYCLES
  // =====================================================

  List<Map<String, dynamic>> _getUniqueTricycles() {
    return _removeDuplicateTricycles(
      _filteredTricycles,
    );
  }

  // =====================================================
  // GET VALID SELECTED TRICYCLE ID
  // =====================================================

  String? _getValidSelectedTricycleId() {
    if (_selectedTricycleId == null) {
      return null;
    }

    final uniqueTricycles =
        _getUniqueTricycles();

    final matches = uniqueTricycles.where(
      (tricycle) =>
          tricycle['tricycle_id']?.toString() ==
          _selectedTricycleId,
    );

    if (matches.length == 1) {
      return _selectedTricycleId;
    }

    return null;
  }

  // =====================================================
  // BUILD TRICYCLE DROPDOWN ITEMS
  // =====================================================

  List<DropdownMenuItem<String>>
      _buildTricycleDropdownItems() {
    final uniqueTricycles =
        _getUniqueTricycles();

    return uniqueTricycles.map(
      (tricycle) {
        final id =
            tricycle['tricycle_id']?.toString() ?? '';

        final bodyNumber =
            tricycle['body_number']?.toString() ?? 'N/A';

        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            bodyNumber,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    ).toList();
  }

  // =====================================================
  // SUBMIT
  // =====================================================

 Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  if (_selectedOperatorId == null ||
      _selectedOperatorId!.isEmpty) {
    return;
  }

  if (_selectedTricycleId == null ||
      _selectedTricycleId!.isEmpty) {
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    final supabase = Supabase.instance.client;

    // Make sure the status is one of the allowed values
    String driverStatus =
        (_selectedStatus ?? 'active').trim().toLowerCase();

    if (![
      'active',
      'inactive',
      'suspended',
    ].contains(driverStatus)) {
      driverStatus = 'active';
    }

    // =====================================================
    // EDIT DRIVER
    // =====================================================
    if (_isEditing) {
      final driverId =
          widget.driverToEdit!['driver_id'];
final updatePayload = {
  'name': _nameController.text.trim(),
  'contact': _contactController.text.trim(),
  'license_number': _licenseController.text.trim(),

  'operator_id': int.parse(_selectedOperatorId!),
  'tricycle_id': int.parse(_selectedTricycleId!),
  'status': driverStatus,

  // Driver's Permit
  'permit_number': _permitNumberController.text.trim(),
  'permit_address': _permitAddressController.text.trim(),
  'permit_license_number':
      _permitLicenseNumberController.text.trim(),
  'permit_issued_date':
      _permitIssuedDateController.text.trim(),
  'permit_valid_until':
      _permitValidUntilController.text.trim(),
  'permit_control_no':
      _permitControlNoController.text.trim(),
  'permit_or_no':
      _permitOrNoController.text.trim(),
  'permit_amount':
      _permitAmountController.text.trim(),
  'permit_payment_date':
      _permitPaymentDateController.text.trim(),
};

await supabase
    .from('drivers')
    .update(updatePayload)
    .eq('driver_id', driverId);
    }

    // =====================================================
    // REGISTER NEW DRIVER
    // =====================================================
    else {
     final insertPayload = {
  'name': _nameController.text.trim(),
  'contact': _contactController.text.trim(),
  'license_number': _licenseController.text.trim(),

  'operator_id': int.parse(_selectedOperatorId!),
  'tricycle_id': int.parse(_selectedTricycleId!),
  'status': driverStatus,

  // Driver's Permit
  'permit_number': _permitNumberController.text.trim(),
  'permit_address': _permitAddressController.text.trim(),
  'permit_license_number':
      _permitLicenseNumberController.text.trim(),
  'permit_issued_date':
      _permitIssuedDateController.text.trim(),
  'permit_valid_until':
      _permitValidUntilController.text.trim(),
  'permit_control_no':
      _permitControlNoController.text.trim(),
  'permit_or_no':
      _permitOrNoController.text.trim(),
  'permit_amount':
      _permitAmountController.text.trim(),
  'permit_payment_date':
      _permitPaymentDateController.text.trim(),
};
      await supabase
          .from('drivers')
          .insert(insertPayload);
    }

    if (!mounted) return;

    Navigator.of(context).pop(true);
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Error saving driver: $e',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}
  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // =================================================
                      // TITLE
                      // =================================================

                      Text(
                        _isEditing
                            ? 'Edit Driver'
                            : 'Register New Driver',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // =================================================
                      // NAME
                      // =================================================

                      _buildTextField(
                        _nameController,
                        'Full Name',
                        Icons.person,
                      ),

                      // =================================================
                      // CONTACT
                      // =================================================

                      _buildTextField(
                        _contactController,
                        'Contact',
                        Icons.phone,
                        TextInputType.phone,
                      ),

                      // =================================================
                      // LICENSE
                      // =================================================

                      _buildTextField(
                        _licenseController,
                        'License #',
                        Icons.badge,
                      ),

                     const SizedBox(height: 12),

// =====================================================
// DRIVER'S PERMIT
// =====================================================

const Text(
  "Driver's Permit",
  style: TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 16),

_buildTextField(
  _permitNumberController,
  'Permit No.',
  Icons.confirmation_number,
),

_buildTextField(
  _permitAddressController,
  'Permit Address',
  Icons.location_on,
),

_buildTextField(
  _permitLicenseNumberController,
  "Driver's License No.",
  Icons.badge,
),

_buildDateField(
  _permitIssuedDateController,
  'Issued Date',
  Icons.calendar_today,
),

_buildDateField(
  _permitValidUntilController,
  'Valid Until',
  Icons.event_available,
),

_buildTextField(
  _permitControlNoController,
  'Control No.',
  Icons.numbers,
),

_buildTextField(
  _permitOrNoController,
  'O.R. No.',
  Icons.receipt_long,
),

_buildTextField(
  _permitAmountController,
  'Amount',
  Icons.payments,
  TextInputType.number,
),

_buildDateField(
  _permitPaymentDateController,
  'Payment Date',
  Icons.calendar_month,
),

const SizedBox(height: 12),
                      // =================================================
                      // OPERATOR SEARCH POPUP
                      // =================================================

                      TextFormField(
                        controller:
                            _operatorController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Operator',
                          hintText:
                              'Select operator',
                          prefixIcon:
                              const Icon(
                            Icons.business,
                          ),
                          suffixIcon:
                              const Icon(
                            Icons.arrow_drop_down,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (_selectedOperatorId ==
                                  null ||
                              _selectedOperatorId!
                                  .isEmpty) {
                            return 'Please select an operator';
                          }

                          return null;
                        },
                        onTap:
                            _showOperatorSelector,
                      ),

                      const SizedBox(height: 24),

                      // =================================================
                      // BODY NUMBER
                      // =================================================

                      DropdownButtonFormField<String>(
                        value:
                            _getValidSelectedTricycleId(),
                        isExpanded: true,
                        decoration:
                            InputDecoration(
                          labelText: 'Body Number',
                          hintText:
                              _selectedOperatorId ==
                                      null
                                  ? 'Select an operator first'
                                  : _getUniqueTricycles()
                                          .isEmpty
                                      ? 'No tricycle available'
                                      : 'Select body number',
                          prefixIcon:
                              const Icon(
                            Icons.directions_bike,
                          ),
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                          ),
                        ),
                        items:
                            _buildTricycleDropdownItems(),
                        validator: (value) {
                          if (_selectedOperatorId ==
                              null) {
                            return 'Please select an operator first';
                          }

                          if (value == null ||
                              value.isEmpty) {
                            return 'Please select a body number';
                          }

                          return null;
                        },
                        onChanged:
                            _selectedOperatorId ==
                                    null ||
                                _getUniqueTricycles()
                                    .isEmpty
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedTricycleId =
                                      value;

                                  final selected =
                                      _getUniqueTricycles()
                                          .where(
                                    (tricycle) =>
                                        tricycle[
                                                'tricycle_id']
                                            ?.toString() ==
                                        value,
                                  );

                                  if (selected
                                      .isNotEmpty) {
                                    _bodyNumberController
                                            .text =
                                        selected
                                                .first[
                                                    'body_number']
                                                ?.toString() ??
                                            '';
                                  }
                                });
                              },
                      ),

                      const SizedBox(height: 24),

                      // =================================================
                      // STATUS
                      // =================================================

            DropdownButtonFormField<String>(
  value: _selectedStatus,
  decoration: const InputDecoration(
    labelText: 'Status',
    prefixIcon: Icon(Icons.info_outline),
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(
      value: 'Active',
      child: Text('Active'),
    ),
    DropdownMenuItem(
      value: 'Inactive',
      child: Text('Inactive'),
    ),
    DropdownMenuItem(
      value: 'Suspended',
      child: Text('Suspended'),
    ),
  ],
  onChanged: (value) {
    setState(() {
      _selectedStatus = value;
    });
  },
),
            
                      const SizedBox(height: 24),

                      // =================================================
                      // ACTION BUTTONS
                      // =================================================

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () =>
                                        Navigator.pop(
                                          context,
                                        ),
                            child:
                                const Text(
                              'Cancel',
                            ),
                          ),

                          const SizedBox(width: 8),

                          ElevatedButton(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color:
                                          Colors.white,
                                    ),
                                  )
                                : Text(
                                    _isEditing
                                        ? 'Update'
                                        : 'Register',
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // =====================================================
  // OPERATOR SELECTOR
  // =====================================================

  Future<void> _showOperatorSelector() async {
    if (!mounted) return;

    final selectedOperator =
        await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        List<Map<String, dynamic>>
            filteredOperators =
            List<Map<String, dynamic>>.from(
          _operators,
        );

        final searchController =
            TextEditingController();

        return StatefulBuilder(
          builder:
              (context, setDialogState) {
            return AlertDialog(
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16),
              ),
              title: const Text(
                'Select Operator',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              content: SizedBox(
                width: 400,
                height: 400,
                child: Column(
                  children: [
                    // =================================================
                    // SEARCH
                    // =================================================

                    TextField(
                      controller:
                          searchController,
                      autofocus: true,
                      decoration:
                          InputDecoration(
                        hintText:
                            'Search operator...',
                        prefixIcon:
                            const Icon(
                          Icons.search,
                        ),
                        suffixIcon:
                            searchController
                                    .text
                                    .isNotEmpty
                                ? IconButton(
                                    icon:
                                        const Icon(
                                      Icons.clear,
                                    ),
                                    onPressed:
                                        () {
                                      searchController
                                          .clear();

                                      setDialogState(
                                        () {
                                          filteredOperators =
                                              List<
                                                  Map<
                                                      String,
                                                      dynamic>>.from(
                                            _operators,
                                          );
                                        },
                                      );
                                    },
                                  )
                                : null,
                        border:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                      ),
                      onChanged: (value) {
                        final query =
                            value
                                .trim()
                                .toLowerCase();

                        setDialogState(() {
                          if (query.isEmpty) {
                            filteredOperators =
                                List<
                                    Map<
                                        String,
                                        dynamic>>.from(
                              _operators,
                            );
                          } else {
                            filteredOperators =
                                _operators
                                    .where(
                              (operator) {
                                final name =
                                    operator[
                                            'name']
                                        ?.toString()
                                        .toLowerCase() ??
                                    '';

                                return name
                                    .contains(
                                  query,
                                );
                              },
                            ).toList();
                          }
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // =================================================
                    // OPERATOR LIST
                    // =================================================

                    Expanded(
                      child:
                          filteredOperators
                                  .isEmpty
                              ? const Center(
                                  child: Text(
                                    'No operator found',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.grey,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount:
                                      filteredOperators
                                          .length,
                                  itemBuilder:
                                      (
                                    context,
                                    index,
                                  ) {
                                    final operator =
                                        filteredOperators[
                                            index];

                                    final name =
                                        operator[
                                                'name']
                                            ?.toString() ??
                                        'Unknown';

                                    return ListTile(
                                      leading:
                                          const CircleAvatar(
                                        child:
                                            Icon(
                                          Icons
                                              .business,
                                        ),
                                      ),
                                      title:
                                          Text(
                                        name,
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      onTap:
                                          () {
                                        Navigator.pop(
                                          dialogContext,
                                          operator,
                                        );
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
                    Navigator.pop(
                      dialogContext,
                    );
                  },
                  child:
                      const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    // =====================================================
    // OPERATOR SELECTED
    // =====================================================

    if (selectedOperator == null ||
        !mounted) {
      return;
    }

    final operatorId =
        selectedOperator['operator_id']
            ?.toString();

    final operatorName =
        selectedOperator['name']
                ?.toString() ??
            '';

    if (operatorId == null ||
        operatorId.isEmpty) {
      return;
    }

    setState(() {
      // Save operator ID
      _selectedOperatorId =
          operatorId;

      // Display operator name
      _operatorController.text =
          operatorName;

      // Filter tricycles
      _filteredTricycles =
          _allTricycles
              .where(
        (tricycle) =>
            tricycle['operator_id']
                ?.toString() ==
            operatorId,
      ).toList();

      // Remove duplicates
      _filteredTricycles =
          _removeDuplicateTricycles(
        _filteredTricycles,
      );

      // Reset previous tricycle
      _selectedTricycleId = null;

      _bodyNumberController.clear();
    });
  }
// =====================================================
// DATE PICKER FIELD
// =====================================================

Widget _buildDateField(
  TextEditingController controller,
  String label,
  IconData icon,
) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.calendar_month),
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }

        return null;
      },
      onTap: () async {
        DateTime initialDate = DateTime.now();

        // If there is already a date, use it when editing
        if (controller.text.trim().isNotEmpty) {
          try {
            initialDate = DateTime.parse(
              controller.text.trim(),
            );
          } catch (_) {
            initialDate = DateTime.now();
          }
        }

        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          helpText: 'Select $label',
        );

        if (pickedDate != null) {
          final String formattedDate =
              '${pickedDate.year.toString().padLeft(4, '0')}-'
              '${pickedDate.month.toString().padLeft(2, '0')}-'
              '${pickedDate.day.toString().padLeft(2, '0')}';

          setState(() {
            controller.text = formattedDate;
          });
        }
      },
    ),
  );
}
  // =====================================================
  // TEXT FIELD
  // =====================================================

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, [
    TextInputType type =
        TextInputType.text,
  ]) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border:
              const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null ||
              value.trim().isEmpty) {
            return 'Required';
          }

          return null;
        },
      ),
       
    );
  }
}