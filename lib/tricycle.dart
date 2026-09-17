import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TricycleRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? tricycleToEdit;

  const TricycleRegistrationScreen({
    super.key,
    this.tricycleToEdit,
  });

  @override
  State<TricycleRegistrationScreen> createState() =>
      _TricycleRegistrationScreenState();
}

class _TricycleRegistrationScreenState
    extends State<TricycleRegistrationScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  // Controllers
  final TextEditingController _operatorController =
      TextEditingController();

  final TextEditingController _bodyNumberController =
      TextEditingController();

  final TextEditingController _todaAssociationController =
      TextEditingController();

  // Operators
  List<Map<String, dynamic>> _operators = [];

  String? _selectedOperatorId;

  bool _isLoading = true;
  bool _isSubmitting = false;

  bool get _isEditing => widget.tricycleToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadOperators();
  }

  @override
  void dispose() {
    _operatorController.dispose();
    _bodyNumberController.dispose();
    _todaAssociationController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD OPERATORS
  // ============================================================

  Future<void> _loadOperators() async {
    try {
      final response = await supabase
          .from('operators')
          .select('operator_id, name')
          .order('name');

      final operators =
          List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        _operators = operators;
        _isLoading = false;
      });

      // ========================================================
      // LOAD DATA WHEN EDITING
      // ========================================================

      if (_isEditing) {
        final data = widget.tricycleToEdit!;

        _bodyNumberController.text =
            data['body_number']?.toString() ?? '';

        _todaAssociationController.text =
            data['toda_association']?.toString() ?? '';

        _selectedOperatorId =
            data['operator_id']?.toString();

        // Find selected operator
        final selectedOperator =
            _operators.where(
          (operator) =>
              operator['operator_id'].toString() ==
              _selectedOperatorId,
        );

        if (selectedOperator.isNotEmpty) {
          _operatorController.text =
              selectedOperator.first['name']
                      ?.toString() ??
                  '';
        }

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error loading operators: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SAVE / UPDATE
  // ============================================================
Future<void> _submit() async {
  // Validate Operator
  if (_selectedOperatorId == null ||
      _selectedOperatorId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please select an operator.',
        ),
      ),
    );
    return;
  }

  // Validate Body Number
  final bodyNumber =
      _bodyNumberController.text.trim();

  if (bodyNumber.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please enter the body number.',
        ),
      ),
    );
    return;
  }

  // Validate TODA Association
  final todaAssociation =
      _todaAssociationController.text.trim();

  if (todaAssociation.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please enter the TODA association.',
        ),
      ),
    );
    return;
  }

  setState(() {
    _isSubmitting = true;
  });

  try {
    final payload = {
      'operator_id': int.parse(
        _selectedOperatorId!,
      ),
      'body_number': bodyNumber,
      'toda_association': todaAssociation,
    };

    // UPDATE
    if (_isEditing) {
      await supabase
          .from('tricycles')
          .update(payload)
          .eq(
            'tricycle_id',
            widget.tricycleToEdit!['tricycle_id'],
          );
    }

    // INSERT
    else {
      await supabase
          .from('tricycles')
          .insert(payload);
    }

    if (!mounted) return;

    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to save tricycle: $e',
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
}
  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),

      // ========================================================
      // TITLE
      // ========================================================

      title: Row(
        children: [
          Icon(
            _isEditing
                ? Icons.edit
                : Icons.add_circle_outline,
            color: Colors.green.shade700,
          ),

          const SizedBox(width: 10),

          Text(
            _isEditing
                ? 'Edit Tricycle'
                : 'Register New Tricycle',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),

      // ========================================================
      // CONTENT
      // ========================================================

      content: SizedBox(
        width: 500,

        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

// Operator Dropdown
// Searchable Operator Dropdown
// Searchable Operator Popup
TextFormField(
  controller: _operatorController,
  readOnly: true,

  decoration: InputDecoration(
    labelText: 'Operator',
    hintText: 'Select operator',

    prefixIcon: const Icon(Icons.business),

    suffixIcon: const Icon(
      Icons.arrow_drop_down,
    ),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),

  validator: (value) {
    if (_selectedOperatorId == null) {
      return 'Please select an operator';
    }

    return null;
  },

  onTap: () async {
    final selectedOperator =
        await showDialog<Map<String, dynamic>>(
      context: context,

      builder: (context) {
        List<Map<String, dynamic>> filteredOperators =
            List.from(_operators);

        final searchController =
            TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                    // SEARCH
                    TextField(
                      controller: searchController,
                      autofocus: true,

                      decoration: InputDecoration(
                        hintText: 'Search operator...',

                        prefixIcon:
                            const Icon(Icons.search),

                        suffixIcon:
                            searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                    ),

                                    onPressed: () {
                                      searchController.clear();

                                      setDialogState(() {
                                        filteredOperators =
                                            List.from(
                                          _operators,
                                        );
                                      });
                                    },
                                  )
                                : null,

                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),

                      onChanged: (value) {
                        setDialogState(() {
                          filteredOperators =
                              _operators.where(
                            (operator) {
                              final name =
                                  operator['name']
                                          ?.toString()
                                          .toLowerCase() ??
                                      '';

                              return name.contains(
                                value.toLowerCase(),
                              );
                            },
                          ).toList();
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // OPERATOR LIST
                    Expanded(
                      child: filteredOperators.isEmpty
                          ? const Center(
                              child: Text(
                                'No operator found',
                                style: TextStyle(
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount:
                                  filteredOperators.length,

                              itemBuilder:
                                  (context, index) {
                                final operator =
                                    filteredOperators[index];

                                return ListTile(
                                  leading:
                                      const CircleAvatar(
                                    child: Icon(
                                      Icons.business,
                                    ),
                                  ),

                                  title: Text(
                                    operator['name']
                                        .toString(),

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),

                                  onTap: () {
                                    Navigator.pop(
                                      context,
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
                    Navigator.pop(context);
                  },

                  child: const Text(
                    'Cancel',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // SET SELECTED OPERATOR
    if (selectedOperator != null) {
      setState(() {
        final operatorId =
            selectedOperator['operator_id']
                .toString();

        final operatorName =
            selectedOperator['name']
                .toString();

        // Save selected operator ID
        _selectedOperatorId = operatorId;

        // Display selected operator name
        _operatorController.text = operatorName;
      });
    }
  },
),

                    const SizedBox(height: 18),

                    // =================================================
                    // 2. BODY NUMBER
                    // =================================================

                    TextFormField(
  controller: _bodyNumberController,

  decoration: InputDecoration(
    labelText: 'Body Number',
    hintText: 'Enter body number',

    prefixIcon: const Icon(
      Icons.directions_car,
    ),

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: Colors.green.shade700,
        width: 2,
      ),
    ),
  ),
),
                    const SizedBox(height: 18),

                    // =================================================
                    // 3. TODA ASSOCIATION
                    // =================================================

                    TextFormField(
                      controller:
                          _todaAssociationController,

                      decoration: InputDecoration(
                        labelText:
                            'TODA Association',

                        hintText:
                            'Enter TODA association',

                        prefixIcon: const Icon(
                          Icons.groups,
                        ),

                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                        ),

                        focusedBorder:
                            OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color:
                                Colors.green.shade700,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // =================================================
                    // BUTTONS
                    // =================================================

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.end,
                      children: [

                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  Navigator.pop(
                                    context,
                                  );
                                },
                          child: const Text(
                            'Cancel',
                          ),
                        ),

                        const SizedBox(width: 10),

                        ElevatedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : _submit,

                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color:
                                        Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save,
                                ),

                          label: Text(
                            _isEditing
                                ? 'Update'
                                : 'Register',
                          ),

                          style:
                              ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromARGB(
                              255,
                              10,
                              116,
                              36,
                            ),
                            foregroundColor:
                                Colors.white,

                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),

                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}