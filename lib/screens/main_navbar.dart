import 'package:flutter/material.dart';
import 'view_lost_items.dart';
import 'report_lost_items.dart'; // We'll convert this to a tab body soon
import 'my_claims_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_panel.dart'; // Profile screen
import 'notifications_screen.dart'; // Placeholder
import 'package:lost_found_app/state/app_role.dart';
import 'package:lost_found_app/services/notification_service.dart';

class MainNavbar extends StatefulWidget {
  const MainNavbar({super.key});

  @override
  State<MainNavbar> createState() => _MainNavbarState();
}

class _MainNavbarState extends State<MainNavbar> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: AppRole.role,
      builder: (context, role, _) {
        if (role == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final bool isAdmin = AppRole.isAdmin;
        final List<Widget> screens = [
          const ViewLostItems(),
          const ReportLostItem(),
          isAdmin ? const AdminDashboardScreen() : const MyClaimsScreen(),
          const NotificationsScreen(),
          const AdminPanel(),
        ];

        if (_currentIndex >= screens.length) _currentIndex = 0;

        return Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: StreamBuilder<int>(
            stream: NotificationService.unreadCountStream(),
            builder: (context, unreadSnap) {
              final unreadCount = unreadSnap.data ?? 0;

              final List<NavigationDestination> destinations = [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.add_circle_outline),
                  selectedIcon: Icon(Icons.add_circle),
                  label: 'Report',
                ),
                NavigationDestination(
                  icon: Icon(isAdmin ? Icons.dashboard_outlined : Icons.inbox_outlined),
                  selectedIcon: Icon(isAdmin ? Icons.dashboard : Icons.inbox),
                  label: isAdmin ? 'Dashboard' : 'My Claims',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: unreadCount > 0,
                    label: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.notifications),
                  ),
                  label: 'Alerts',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ];

              return NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                destinations: destinations,
              );
            },
          ),
        );
      },
    );
  }
}
