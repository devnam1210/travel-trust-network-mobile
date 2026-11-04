import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/auth_controller.dart';
import '../models/user_model.dart';
import 'places/explore_screen.dart';
import 'profile_screen.dart';
import 'visits/visit_history_screen.dart';
import 'locket/locket_feed_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Luôn theo dõi state user mới nhất từ authControllerProvider
    final currentUser =
        ref.watch(authControllerProvider).user ?? widget.user;

    final pages = [
      const ExploreScreen(),
      const VisitHistoryScreen(),
      const LocketFeedScreen(),
      ProfileScreen(user: currentUser),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_travel_outlined),
            selectedIcon: Icon(Icons.card_travel_rounded),
            label: 'Chuyến đi',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_outlined),
            selectedIcon: Icon(Icons.photo_rounded),
            label: 'Locket',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Cá nhân',
          ),
        ],
      ),
    );
  }
}
