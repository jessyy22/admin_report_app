import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_dashboard.dart';
import 'complaints.dart';
import 'drivers.dart';
import 'operators.dart';
import 'tricycles.dart';
import 'fare_matrix.dart';
import 'user_session.dart';
import 'user_management.dart';
import 'notification.dart';
import 'services/fcm_service.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() =>
      _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  // ==========================================================
  // STATE
  // ==========================================================

  int _selectedIndex = 0;

  // Screenshot uses collapsed sidebar
  bool _sidebarExpanded = false;

  // ==========================================================
  // CONSTANTS
  // ==========================================================

  static const Color sidebarColor =
      Color(0xff005C2A);

  static const Color selectedColor =
      Color(0xff079447);

  static const Color primaryGreen =
      Color(0xff006B32);

  static const Color pageBackground =
      Color(0xffF5F7F6);

  // Screenshot proportions
  static const double expandedSidebarWidth = 225;
  static const double collapsedSidebarWidth = 82;
  static const double topBarHeight = 80;

  // ==========================================================
  // PAGE PANELS
  // ==========================================================

  final List<Widget> _panels = const [
    DashboardPanel(),
    ComplaintListPage(),
    DriversListScreen(),
    OperatorsListScreen(),
    TricyclesListScreen(),
    AdminFareMatrixScreen(),
    UserManagementScreen(),
  ];

  // ==========================================================
  // PAGE TITLES
  // ==========================================================

  final List<String> _titles = const [
    'RTODA Admin Dashboard',
    'Complaints',
    'Drivers',
    'Operators',
    'Tricycles',
    'Fare Rates',
    'User Management',
  ];

  // ==========================================================
  // SIDEBAR ICONS
  // ==========================================================

  final List<IconData> _icons = const [
    Icons.dashboard_rounded,
    Icons.article_rounded,
    Icons.people_alt_rounded,
    Icons.badge_rounded,
    Icons.electric_rickshaw_rounded,
    Icons.price_change_rounded,
    Icons.manage_accounts_rounded,
  ];

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await FcmService().initialize();
    });
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();

      UserSession.clear();

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/login',
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logout error: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================================
  // SELECT PAGE
  // ==========================================================

  void _selectPage(int index) {
    if (index < 0 || index >= _panels.length) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  // ==========================================================
  // TOGGLE SIDEBAR
  // ==========================================================

  void _toggleSidebar() {
    setState(() {
      _sidebarExpanded = !_sidebarExpanded;
    });
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,

      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ======================================================
          // SIDEBAR
          // ======================================================

          _buildSidebar(),

          // ======================================================
          // RIGHT SIDE
          // ======================================================

          Expanded(
            child: Column(
              children: [
                // ==================================================
                // TOP BAR
                // ==================================================

                _buildTopBar(),

                // ==================================================
                // PAGE CONTENT
                // ==================================================

                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: pageBackground,

                    child: IndexedStack(
                      index: _selectedIndex,
                      children: _panels,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SIDEBAR
  // ==========================================================

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 220),

      curve: Curves.easeInOut,

      width: _sidebarExpanded
          ? expandedSidebarWidth
          : collapsedSidebarWidth,

      color: sidebarColor,

      child: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // LOGO
            // ==================================================

            _buildLogo(),

            const SizedBox(height: 8),

            // ==================================================
            // NAVIGATION
            // ==================================================

            Expanded(
              child: ListView.builder(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                ),

                itemCount: _titles.length,

                itemBuilder:
                    (context, index) {
                  return _buildNavigationItem(
                    index,
                  );
                },
              ),
            ),

            // ==================================================
            // LOGOUT
            // ==================================================

            _buildLogout(),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // LOGO
  // ==========================================================

  Widget _buildLogo() {
    return SizedBox(
      height: 72,

      width: double.infinity,

      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              _sidebarExpanded ? 18 : 10,
        ),

        child: Row(
          children: [
            // Logo box
            Container(
              width: 52,
              height: 52,

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(13),
              ),

              child: const Icon(
                Icons.electric_rickshaw_rounded,

                color: sidebarColor,

                size: 30,
              ),
            ),

            // ==================================================
            // EXPANDED LOGO TEXT
            // ==================================================

            if (_sidebarExpanded) ...[
              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      'RTODA',

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 25,

                        fontWeight:
                            FontWeight.bold,

                        letterSpacing: 1,
                      ),
                    ),

                    SizedBox(height: 2),

                    Text(
                      'Tricycle Operator and Drivers Report App',

                      maxLines: 2,

                      overflow:
                          TextOverflow.ellipsis,

                      style: TextStyle(
                        color: Colors.white70,

                        fontSize: 10,

                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // NAVIGATION ITEM
  // ==========================================================

  Widget _buildNavigationItem(
    int index,
  ) {
    final bool selected =
        _selectedIndex == index;

    final String title =
        _titles[index] ==
                'RTODA Admin Dashboard'
            ? 'Dashboard'
            : _titles[index];

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 6),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius:
              BorderRadius.circular(9),

          onTap: () {
            _selectPage(index);
          },

          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),

            height: 54,

            padding: EdgeInsets.symmetric(
              horizontal:
                  _sidebarExpanded ? 12 : 0,
            ),

            decoration: BoxDecoration(
              color: selected
                  ? selectedColor
                  : Colors.transparent,

              borderRadius:
                  BorderRadius.circular(9),
            ),

            child: Row(
              mainAxisAlignment:
                  _sidebarExpanded
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,

              children: [
                // =================================================
                // ICON
                // =================================================

                Icon(
                  _icons[index],

                  color: Colors.white,

                  size: 22,
                ),

                // =================================================
                // TITLE
                // =================================================

                if (_sidebarExpanded) ...[
                  const SizedBox(width: 13),

                  Expanded(
                    child: Text(
                      title,

                      maxLines: 1,

                      overflow:
                          TextOverflow.ellipsis,

                      style: TextStyle(
                        color: Colors.white,

                        fontSize: 20,

                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Widget _buildLogout() {
    return Column(
      children: [
        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            5,
            18,
            10,
          ),

          child: Divider(
            color:
                Colors.white.withOpacity(.25),
          ),
        ),

        Padding(
          padding:
              const EdgeInsets.fromLTRB(
            10,
            0,
            10,
            18,
          ),

          child: Material(
            color: Colors.transparent,

            child: InkWell(
              borderRadius:
                  BorderRadius.circular(9),

              onTap: _logout,

              child: Container(
                height: 50,

                padding:
                    EdgeInsets.symmetric(
                  horizontal:
                      _sidebarExpanded
                          ? 12
                          : 0,
                ),

                child: Row(
                  mainAxisAlignment:
                      _sidebarExpanded
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,

                  children: [
                    const Icon(
                      Icons.logout_rounded,

                      color: Colors.white,

                      size: 22,
                    ),

                    if (_sidebarExpanded) ...[
                      const SizedBox(width: 13),

                      const Text(
                        'Logout',

                        style: TextStyle(
                          color: Colors.white,

                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // TOP BAR
  // ==========================================================

  Widget _buildTopBar() {
    return Container(
      height: topBarHeight,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
      ),

      decoration: const BoxDecoration(
        color: Colors.white,

        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),

            blurRadius: 8,

            offset:
                Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        children: [
          // ====================================================
          // MENU BUTTON
          // ====================================================

          SizedBox(
            width: 40,
            height: 40,

            child: IconButton(
              tooltip:
                  'Toggle Sidebar',

              padding:
                  EdgeInsets.zero,

              onPressed:
                  _toggleSidebar,

              icon: const Icon(
                Icons.menu_rounded,

                color:
                    Color(0xff333333),

                size: 25,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // ====================================================
          // PAGE TITLE
          // ====================================================

          Expanded(
            child: Text(
              _getPageTitle(),

              style:
                  const TextStyle(
                fontSize: 20,

                fontWeight:
                    FontWeight.bold,

                color:
                    Color(0xff202124),
              ),
            ),
          ),

          // ====================================================
          // NOTIFICATION
          // ====================================================

          const NotificationBell(),

          const SizedBox(width: 18),

          // ====================================================
          // ADMIN PROFILE
          // ====================================================

          _buildAdminProfile(),
        ],
      ),
    );
  }

  // ==========================================================
  // PAGE TITLE
  // ==========================================================

  String _getPageTitle() {
    if (_selectedIndex < 0 ||
        _selectedIndex >= _titles.length) {
      return 'RTODA Admin Dashboard';
    }

    return _titles[_selectedIndex];
  }

  // ==========================================================
  // ADMIN PROFILE
  // ==========================================================

  Widget _buildAdminProfile() {
    return PopupMenuButton<String>(
      tooltip: 'Admin Menu',

      offset:
          const Offset(0, 55),

      onSelected: (value) {
        if (value == 'logout') {
          _logout();
        }
      },

      itemBuilder:
          (context) => const [
        PopupMenuItem<String>(
          value: 'logout',

          child: Row(
            children: [
              Icon(
                Icons.logout,
                color: Colors.red,
                size: 20,
              ),

              SizedBox(width: 10),

              Text('Logout'),
            ],
          ),
        ),
      ],

      child: Row(
        children: [
          // ==================================================
          // PROFILE CIRCLE
          // ==================================================

          Container(
            width: 42,
            height: 42,

            decoration:
                const BoxDecoration(
              color: primaryGreen,

              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.person,

              color: Colors.white,

              size: 25,
            ),
          ),

          const SizedBox(width: 9),

          // ==================================================
          // ADMIN INFORMATION
          // ==================================================

          const Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Text(
                'Admin',

                style: TextStyle(
                  fontSize: 13,

                  fontWeight:
                      FontWeight.bold,

                  color:
                      Color(0xff222222),
                ),
              ),

              SizedBox(height: 1),

              Text(
                'Super Administrator',

                style: TextStyle(
                  fontSize: 9,

                  color: Colors.grey,
                ),
              ),
            ],
          ),

          const SizedBox(width: 7),

          const Icon(
            Icons.keyboard_arrow_down_rounded,

            size: 20,
          ),
        ],
      ),
    );
  }
}