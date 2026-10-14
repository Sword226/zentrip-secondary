import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/chatbot/presentation/screens/chatbot_screen.dart';
import '../features/nearby/presentation/screens/nearby_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/trips/presentation/screens/my_trips_screen.dart';
import '../l10n/app_localizations.dart';
import 'offline_banner.dart';

/// بيسمح لأي شاشة جوه الـ IndexedStack (زي HomeScreen) إنها "تنادي" على
/// AppShell وتخليه يبدّل التاب — من غير ما تعمل Navigator.push لصفحة جديدة
/// (لأن AppShell أصلاً هي الشاشة الحالية، وبس بنبدّل مين اللي ظاهر جواها).
class AppShellTabController {
  static final ValueNotifier<int?> pendingIndex = ValueNotifier<int?>(null);

  static void goToChatbot() => pendingIndex.value = 2;
  static void goToTab(int index) => pendingIndex.value = index;
}

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  late int _selectedIndex;
  late final AnimationController _animController;

  final List<Widget> _screens = const [
    HomeScreen(),
    NearbyScreen(),
    ChatbotScreen(),
    MyTripsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex =
        AppShellTabController.pendingIndex.value ?? widget.initialIndex;
    AppShellTabController.pendingIndex.value = null;
    AppShellTabController.pendingIndex.addListener(_onPendingIndexChanged);
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _animController.forward();
  }

  void _onPendingIndexChanged() {
    final target = AppShellTabController.pendingIndex.value;
    if (target != null) {
      _onItemTapped(target);
      AppShellTabController.pendingIndex.value = null;
    }
  }

  @override
  void dispose() {
    AppShellTabController.pendingIndex.removeListener(_onPendingIndexChanged);
    _animController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    _animController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: OfflineBanner()),
          Expanded(
            child: AnimatedBuilder(
              animation: _animController,
              builder: (_, __) => FadeTransition(
                opacity: _animController,
                child: IndexedStack(index: _selectedIndex, children: _screens),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: navBg,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BottomNavigationBar(
                currentIndex: _selectedIndex,
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                backgroundColor: navBg,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                selectedFontSize: 10,
                unselectedFontSize: 10,
                selectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w700),
                elevation: 0,
                items: [
                  _navItem(Icons.explore_outlined, Icons.explore_rounded,
                      l10n.navHome, 0),
                  _navItem(Icons.place_outlined, Icons.place_rounded,
                      l10n.navNearby, 1),
                  _navItem(Icons.auto_awesome_outlined,
                      Icons.auto_awesome_rounded, l10n.navChatbot, 2),
                  _navItem(Icons.card_travel_outlined,
                      Icons.card_travel_rounded, l10n.navTrips, 3),
                  _navItem(Icons.person_outline_rounded, Icons.person_rounded,
                      l10n.navProfile, 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(
      IconData outlined, IconData filled, String label, int index) {
    final isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      label: label,
      icon: Icon(outlined),
      activeIcon: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(filled, color: AppColors.primary),
      ),
    );
  }
}
