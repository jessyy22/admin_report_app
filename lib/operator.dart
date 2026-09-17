import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class OperatorRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? operatorToEdit;

  const OperatorRegistrationScreen({
    super.key,
    this.operatorToEdit,
  });

  @override
  State<OperatorRegistrationScreen> createState() =>
      _OperatorRegistrationScreenState();
}

class _OperatorRegistrationScreenState
    extends State<OperatorRegistrationScreen> {

  final SupabaseClient supabase = Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _operatorIdController =
      TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController =
      TextEditingController();
  final TextEditingController _addressController =
      TextEditingController();

  bool _isSubmitting = false;
  bool get _isEditing => widget.operatorToEdit != null;

  @override
void initState() {
  super.initState();

  if (_isEditing) {
    final operator = widget.operatorToEdit!;

    _operatorIdController.text =
        operator['operator_id']?.toString() ?? '';

    _nameController.text =
        operator['name'] ?? '';

    _contactController.text =
        operator['contact'] ?? '';

    _addressController.text =
        operator['address'] ?? '';
  }
}

  /// CREATE & UPDATE
  Future<void> _saveOperator() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isSubmitting = true;
  });

  try {
 if (_isEditing) {
  await supabase
      .from('operators')
      .update({
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'address': _addressController.text.trim(),
      })
      .eq('operator_id', _operatorIdController.text.trim());

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Operator updated successfully"),
    ),
  );
} else {
  await supabase
      .from('operators')
      .insert({
        'name': _nameController.text.trim(),
        'contact': _contactController.text.trim(),
        'address': _addressController.text.trim(),
      });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Operator registered successfully"),
    ),
  );
}
if (mounted) {
  Navigator.pop(context, true);
}


    _clearForm();
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e")),
    );
  }

  if (mounted) {
  setState(() {
    _isSubmitting = false;
  });
}
}
  /// DELETE
  Future<void> _deleteOperator(String id) async {
  bool? confirm = await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Delete Operator"),
      content: const Text(
        "Are you sure you want to delete this operator?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete"),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await supabase
        .from('operators')
        .delete()
        .eq('id', int.parse(id));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Operator deleted"),
      ),
    );
  }
}

  /// EDIT
  void _editOperator(Map<String, dynamic> data) {
  _operatorIdController.text = data['operator_id'] ?? '';
  _nameController.text = data['name'] ?? '';
  _contactController.text = data['contact'] ?? '';
  _addressController.text = data['address'] ?? '';

  setState(() {
    _isSubmitting = false;
  });

  Scrollable.ensureVisible(
    _formKey.currentContext!,
    duration: const Duration(milliseconds: 300),
  );
}

  /// CLEAR FORM
  void _clearForm() {
    _operatorIdController.clear();
    _nameController.clear();
    _contactController.clear();
    _addressController.clear();

   setState(() {
    _isSubmitting = false;
  });
  }

  @override
  void dispose() {
    _operatorIdController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    super.dispose();
  }

 InputDecoration fieldDecoration(
  String hint,
  IconData icon,
) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 18,
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Dialog(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
    child: Container(
      width: 450,
      padding: const EdgeInsets.all(24),
     child: _isSubmitting
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          Text(
  _isEditing
      ? "Edit Operator"
      : "Register New Operator",
  style: const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

                  const SizedBox(height: 12),

                  TextFormField(
                 controller: _nameController,
                 decoration: fieldDecoration(
                     "Full Name",
                 Icons.person,
                 ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _contactController,
                   keyboardType: TextInputType.phone,
                   decoration: fieldDecoration(
                         "Contact",
                  Icons.phone,
                      ),
                      ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _addressController,
                    decoration: fieldDecoration(
                         "Address",
                   Icons.location_on,
                      ),
                      ),

                  const SizedBox(height: 12),
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text("Cancel"),
    ),

    const SizedBox(width: 12),

    ElevatedButton(
      onPressed: _isSubmitting ? null : _saveOperator,
      child: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(_isEditing ? "Update" : "Register"),
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
    }