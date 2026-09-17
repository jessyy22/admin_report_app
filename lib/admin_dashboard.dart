import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_session.dart';
import 'reports_view.dart';

class DashboardPanel extends StatelessWidget {
  const DashboardPanel({super.key});

  static const Color primaryGreen = Color(0xff005C2A);
  static const Color dashboardGreen = Color(0xff079447);
  static const Color backgroundColor = Color(0xffF4F6F8);
  static const Color cardColor = Colors.white;
  static const Color textDark = Color(0xff1E293B);
  static const Color textMuted = Color(0xff64748B);
  static const Color borderSubtle = Color(0xffE2E8F0);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client
          .from('reports')
          .stream(primaryKey: ['report_id'])
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: dashboardGreen,
              strokeWidth: 3,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load reports',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data ?? [];

        return Container(
          color: backgroundColor,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                _buildSectionHeader(
                  title: 'System Overview',
                  subtitle: 'Current RTODA operational statistics',
                ),
                const SizedBox(height: 16),
                _buildStatsGrid(data),
                const SizedBox(height: 18),
                _buildSectionHeader(
                  title: 'Quick Analytics',
                  subtitle: 'Monitor system activity metrics at a glance',
                ),
                const SizedBox(height: 16),
                _buildQuickOverview(data),
                const SizedBox(height: 18),
                _buildSectionHeader(
                  title: 'Recent Reports',
                  subtitle: 'Latest issues submitted to the platform',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: dashboardGreen.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${data.length} total',
                      style: const TextStyle(
                        color: dashboardGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildRecentReports(data, context),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================================================
  // SECTION HEADER HELPER
  // ========================================================================

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
     crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: textMuted,
              ),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  

  // ========================================================================
  // STATISTICS GRID
  // ========================================================================
Widget _buildStatsGrid(List<Map<String, dynamic>> reports) {
  final pendingCount = reports
      .where((r) => r['status'].toString().toLowerCase() == 'pending')
      .length;

  final resolvedCount = reports
      .where((r) => r['status'].toString().toLowerCase() == 'resolved')
      .length;

  return LayoutBuilder(
    builder: (context, constraints) {
      int columns;

      if (constraints.maxWidth >= 1100) {
        // Desktop: all 6 cards in ONE ROW
        columns = 6;
      } else if (constraints.maxWidth >= 750) {
        // Tablet
        columns = 3;
      } else {
        // Mobile
        columns = 2;
      }

      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: columns == 6
            ? 1.8
            : columns == 3
                ? 2.0
                : 1.8,
        children: [
          _statCard(
            'Total Drivers',
            _fetchCount('drivers'),
            Icons.people_alt_rounded,
            const Color(0xff2563EB),
            const Color(0xffEFF6FF),
          ),

          _statCard(
            'Total Operators',
            _fetchCount('operators'),
            Icons.badge_rounded,
            const Color(0xff9333EA),
            const Color(0xffF3E8FF),
          ),

          _statCard(
            'Total Tricycles',
            _fetchCount('tricycles'),
            Icons.electric_rickshaw_rounded,
            dashboardGreen,
            const Color(0xffF0FDF4),
          ),

          _statCardValue(
            'Total Reports',
            reports.length.toString(),
            Icons.analytics_rounded,
            const Color(0xff475569),
            const Color(0xffF8FAFC),
          ),

          _statCardValue(
            'Pending Reports',
            pendingCount.toString(),
            Icons.pending_actions_rounded,
            const Color(0xffD97706),
            const Color(0xffFFFBEB),
          ),

          _statCardValue(
            'Resolved Reports',
            resolvedCount.toString(),
            Icons.check_circle_rounded,
            const Color(0xff16A34A),
            const Color(0xffF0FDF4),
          ),
        ],
      );
    },
  );
}

  Widget _statCard(
    String title,
    Future<int> futureCount,
    IconData icon,
    Color color,
    Color background,
  ) {
    return FutureBuilder<int>(
      future: futureCount,
      builder: (context, snapshot) {
        final value = snapshot.connectionState == ConnectionState.waiting
            ? '...'
            : (snapshot.data?.toString() ?? '0');
        return _statCardValue(title, value, icon, color, background);
      },
    );
  }

  Widget _statCardValue(
    String title,
    String value,
    IconData icon,
    Color color,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // FETCH TABLE COUNT
  // ========================================================================

  Future<int> _fetchCount(String table) async {
    try {
      final response = await Supabase.instance.client.from(table).select();
      return response.length;
    } catch (_) {
      return 0;
    }
  }

  // ========================================================================
  // QUICK OVERVIEW
  // ========================================================================

  Widget _buildQuickOverview(List<Map<String, dynamic>> data) {
    final pendingCount = data
        .where((r) => r['status'].toString().toLowerCase() == 'pending')
        .length;

    final resolvedCount = data
        .where((r) => r['status'].toString().toLowerCase() == 'resolved')
        .length;

    final total = data.length;
    final pendingPercent = total == 0 ? 0.0 : pendingCount / total;
    final resolvedPercent = total == 0 ? 0.0 : resolvedCount / total;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;

        final cards = [
          _overviewCard(
            'Pending Resolution',
            pendingCount,
            pendingPercent,
            Icons.pending_actions_rounded,
            const Color(0xffD97706),
            const Color(0xffFFFBEB),
          ),
          _overviewCard(
            'Successfully Resolved',
            resolvedCount,
            resolvedPercent,
            Icons.check_circle_rounded,
            const Color(0xff16A34A),
            const Color(0xffF0FDF4),
          ),
        ];

        if (isMobile) {
          return Column(
            children: [
              cards[0],
              const SizedBox(height: 16),
              cards[1],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 16),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _overviewCard(
    String title,
    int count,
    double percentage,
    IconData icon,
    Color color,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: textDark,
                  ),
                ),
              ),
              Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 6,
              backgroundColor: background,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(percentage * 100).toStringAsFixed(1)}% of total complaints',
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$count total',
                style: const TextStyle(
                  color: textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // RECENT REPORTS
  // ========================================================================

  Widget _buildRecentReports(
    List<Map<String, dynamic>> data,
    BuildContext context,
  ) {
    if (data.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderSubtle),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              color: textMuted,
              size: 48,
            ),
            SizedBox(height: 12),
            Text(
              'No reports found',
              style: TextStyle(
                color: textDark,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Submitted report logs will appear here.',
              style: TextStyle(color: textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final recentReports = data.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < recentReports.length; i++)
            _buildReportItem(
              recentReports[i],
              context,
              i == recentReports.length - 1,
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // REPORT ITEM
  // ========================================================================

  Widget _buildReportItem(
    Map<String, dynamic> item,
    BuildContext context,
    bool isLast,
  ) {
    final status = (item['status'] ?? 'Pending').toString();
    final isPending = status.toLowerCase() == 'pending';

    final statusBg = isPending ? const Color(0xffFFFBEB) : const Color(0xffF0FDF4);
    final statusFg = isPending ? const Color(0xffD97706) : const Color(0xff16A34A);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        onTap: () {
          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) {
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                insetPadding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 700,
                  height: 700,
                  child: ComplaintReviewPage(
                    documentId: item['report_id'].toString(),
                    complaintData: item,
                  ),
                ),
              );
            },
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: borderSubtle),
                  ),
          ),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPending
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: statusFg,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['violation'] ?? 'Unknown Violation',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: textMuted,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            item['location'] ?? 'Location unmapped',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (item['created_at'] != null) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.access_time_rounded,
                            size: 13,
                            color: textMuted,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatDate(item['created_at'].toString()),
                            style: const TextStyle(
                              color: textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusFg.withOpacity(0.3)),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusFg,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (UserSession.role == 'admin')
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                  tooltip: 'Delete report',
                  onPressed: () {
                    final reportId = int.tryParse(item['report_id'].toString());
                    if (reportId != null) {
                      _confirmDelete(context, reportId);
                    }
                  },
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: textMuted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // DATE FORMAT
  // ========================================================================

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();
      return '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value;
    }
  }

  // ========================================================================
  // DELETE REPORT
  // ========================================================================

  Future<void> _confirmDelete(BuildContext context, int reportId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Report'),
          content: const Text('Are you sure you want to delete this record permanently?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('reports')
            .delete()
            .eq('report_id', reportId);

        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted successfully.')),
        );
      } catch (e) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete report: $e')),
        );
      }
    }
  }
}