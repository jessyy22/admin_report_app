import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'user_session.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplaintReviewPage extends StatefulWidget {
  final String documentId;
  final Map<String, dynamic> complaintData;

  const ComplaintReviewPage({
    super.key,
    required this.documentId,
    required this.complaintData,
  });

  @override
  State<ComplaintReviewPage> createState() =>
      _ComplaintReviewPageState();
}

class _ComplaintReviewPageState extends State<ComplaintReviewPage> {
  late String _selectedStatus;

  final TextEditingController _staffController =
      TextEditingController();

  final TextEditingController _notesController =
      TextEditingController();

  final TextEditingController _bodyNumberController =
      TextEditingController();

  bool _isLoading = false;

  final List<String> _statusOptions = [
    'Pending',
    'Under Investigation',
    'Summoned',
    'Resolved',
    'Dismissed',
  ];

  @override
  void initState() {
    super.initState();

    _fetchUserInfo();

    final user =
        Supabase.instance.client.auth.currentUser;

    final String currentStaff =
        user?.email ?? 'Unknown Staff';

    _bodyNumberController.text =
        widget.complaintData['body_number']
                ?.toString() ??
            '';

    _selectedStatus =
        widget.complaintData['status']
                ?.toString() ??
            'Pending';

    _staffController.text =
        widget.complaintData['assigned_staff']
                ?.toString() ??
            currentStaff;

    _notesController.text =
        widget.complaintData['action_taken']
                ?.toString() ??
            '';
  }

  Future<void> _fetchUserInfo() async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    try {
      final response =
          await Supabase.instance.client
              .from('admin_profiles')
              .select('role, full_name')
              .eq('id', user.id)
              .single();

      if (mounted) {
        setState(() {
          UserSession.role =
              response['role']?.toString();

          _staffController.text =
              response['full_name']?.toString() ??
                  'Unknown Staff';
        });
      }
    } catch (e) {
      debugPrint(
        "Error loading user info: $e",
      );
    }
  }

  @override
  void dispose() {
    _staffController.dispose();
    _notesController.dispose();
    _bodyNumberController.dispose();
    super.dispose();
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) {
      return 'N/A';
    }

    try {
      return DateFormat(
        'MMM d, yyyy - hh:mm a',
      ).format(
        DateTime.parse(
          timestamp.toString(),
        ),
      );
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // =========================================================
  // GET REPORTER NAME
  // =========================================================

  String _getReporterName() {
    final data = widget.complaintData;

    final reporterName =
        data['reporter_name'];

    if (reporterName != null &&
        reporterName.toString().trim().isNotEmpty &&
        reporterName.toString() != 'N/A') {
      return reporterName.toString();
    }

    final fullName =
        data['full_name'];

    if (fullName != null &&
        fullName.toString().trim().isNotEmpty &&
        fullName.toString() != 'N/A') {
      return fullName.toString();
    }

    return 'Unknown Reporter';
  }

  // =========================================================
  // GET REPORTER EMAIL
  // =========================================================

  String _getReporterEmail() {
    final data = widget.complaintData;

    return data['reporter_email']?.toString() ??
        data['email']?.toString() ??
        'N/A';
  }

  // =========================================================
  // GET LOCATION
  // =========================================================

  String _getLocation() {
    final data = widget.complaintData;

    final location =
        data['location'];

    if (location != null &&
        location.toString().trim().isNotEmpty &&
        location.toString() != 'N/A') {
      return location.toString();
    }

    return 'Location not provided';
  }

  // =========================================================
  // GET LATITUDE
  // =========================================================

  String _getLatitude() {
    final value =
        widget.complaintData['latitude'];

    return value?.toString() ?? 'N/A';
  }

  // =========================================================
  // GET LONGITUDE
  // =========================================================

  String _getLongitude() {
    final value =
        widget.complaintData['longitude'];

    return value?.toString() ?? 'N/A';
  }
  Future<void> _openIncidentLocation() async {
  final latitude =
      widget.complaintData['latitude'];

  final longitude =
      widget.complaintData['longitude'];

  if (latitude == null || longitude == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'GPS location is not available for this incident.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final double? lat =
      double.tryParse(latitude.toString());

  final double? lng =
      double.tryParse(longitude.toString());

  if (lat == null || lng == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Invalid GPS coordinates.',
        ),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  final Uri mapUrl = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
  );

  try {
    final bool launched = await launchUrl(
      mapUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      throw Exception(
        'Could not open Google Maps',
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open map: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  // =========================================================
  // UPDATE COMPLAINT
  // =========================================================

  Future<void> _updateComplaint() async {
    setState(() => _isLoading = true);

    try {
      final user =
          Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception(
          'User is not authenticated.',
        );
      }

      await Supabase.instance.client
          .from('reports')
          .update({
        'status': _selectedStatus,
        'assigned_staff_id': user.id,
        'action_taken':
            _notesController.text.trim(),
        'reviewed_at':
            DateTime.now().toIso8601String(),
      }).eq(
        'report_id',
        widget.documentId,
      );

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content:
                Text('Updated Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
                Text('Update Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(
          () => _isLoading = false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canEdit =
        UserSession.role == 'admin' ||
        UserSession.role == 'staff';

    return Scaffold(
      backgroundColor: Colors.grey[50],

      appBar: AppBar(
        title: const Text(
          'Review Complaint',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),

      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.all(16.0),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  // =====================================================
                  // COMPLAINT SUMMARY
                  // =====================================================

                  const Text(
                    "COMPLAINT SUMMARY",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 10),
Card(
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      children: [
        _detailRow(
          'Body Number',
          widget.complaintData['body_number'],
        ),

        _detailRow(
          'Tricycle ID',
          widget.complaintData['tricycle_id'],
        ),

        _detailRow(
          'Violation',
          widget.complaintData['violation'],
        ),

        _detailRow(
          'Reported By',
          widget.complaintData['report_name'],
        ),

        _detailRow(
          'Location',
          widget.complaintData['location'],
        ),

        _detailRow(
          'Submitted',
          _formatDate(
            widget.complaintData['created_at'],
          ),
        ),
      ],
    ),
  ),
),
                  const SizedBox(height: 25),

                  // =====================================================
                  // REPORTER INFORMATION
                  // =====================================================

                  const Text(
                    "REPORTER INFORMATION",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                              16),

                      child: Column(
                        children: [

                          // Reporter name
                          _iconDetailRow(
                            Icons.person,
                            'Reported By',
                            _getReporterName(),
                            Colors.blue,
                          ),

                          const Divider(),

                          // Reporter email
                          _iconDetailRow(
                            Icons.email,
                            'Email',
                            _getReporterEmail(),
                            Colors.indigo,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =====================================================
                  // LOCATION
                  // =====================================================

                  const Text(
                    "REPORT LOCATION",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Card(
                    elevation: 2,

                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                              16),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [

                          // Location header
                          Row(
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets
                                        .all(10),

                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .red
                                      .withOpacity(
                                          0.1),
                                  shape:
                                      BoxShape
                                          .circle,
                                ),

                                child:
                                    const Icon(
                                  Icons
                                      .location_on,
                                  color:
                                      Colors.red,
                                ),
                              ),

                              const SizedBox(
                                  width: 12),

                              const Text(
                                'Incident Location',
                                style:
                                    TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                              height: 15),

                          // Location text
                          Container(
                            width:
                                double.infinity,

                            padding:
                                const EdgeInsets
                                    .all(14),

                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.grey[100],

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                          10),

                              border:
                                  Border.all(
                                color:
                                    Colors.grey[
                                        300]!,
                              ),
                            ),

                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [

                                const Icon(
                                  Icons
                                      .place,
                                  color:
                                      Colors.red,
                                ),

                                const SizedBox(
                                    width: 10),

                                Expanded(
                                  child: Text(
                                    _getLocation(),

                                    style:
                                        const TextStyle(
                                      fontSize:
                                          15,
                                      fontWeight:
                                          FontWeight
                                              .w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                              height: 15),

                          // GPS coordinates
                          Row(
                            children: [

                              Expanded(
                                child:
                                    _coordinateBox(
                                  'Latitude',
                                  _getLatitude(),
                                ),
                              ),

                              const SizedBox(
                                  width: 10),

                              Expanded(
                                child:
                                    _coordinateBox(
                                  'Longitude',
                                  _getLongitude(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),
                  const SizedBox(height: 15),

SizedBox(
  width: double.infinity,
  height: 48,
  child: ElevatedButton.icon(
    onPressed: _openIncidentLocation,
    icon: const Icon(Icons.map),
    label: const Text(
      'VIEW INCIDENT ON MAP',
      style: TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
  ),
),

                  // =====================================================
                  // UPDATE STATUS
                  // =====================================================

                  const Text(
                    "UPDATE STATUS",
                    style: TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                              16.0),

                      child: Column(
                        children: [

                          DropdownButtonFormField<
                              String>(
                            value:
                                _selectedStatus,

                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Status',
                              border:
                                  OutlineInputBorder(),
                              filled: true,
                            ),

                            items:
                                _statusOptions
                                    .map(
                              (s) =>
                                  DropdownMenuItem(
                                value: s,
                                child:
                                    Text(s),
                              ),
                            ).toList(),

                            onChanged: canEdit
                                ? (val) {
                                    if (val !=
                                        null) {
                                      setState(
                                        () =>
                                            _selectedStatus =
                                                val,
                                      );
                                    }
                                  }
                                : null,
                          ),

                          const SizedBox(
                              height: 16),

                          TextField(
                            controller:
                                _staffController,

                            enabled: false,

                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Assigned Staff',
                              border:
                                  OutlineInputBorder(),
                              filled: true,
                              fillColor:
                                  Colors.black12,
                            ),
                          ),

                          const SizedBox(
                              height: 16),

                          TextField(
                            controller:
                                _notesController,

                            enabled: canEdit,

                            maxLines: 4,

                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Action Taken / Notes',
                              border:
                                  OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // =====================================================
                  // SAVE BUTTON
                  // =====================================================

                  if (canEdit)
                    SizedBox(
                      width:
                          double.infinity,
                      height: 50,

                      child:
                          ElevatedButton.icon(
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.orange,
                          foregroundColor:
                              Colors.white,
                        ),

                        onPressed:
                            _updateComplaint,

                        icon: const Icon(
                          Icons.save_outlined,
                        ),

                        label: const Text(
                          'SAVE UPDATES',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  // =========================================================
  // NORMAL DETAIL ROW
  // =========================================================

  Widget _detailRow(
    String label,
    dynamic value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
              vertical: 6),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          SizedBox(
            width: 100,

            child: Text(
              '$label:',

              style: const TextStyle(
                fontWeight:
                    FontWeight.bold,
                color:
                    Colors.blueGrey,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value?.toString() ??
                  'N/A',
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ICON DETAIL ROW
  // =========================================================

  Widget _iconDetailRow(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        Icon(
          icon,
          color: color,
          size: 22,
        ),

        const SizedBox(width: 12),

        SizedBox(
          width: 110,

          child: Text(
            label,
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
              color:
                  Colors.blueGrey,
            ),
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // COORDINATE BOX
  // =========================================================

  Widget _coordinateBox(
    String label,
    String value,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius:
            BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
