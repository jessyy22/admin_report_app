import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/notification_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _searchQuery = '';
  String _statusFilter = 'All';

  // ============================================================
  // LOAD COMMUTER + DRIVER PROFILES
  // ============================================================

  Future<Map<String, Map<String, dynamic>>> _loadProfiles() async {
    final profiles = <String, Map<String, dynamic>>{};

    try {
      final commuters = await _supabase
          .from('commuter_profiles')
          .select(
            'id, full_name, phone_number, is_verified',
          );

      for (final row in commuters) {
        final profile = Map<String, dynamic>.from(row);

        final id =
            profile['id']?.toString().trim() ?? '';

        if (id.isEmpty) continue;

        profiles[id] = {
          ...profile,
          '_profile_role': 'commuter',
        };
      }
    } catch (e) {
      debugPrint(
        'Error loading commuter profiles: $e',
      );
    }

    try {
      final drivers = await _supabase
          .from('driver_profiles')
          .select(
            'id, full_name, phone_number, body_number, '
            'is_active, verification_status',
          );

      for (final row in drivers) {
        final profile = Map<String, dynamic>.from(row);

        final id =
            profile['id']?.toString().trim() ?? '';

        if (id.isEmpty) continue;

        profiles[id] = {
          ...profile,
          '_profile_role': 'driver',
        };
      }
    } catch (e) {
      debugPrint(
        'Error loading driver profiles: $e',
      );
    }

    return profiles;
  }

  // ============================================================
  // LOAD AUTH EMAILS
  // ============================================================

  Future<Map<String, String>> _loadEmails() async {
    final emails = <String, String>{};

    try {
      final result = await _supabase.rpc(
        'get_user_emails',
      );

      for (final row in result) {
        final id =
            row['id']?.toString().trim() ?? '';

        final email =
            row['email']?.toString().trim() ?? '';

        if (id.isNotEmpty && email.isNotEmpty) {
          emails[id] = email;
        }
      }
    } catch (e) {
      debugPrint(
        'Error loading user emails: $e',
      );
    }

    return emails;
  }

  // ============================================================
  // BUILD USERS
  // ============================================================
Future<List<Map<String, dynamic>>> _buildUsers(
  List<Map<String, dynamic>> roles,
) async {
  final results = await Future.wait([
    _loadProfiles(),
    _loadEmails(),
  ]);

  final profiles =
      results[0] as Map<String, Map<String, dynamic>>;

  final emails =
      results[1] as Map<String, String>;

  final users = <Map<String, dynamic>>[];

  for (final row in roles) {
    final userId =
        row['id']?.toString().trim() ?? '';

    final role =
        row['role']
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';

    if (userId.isEmpty) continue;

    Map<String, dynamic>? profile =
        profiles[userId];

    // ----------------------------------------------------------
    // IMPORTANT:
    // Explicitly retrieve the profile using user_roles.id.
    // ----------------------------------------------------------

    if (role == 'commuter') {
      try {
        final commuter =
            await _supabase
                .from('commuter_profiles')
                .select(
                  'id, full_name, phone_number, is_verified',
                )
                .eq('id', userId)
                .maybeSingle();

        if (commuter != null) {
          profile =
              Map<String, dynamic>.from(commuter);
        }
      } catch (e) {
        debugPrint(
          'Could not load commuter $userId: $e',
        );
      }
    }

    if (role == 'driver') {
      try {
        final driver =
            await _supabase
                .from('driver_profiles')
                .select(
                  'id, full_name, phone_number, '
                  'body_number, is_active, '
                  'verification_status',
                )
                .eq('id', userId)
                .maybeSingle();

        if (driver != null) {
          profile =
              Map<String, dynamic>.from(driver);
        }
      } catch (e) {
        debugPrint(
          'Could not load driver $userId: $e',
        );
      }
    }

    // ----------------------------------------------------------
    // NAME
    // ----------------------------------------------------------

    final name =
        (profile?['full_name'] ?? '')
            .toString()
            .trim();

    // ----------------------------------------------------------
    // EMAIL
    // ----------------------------------------------------------

    final email =
        (emails[userId] ?? '')
            .toString()
            .trim();

    // ----------------------------------------------------------
    // STATUS
    // ----------------------------------------------------------

    String status;

    if (role == 'commuter') {
      status =
          profile?['is_verified'] == true
              ? 'email_verified'
              : 'email_not_verified';
    } else if (role == 'driver') {
      final verificationStatus =
          profile?['verification_status']
              ?.toString()
              .trim()
              .toLowerCase();

      if (verificationStatus == 'approved' ||
          verificationStatus == 'rejected' ||
          verificationStatus == 'pending') {
        status = verificationStatus!;
      } else {
        status =
            profile?['is_active'] == true
                ? 'approved'
                : 'pending';
      }
    } else {
      status = 'active';
    }

    // ----------------------------------------------------------
    // ADD USER
    // ----------------------------------------------------------

    users.add({
      'user_id': userId,
      'full_name': name,
      'email': email,
      'role': role,
      'status': status,
      'phone_number':
          profile?['phone_number'],
      'body_number':
          profile?['body_number'],
      'created_at':
          row['created_at'],
    });
  }

  return users;
}
  // ============================================================
  // DRIVER STATUS
  // ============================================================

  Future<void> _updateDriverStatus(
    String userId,
    String status,
  ) async {
    try {
      final updated = await _supabase
          .from('driver_profiles')
          .update({
            'verification_status': status,
            'is_active': status == 'approved',
          })
          .eq('id', userId)
          .select('id');

      if (updated.isEmpty) {
        throw Exception(
          'Driver profile was not found.',
        );
      }

      final approved =
          status == 'approved';

      try {
        await NotificationService.sendPush(
          userId: userId,
          title: approved
              ? 'Account Approved'
              : 'Account Rejected',
          message: approved
              ? 'Your RTODA driver account has been approved. You can now access the driver app.'
              : 'Your RTODA driver registration has been rejected. Please contact RTODA support for details.',
          type: approved
              ? 'account_approved'
              : 'account_rejected',
        );
      } catch (e) {
        debugPrint(
          'Driver notification error: $e',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Driver approved successfully.'
                : 'Driver rejected successfully.',
          ),
          backgroundColor:
              approved
                  ? Colors.green
                  : Colors.red,
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Unable to update driver: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // APPROVE DRIVER
  // ============================================================

  Future<void> _approveDriver(
    String userId,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: const Text(
            'Approve Driver',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Approve this driver and allow access to the driver app?',
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
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              icon: const Icon(
                Icons.check_rounded,
              ),
              label:
                  const Text('Approve'),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.green,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateDriverStatus(
        userId,
        'approved',
      );
    }
  }

  // ============================================================
  // REJECT DRIVER
  // ============================================================

  Future<void> _rejectDriver(
    String userId,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: const Text(
            'Reject Driver',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Reject this driver registration?',
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
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              icon: const Icon(
                Icons.close_rounded,
              ),
              label:
                  const Text('Reject'),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _updateDriverStatus(
        userId,
        'rejected',
      );
    }
  }

  // ============================================================
  // REMOVE USER ROLE
  // ============================================================

  Future<void> _removeUser(
    String userId,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: const Text(
            'Remove User',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Remove this user from the RTODA user management list? '
            'This removes the role record only and does not delete the Supabase Auth account.',
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
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              icon: const Icon(
                Icons.delete_outline_rounded,
              ),
              label:
                  const Text('Remove'),
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    Colors.red,
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final deleted = await _supabase
          .from('user_roles')
          .delete()
          .eq('id', userId)
          .select('id');

      if (deleted.isEmpty) {
        throw Exception(
          'User role was not found.',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'User removed successfully.',
          ),
          backgroundColor:
              Colors.green,
        ),
      );

      setState(() {});
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Unable to remove user: $e'),
          backgroundColor:
              Colors.red,
        ),
      );
    }
  }

  // ============================================================
  // USER DETAILS
  // ============================================================

  void _showUserDetails(
    Map<String, dynamic> user,
  ) {
    final id =
        '${user['user_id'] ?? ''}';

    final name =
        '${user['full_name'] ?? ''}';

    final email =
        '${user['email'] ?? ''}';

    final role =
        '${user['role'] ?? ''}';

    final phone =
        '${user['phone_number'] ?? ''}';

    final body =
        '${user['body_number'] ?? ''}';

    final status =
        '${user['status'] ?? ''}';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.account_circle_rounded,
                color:
                    Color(0xff087A45),
                size: 30,
              ),
              SizedBox(width: 10),
              Text(
                'User Details',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 470,
            child:
                SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  _detailRow(
                    'Name',
                    name.isEmpty
                        ? 'Name not available'
                        : name,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  _detailRow(
                    'Email',
                    email.isEmpty
                        ? 'Email unavailable'
                        : email,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  _detailRow(
                    'Role',
                    role.toUpperCase(),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  _detailRow(
                    'Verification Status',
                    _statusLabel(status),
                  ),
                  if (role ==
                          'driver' &&
                      body.isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),
                    _detailRow(
                      'Body Number',
                      body,
                    ),
                  ],
                  if (phone.isNotEmpty) ...[
                    const SizedBox(
                      height: 10,
                    ),
                    _detailRow(
                      'Phone Number',
                      phone,
                    ),
                  ],
                  const SizedBox(
                    height: 10,
                  ),
                  _detailRow(
                    'Account ID',
                    id,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            Colors.grey.shade50,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color:
                  Colors.grey.shade600,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          SelectableText(
            value,
            style:
                const TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String _statusLabel(
    String status,
  ) {
    switch (status) {
      case 'email_verified':
        return 'EMAIL VERIFIED';

      case 'email_not_verified':
        return 'EMAIL NOT VERIFIED';

      case 'pending':
        return 'PENDING APPROVAL';

      case 'approved':
        return 'APPROVED';

      case 'rejected':
        return 'REJECTED';

      default:
        return status.toUpperCase();
    }
  }

  // ============================================================
  // STATUS CHIP
  // ============================================================

  Widget _statusChip(
    String status,
  ) {
    Color background;
    Color foreground;
    IconData icon;

    switch (status) {
      case 'email_verified':
        background =
            Colors.green.shade50;
        foreground =
            Colors.green.shade800;
        icon =
            Icons.mark_email_read_rounded;
        break;

      case 'email_not_verified':
        background =
            Colors.orange.shade50;
        foreground =
            Colors.orange.shade800;
        icon =
            Icons.mark_email_unread_rounded;
        break;

      case 'approved':
        background =
            Colors.green.shade50;
        foreground =
            Colors.green.shade800;
        icon =
            Icons.check_circle_rounded;
        break;

      case 'rejected':
        background =
            Colors.red.shade50;
        foreground =
            Colors.red.shade800;
        icon =
            Icons.cancel_rounded;
        break;

      default:
        background =
            Colors.orange.shade50;
        foreground =
            Colors.orange.shade800;
        icon =
            Icons.pending_actions_rounded;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: foreground,
          ),
          const SizedBox(
            width: 6,
          ),
          Text(
            _statusLabel(status),
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ROLE CHIP
  // ============================================================

  Widget _roleChip(
    String role,
  ) {
    final isDriver =
        role == 'driver';

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isDriver
            ? Colors.purple.shade50
            : Colors.blue.shade50,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: isDriver
              ? Colors.purple.shade100
              : Colors.blue.shade100,
        ),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            isDriver
                ? Icons.drive_eta_rounded
                : Icons.person_outline_rounded,
            size: 14,
            color: isDriver
                ? Colors.purple.shade700
                : Colors.blue.shade700,
          ),
          const SizedBox(
            width: 5,
          ),
          Text(
            role.toUpperCase(),
            style: TextStyle(
              color: isDriver
                  ? Colors.purple.shade700
                  : Colors.blue.shade700,
              fontSize: 10,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Widget _actions(
    Map<String, dynamic> user,
  ) {
    final id =
        '${user['user_id'] ?? ''}';

    final role =
        '${user['role'] ?? ''}'
            .toLowerCase();

    final status =
        '${user['status'] ?? ''}'
            .toLowerCase();

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'View details',
          onPressed: () =>
              _showUserDetails(user),
          icon: const Icon(
            Icons.visibility_outlined,
            size: 20,
            color: Colors.blue,
          ),
        ),

        if (role == 'driver' &&
            status != 'approved')
          IconButton(
            tooltip:
                'Approve driver',
            onPressed: () =>
                _approveDriver(id),
            icon: const Icon(
              Icons
                  .check_circle_outline_rounded,
              size: 20,
              color: Colors.green,
            ),
          ),

        if (role == 'driver' &&
            status != 'rejected')
          IconButton(
            tooltip:
                'Reject driver',
            onPressed: () =>
                _rejectDriver(id),
            icon: const Icon(
              Icons.cancel_outlined,
              size: 20,
              color: Colors.red,
            ),
          ),

        IconButton(
          tooltip: 'Remove role',
          onPressed: () =>
              _removeUser(id),
          icon: const Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: Colors.red,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: 245,
      child: Container(
        padding:
            const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(18),
          border: Border.all(
            color:
                Colors.grey.shade100,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(
                .035,
              ),
              blurRadius: 12,
              offset:
                  const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                color:
                    color.withOpacity(.10),
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(
              width: 13,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    value,
                    style:
                        const TextStyle(
                      fontSize: 23,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      color:
          const Color(0xffF6F8F5),
      padding:
          const EdgeInsets.all(24),
      child:
          StreamBuilder<
              List<Map<String, dynamic>>>(
        stream: _supabase
            .from('user_roles')
            .stream(
              primaryKey: ['id'],
            )
            .order(
              'created_at',
              ascending: false,
            ),
        builder:
            (context, roleSnapshot) {
          if (roleSnapshot
                  .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(
                color: Colors.green,
              ),
            );
          }

          if (roleSnapshot
              .hasError) {
            return _errorView(
              '${roleSnapshot.error}',
            );
          }

          final roleRows =
              roleSnapshot.data ?? [];

          return FutureBuilder<
              List<Map<String, dynamic>>>(
            future:
                _buildUsers(roleRows),
            builder:
                (context, snapshot) {
              if (snapshot
                      .connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child:
                      CircularProgressIndicator(
                    color: Colors.green,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _errorView(
                  '${snapshot.error}',
                );
              }

              final users =
                  snapshot.data ?? [];

              final pending =
                  users.where(
                (u) =>
                    u['role'] ==
                        'driver' &&
                    u['status'] ==
                        'pending',
              ).length;

              final approved =
                  users.where(
                (u) =>
                    u['role'] ==
                        'driver' &&
                    u['status'] ==
                        'approved',
              ).length;

              final rejected =
                  users.where(
                (u) =>
                    u['role'] ==
                        'driver' &&
                    u['status'] ==
                        'rejected',
              ).length;

             final query = _searchQuery
    .toLowerCase()
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

final filtered = users.where((user) {
  // Get the FULL NAME directly from the profile data
  final fullName = (user['full_name'] ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ');

  final email = (user['email'] ?? '')
      .toString()
      .trim()
      .toLowerCase();

  final role = (user['role'] ?? '')
      .toString()
      .trim()
      .toLowerCase();

  final status = (user['status'] ?? '')
      .toString()
      .trim()
      .toLowerCase();

  final bodyNumber = (user['body_number'] ?? '')
      .toString()
      .trim()
      .toLowerCase();

  // Search using FULL NAME
  final matchesFullName =
      query.isEmpty ||
      fullName.contains(query);

  final matchesOtherFields =
      query.isEmpty ||
      email.contains(query) ||
      role.contains(query) ||
      status.contains(query) ||
      bodyNumber.contains(query);

  final matchesSearch =
      matchesFullName || matchesOtherFields;

  final matchesFilter =
      _statusFilter == 'All' ||
      status == _statusFilter.toLowerCase();

  return matchesSearch && matchesFilter;
}).toList();

              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  // ==================================================
                  // STATISTICS
                  // ==================================================

                  Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      _statCard(
                        title:
                            'Total Users',
                        value:
                            '${users.length}',
                        icon: Icons
                            .people_alt_outlined,
                        color:
                            Colors.blue,
                      ),
                      _statCard(
                        title:
                            'Driver Pending',
                        value:
                            '$pending',
                        icon: Icons
                            .pending_actions_rounded,
                        color:
                            Colors.orange,
                      ),
                      _statCard(
                        title:
                            'Driver Approved',
                        value:
                            '$approved',
                        icon: Icons
                            .check_circle_outline_rounded,
                        color:
                            Colors.green,
                      ),
                      _statCard(
                        title:
                            'Driver Rejected',
                        value:
                            '$rejected',
                        icon: Icons
                            .cancel_outlined,
                        color:
                            Colors.red,
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  // ==================================================
                  // SEARCH + FILTER
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.all(
                      10,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          Colors.white,
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                      border:
                          Border.all(
                        color:
                            Colors.grey.shade100,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child:
                              TextField(
                            onChanged:
                                (value) {
                              setState(
                                () {
                                  _searchQuery =
                                      value;
                                },
                              );
                            },
                            decoration:
                                InputDecoration(
                              hintText:
                                  'Search name, email, role, body number or status...',
                              prefixIcon:
                                  const Icon(
                                Icons
                                    .search_rounded,
                              ),
                              suffixIcon:
                                  _searchQuery
                                          .isNotEmpty
                                      ? IconButton(
                                          tooltip:
                                              'Clear',
                                          onPressed:
                                              () {
                                            setState(
                                              () {
                                                _searchQuery =
                                                    '';
                                              },
                                            );
                                          },
                                          icon:
                                              const Icon(
                                            Icons
                                                .close_rounded,
                                          ),
                                        )
                                      : null,
                              filled: true,
                              fillColor:
                                  const Color(
                                0xffF7F9F7,
                              ),
                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  12,
                                ),
                                borderSide:
                                    BorderSide.none,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Container(
                          height: 50,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 12,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xffF7F9F7,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                          ),
                          child:
                              DropdownButtonHideUnderline(
                            child:
                                DropdownButton<
                                    String>(
                              value:
                                  _statusFilter,
                              items: const [
                                DropdownMenuItem(
                                  value:
                                      'All',
                                  child:
                                      Text(
                                    'All Status',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value:
                                      'pending',
                                  child:
                                      Text(
                                    'Driver Pending',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value:
                                      'approved',
                                  child:
                                      Text(
                                    'Driver Approved',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value:
                                      'rejected',
                                  child:
                                      Text(
                                    'Driver Rejected',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value:
                                      'email_verified',
                                  child:
                                      Text(
                                    'Email Verified',
                                  ),
                                ),
                                DropdownMenuItem(
                                  value:
                                      'email_not_verified',
                                  child:
                                      Text(
                                    'Email Not Verified',
                                  ),
                                ),
                              ],
                              onChanged:
                                  (value) {
                                if (value ==
                                    null) {
                                  return;
                                }

                                setState(
                                  () {
                                    _statusFilter =
                                        value;
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(
                    height: 18,
                  ),

                  // ==================================================
                  // USER TABLE
                  // ==================================================

                  Expanded(
                    child: Container(
                      width:
                          double.infinity,
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,
                        borderRadius:
                            BorderRadius
                                .circular(
                          18,
                        ),
                        border:
                            Border.all(
                          color:
                              Colors.grey.shade100,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(
                              .03,
                            ),
                            blurRadius: 12,
                            offset:
                                const Offset(
                              0,
                              4,
                            ),
                          ),
                        ],
                      ),
                      child: filtered
                              .isEmpty
                          ? const Center(
                              child:
                                  Column(
                                mainAxisSize:
                                    MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons
                                        .people_outline_rounded,
                                    size: 58,
                                    color:
                                        Colors.grey,
                                  ),
                                  SizedBox(
                                    height:
                                        10,
                                  ),
                                  Text(
                                    'No users found',
                                    style:
                                        TextStyle(
                                      fontSize:
                                          16,
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                18,
                              ),
                              child:
                                  SingleChildScrollView(
                                scrollDirection:
                                    Axis.horizontal,
                                child:
                                    SingleChildScrollView(
                                  child:
                                      DataTable(
                                    headingRowHeight:
                                        54,
                                    dataRowMinHeight:
                                        64,
                                    dataRowMaxHeight:
                                        76,
                                    columnSpacing:
                                        28,
                                    horizontalMargin:
                                        20,
                                    headingRowColor:
                                        WidgetStateProperty
                                            .all(
                                      const Color(
                                        0xffF1F8F4,
                                      ),
                                    ),
                                    columns:
                                        const [
                                      DataColumn(
                                        label:
                                            Text(
                                          'NAME',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label:
                                            Text(
                                          'EMAIL',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label:
                                            Text(
                                          'ROLE',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label:
                                            Text(
                                          'VERIFICATION STATUS',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label:
                                            Text(
                                          'BODY NUMBER',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label:
                                            Text(
                                          'ACTIONS',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows:
                                        filtered.map(
                                      (user) {
                                        final name =
                                            '${user['full_name'] ?? ''}';

                                        final email =
                                            '${user['email'] ?? ''}';

                                        final role =
                                            '${user['role'] ?? ''}';

                                        final status =
                                            '${user['status'] ?? ''}';

                                        final body =
                                            '${user['body_number'] ?? ''}';

                                        return DataRow(
                                          cells: [
                                            // NAME
                                            DataCell(
                                              SizedBox(
                                                width:
                                                    210,
                                                child:
                                                    Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius:
                                                          18,
                                                      backgroundColor:
                                                          Colors.green.shade50,
                                                      child:
                                                          Icon(
                                                        role == 'driver'
                                                            ? Icons.drive_eta_rounded
                                                            : Icons.person_outline_rounded,
                                                        size:
                                                            18,
                                                        color:
                                                            Colors.green.shade700,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width:
                                                          10,
                                                    ),
                                                    Expanded(
                                                      child:
                                                          Text(
                                                        name.isEmpty
                                                            ? 'Name not available'
                                                            : name,
                                                        maxLines:
                                                            2,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize:
                                                              13,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),

                                            // EMAIL
                                            DataCell(
                                              SizedBox(
                                                width:
                                                    220,
                                                child:
                                                    Text(
                                                  email.isEmpty
                                                      ? 'Email unavailable'
                                                      : email,
                                                  maxLines:
                                                      1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style:
                                                      TextStyle(
                                                    fontSize:
                                                        12,
                                                    color: email.isEmpty
                                                        ? Colors.grey.shade500
                                                        : Colors.grey.shade800,
                                                  ),
                                                ),
                                              ),
                                            ),

                                            // ROLE
                                            DataCell(
                                              _roleChip(
                                                role,
                                              ),
                                            ),

                                            // VERIFICATION
                                            DataCell(
                                              _statusChip(
                                                status,
                                              ),
                                            ),

                                            // BODY NUMBER
                                            DataCell(
                                              Text(
                                                role == 'driver' &&
                                                        body.isNotEmpty
                                                    ? body
                                                    : '—',
                                                style:
                                                    const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),

                                            // ACTIONS
                                            DataCell(
                                              _actions(
                                                user,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ).toList(),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Showing ${filtered.length} of ${users.length} users',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR VIEW
  // ============================================================

  Widget _errorView(
    String error,
  ) {
    return Center(
      child: Container(
        padding:
            const EdgeInsets.all(24),
        constraints:
            const BoxConstraints(
          maxWidth: 520,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Colors.red,
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Unable to load users',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              error,
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}