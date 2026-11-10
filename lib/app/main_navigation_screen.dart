import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/user_model.dart';
import '../features/places/explore_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/visits/visit_history_screen.dart';
import '../features/locket/locket_feed_screen.dart';
import '../features/messages/inbox_screen.dart';
import '../features/messages/unread_message_badge.dart';
import '../shared/motion/app_motion.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key, required this.user});

  final UserModel user;

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _messagesVisited = false;
  late final _tabController = AnimationController(
    vsync: this,
    duration: AppMotion.feedback,
    value: 1,
  );
  late final _tabOffset = _tabController
      .drive(CurveTween(curve: AppMotion.curve))
      .drive(Tween(begin: const Offset(0, 0.012), end: Offset.zero));

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Luôn theo dõi state user mới nhất từ authControllerProvider
    final currentUser = ref.watch(authControllerProvider).user ?? widget.user;

    final pages = [
      const ExploreScreen(),
      const VisitHistoryScreen(),
      const LocketFeedScreen(),
      _messagesVisited
          ? InboxScreen(isActive: _currentIndex == 3)
          : const SizedBox.shrink(),
      ProfileScreen(user: currentUser),
    ];

    return Scaffold(
      body: SlideTransition(
        position: _tabOffset,
        child: IndexedStack(
          index: _currentIndex,
          children: [
            for (var i = 0; i < pages.length; i++)
              TickerMode(enabled: i == _currentIndex, child: pages[i]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == _currentIndex) return;
          setState(() {
            _currentIndex = index;
            if (index == 3) _messagesVisited = true;
          });
          if (AppMotion.reduced(context)) {
            _tabController.value = 1;
          } else {
            _tabController.forward(from: 0);
          }
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
            icon: MessageNavigationIcon(),
            selectedIcon: MessageNavigationIcon(selected: true),
            label: 'Tin nhắn',
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
