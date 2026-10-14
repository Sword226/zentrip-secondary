import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../global_widgets/app_shell.dart';
import '../../../../global_widgets/boarding_pass_card.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../models/attraction_model.dart';
import '../../../attractions/logic/attractions_controller.dart';
import '../../../attractions/presentation/attraction_category.dart';
import 'packages_list_screen.dart';
import '../../../../models/travel_package_model.dart';
import '../../../../features/favorites/logic/favorites_controller.dart';
import '../../../../features/notifications/logic/notifications_store.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/home_controller.dart';
import '../../../trips/presentation/screens/package_detail_screen.dart';
import '../../../trips/presentation/screens/trip_details_screen.dart';
import '../../../flight_booking/presentation/screens/flight_search_screen.dart';
import '../../../profile/presentation/screens/travel_preferences_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = HomeController();
  final _ideasController = PageController(viewportFraction: 0.88);
  Timer? _ideasTimer;
  int _activeIdea = 0;
  bool _notifChecksDone = false;
  List<AttractionModel> _monuments = [];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_startIdeasRotation);
    _ctrl.loadAll();
    _loadMonuments();
  }

  Future<void> _loadMonuments() async {
    final list = await AttractionsController.loadFeaturedMonuments();
    if (mounted) setState(() => _monuments = list);
  }

  void _openPackagesList(PackagesListKind kind) {
    Navigator.pushNamed(
      context,
      AppRoutes.packagesList,
      arguments: PackagesListArgs(kind: kind, packages: _ctrl.packages),
    );
  }

  void _startIdeasRotation() {
    if (_ideasTimer != null || _ctrl.packages.length < 2) return;
    _ideasTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !_ideasController.hasClients ||
          _ctrl.packages.length < 2) {
        return;
      }
      final next = (_activeIdea + 1) % _ctrl.packages.length;
      _ideasController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_notifChecksDone) {
      _notifChecksDone = true;
      _runNotificationChecks();
    }
  }

  /// بيتشيّك على عروض جديدة ورحلات قرّب ميعادها، ويولّد إشعارات حقيقية
  /// لهم — بيتنفّذ مرة واحدة بس في كل مرة الشاشة دي تتفتح.
  Future<void> _runNotificationChecks() async {
    final l10n = AppLocalizations.of(context);
    final offersResult = await ApiService.instance.getOffers();
    await NotificationsStore.instance.notifyNewOffers(offersResult.data ?? [],
        promoTitle: l10n.notifPromoTitle);

    final tripsResult = await ApiService.instance.getMyFlightTrips();
    await NotificationsStore.instance.checkTripReminders(tripsResult.data ?? [],
        reminderTitle: l10n.notifTripReminderTitle);
  }

  void _openPackage(TravelPackage package) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PackageDetailScreen(package: package)),
    );
  }

  @override
  void dispose() {
    _ctrl.removeListener(_startIdeasRotation);
    _ideasTimer?.cancel();
    _ideasController.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ApiService.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final featured =
        _ctrl.packages.where((package) => package.isFeatured).toList();
    final offers = featured.isEmpty ? _ctrl.packages : featured;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await Future.wait([_ctrl.loadAll(), _loadMonuments()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            child: ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GreetingHeader(
                    userName: user?.name.split(' ').first ?? '',
                    l10n: l10n,
                    isDark: isDark,
                  ).animate().fade(duration: 500.ms),
                  const SizedBox(height: 18),
                  _HomeSearchCard(
                    l10n: l10n,
                    isDark: isDark,
                    packages: _ctrl.packages,
                  ).animate().fade(delay: 80.ms).slideY(begin: 0.06, end: 0),
                  const SizedBox(height: 20),
                  _QuickActions(l10n: l10n).animate().fade(delay: 100.ms),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: l10n.homeNewIdeas,
                    actionLabel: l10n.viewAll,
                    onAction: () => _openPackagesList(PackagesListKind.ideas),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  if (_ctrl.isLoadingPackages)
                    const _ShimmerCard(height: 205)
                  else if (_ctrl.packagesLoadError != null)
                    _HomeMessageCard(
                      message: l10n.homeOffersLoadError,
                      actionLabel: l10n.retry,
                      onAction: _ctrl.loadPackages,
                      isDark: isDark,
                    )
                  else if (_ctrl.packages.isEmpty)
                    _HomeMessageCard(
                      message: l10n.homeNoDestinations,
                      isDark: isDark,
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          height: 205,
                          child: PageView.builder(
                            controller: _ideasController,
                            itemCount: _ctrl.packages.length,
                            onPageChanged: (index) =>
                                setState(() => _activeIdea = index),
                            itemBuilder: (_, index) => Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 12),
                              child: _PackageCard(
                                package: _ctrl.packages[index],
                                index: index,
                                onTap: () =>
                                    _openPackage(_ctrl.packages[index]),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _ctrl.packages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: index == _activeIdea ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: index == _activeIdea
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (_monuments.isNotEmpty) ...[
                    _SectionHeader(
                      title: l10n.homeMonuments,
                      actionLabel: l10n.viewAll,
                      onAction: () =>
                          Navigator.pushNamed(context, AppRoutes.attractions),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    _MonumentsRow(monuments: _monuments),
                    const SizedBox(height: 24),
                  ],
                  _SectionHeader(
                    title: l10n.homeOffers,
                    actionLabel: l10n.viewAll,
                    onAction: () => _openPackagesList(PackagesListKind.deals),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 12),
                  if (_ctrl.isLoadingPackages)
                    SizedBox(
                      height: 205,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 2,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) =>
                            const _ShimmerCard(width: 260, height: 205),
                      ),
                    )
                  else if (offers.isEmpty)
                    _HomeMessageCard(
                      message: _ctrl.packagesLoadError == null
                          ? l10n.homeNoOffers
                          : l10n.homeOffersLoadError,
                      actionLabel:
                          _ctrl.packagesLoadError == null ? null : l10n.retry,
                      onAction: _ctrl.packagesLoadError == null
                          ? null
                          : _ctrl.loadPackages,
                      isDark: isDark,
                    )
                  else
                    SizedBox(
                      height: 205,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: offers.take(4).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          final offer = offers[index];
                          return _OfferCard(
                            package: offer,
                            l10n: l10n,
                            isDark: isDark,
                            onTap: () => _openPackage(offer),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: l10n.upcomingTrip, isDark: isDark),
                  const SizedBox(height: 14),
                  if (_ctrl.isLoadingTrip)
                    const _ShimmerCard(height: 160)
                  else if (_ctrl.upcomingTrip != null)
                    BoardingPassCard(
                      trip: _ctrl.upcomingTrip!,
                      onTap: () async {
                        final cancelled = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TripDetailsScreen(trip: _ctrl.upcomingTrip!),
                          ),
                        );
                        if (cancelled == true) _ctrl.loadUpcomingTrip();
                      },
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0)
                  else
                    _EmptyTripCard(l10n: l10n),
                  const SizedBox(height: 24),
                  _ZenPromoCard(l10n: l10n).animate().fade(delay: 300.ms),
                  const SizedBox(height: 18),
                  _PersonalizedRecommendationsCard(
                    l10n: l10n,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TravelPreferencesScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/*
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.l10n.homeTravelersLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: _travelers > 1
                                  ? () => setState(() => _travelers--)
                                  : null,
                              icon: const Icon(Icons.remove_rounded, size: 14),
                            ),
                            Text(
                              '$_travelers',
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: _travelers < 9
                                  ? () => setState(() => _travelers++)
                                  : null,
                              icon: const Icon(Icons.add_rounded, size: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                    l10n: l10n,
                    isDark: isDark,
                    packages: _ctrl.packages,
                  ).animate().fade(delay: 80.ms).slideY(begin: 0.06, end: 0),
                  const SizedBox(height: 20),
                  _QuickActions(l10n: l10n).animate().fade(delay: 100.ms),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: l10n.homeNewIdeas,
                    actionLabel: l10n.viewAll,
                    onAction: () =>
                        Navigator.pushNamed(context, AppRoutes.attractions),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  if (_ctrl.isLoadingPackages)
                    const _ShimmerCard(height: 205)
                  else if (_ctrl.packagesLoadError != null)
                    _HomeMessageCard(
                      message: l10n.homeOffersLoadError,
                      actionLabel: l10n.retry,
                      onAction: _ctrl.loadPackages,
                      isDark: isDark,
                    )
                  else if (_ctrl.packages.isEmpty)
                    _HomeMessageCard(
                      message: l10n.homeNoDestinations,
                      isDark: isDark,
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          height: 205,
                          child: PageView.builder(
                            controller: _ideasController,
                            itemCount: _ctrl.packages.length,
                            onPageChanged: (index) =>
                                setState(() => _activeIdea = index),
                            itemBuilder: (_, index) => Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 12),
                              child: _PackageCard(
                                package: _ctrl.packages[index],
                                index: index,
                                onTap: () =>
                                    _openPackage(_ctrl.packages[index]),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _ctrl.packages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: index == _activeIdea ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: index == _activeIdea
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: l10n.homeOffers, isDark: isDark),
                  const SizedBox(height: 12),
                  if (_ctrl.isLoadingPackages)
                    SizedBox(
                      height: 205,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 2,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) =>
                            const _ShimmerCard(width: 260, height: 205),
                      ),
                    )
                  else if (offers.isEmpty)
                    _HomeMessageCard(
                      message: _ctrl.packagesLoadError == null
                          ? l10n.homeNoOffers
                          : l10n.homeOffersLoadError,
                      actionLabel:
                          _ctrl.packagesLoadError == null ? null : l10n.retry,
                      onAction: _ctrl.packagesLoadError == null
                          ? null
                          : _ctrl.loadPackages,
                      isDark: isDark,
                    )
                  else
                    SizedBox(
                      height: 205,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: offers.take(4).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          final offer = offers[index];
                          return _OfferCard(
                            package: offer,
                            l10n: l10n,
                            isDark: isDark,
                            onTap: () => _openPackage(offer),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),
                  _SectionHeader(title: l10n.upcomingTrip, isDark: isDark),
                  const SizedBox(height: 14),
                  if (_ctrl.isLoadingTrip)
                    const _ShimmerCard(height: 160)
                  else if (_ctrl.upcomingTrip != null)
                    BoardingPassCard(
                      trip: _ctrl.upcomingTrip!,
                      onTap: () async {
                        final cancelled = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TripDetailsScreen(trip: _ctrl.upcomingTrip!),
                          ),
                        );
                        if (cancelled == true) _ctrl.loadUpcomingTrip();
                      },
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0)
                  else
                    _EmptyTripCard(l10n: l10n),
                  const SizedBox(height: 24),
                  _ZenPromoCard(l10n: l10n).animate().fade(delay: 300.ms),
                  const SizedBox(height: 18),
                  _PersonalizedRecommendationsCard(
                    l10n: l10n,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TravelPreferencesScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /*
  @override
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.l10n.homeTravelersLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                      SizedBox(
                        height: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: _travelers > 1
                                  ? () => setState(() => _travelers--)
                                  : null,
                              icon: const Icon(Icons.remove_rounded, size: 14),
                            ),
                            Text(
                              '$_travelers',
                              style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 28,
                                height: 28,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: _travelers < 9
                                  ? () => setState(() => _travelers++)
                                  : null,
                              icon: const Icon(Icons.add_rounded, size: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                      .animate()
                      .fade(duration: 500.ms),
                  const SizedBox(height: 18),

                  _HomeSearchCard(
                    l10n: l10n,
                    isDark: isDark,
                    packages: _ctrl.packages,
                  ).animate().fade(delay: 80.ms).slideY(begin: 0.06, end: 0),
                  const SizedBox(height: 20),

                  // ── Quick Actions ─────────────────────────────────────
                  _QuickActions(l10n: l10n).animate().fade(delay: 100.ms),
                  const SizedBox(height: 24),

                  // ── Rotating destination ideas ────────────────────────
                  _SectionHeader(
                    title: l10n.homeNewIdeas,
                    actionLabel: l10n.viewAll,
                    onAction: () =>
                        Navigator.pushNamed(context, AppRoutes.attractions),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 14),
                  if (_ctrl.isLoadingPackages)
                    const _ShimmerCard(height: 205)
                  else if (_ctrl.packagesLoadError != null)
                    _HomeMessageCard(
                      message: l10n.homeOffersLoadError,
                      actionLabel: l10n.retry,
                      onAction: _ctrl.loadPackages,
                      isDark: isDark,
                    )
                  else if (_ctrl.packages.isEmpty)
                    _HomeMessageCard(
                      message: l10n.homeNoDestinations,
                      isDark: isDark,
                    )
                  else
                    Column(
                      children: [
                        SizedBox(
                          height: 205,
                          child: PageView.builder(
                            controller: _ideasController,
                            itemCount: _ctrl.packages.length,
                            onPageChanged: (index) =>
                                setState(() => _activeIdea = index),
                            itemBuilder: (_, index) => Padding(
                              padding:
                                  const EdgeInsetsDirectional.only(end: 12),
                              child: _PackageCard(
                                package: _ctrl.packages[index],
                                index: index,
                                onTap: () =>
                                    _openPackage(_ctrl.packages[index]),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _ctrl.packages.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: index == _activeIdea ? 18 : 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: index == _activeIdea
                                    ? AppColors.primary
                                    : (isDark
                                        ? AppColors.darkBorder
                                        : AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  // ── Offers ────────────────────────────────────────────
                  _SectionHeader(title: l10n.homeOffers, isDark: isDark),
                  const SizedBox(height: 12),
                  if (_ctrl.isLoadingPackages)
                    SizedBox(
                      height: 205,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: 2,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) =>
                            const _ShimmerCard(width: 260, height: 205),
                      ),
                    )
                  else if (_ctrl.packages.isEmpty)
                    _HomeMessageCard(
                      message: _ctrl.packagesLoadError == null
                          ? l10n.homeNoOffers
                          : l10n.homeOffersLoadError,
                      actionLabel:
                          _ctrl.packagesLoadError == null ? null : l10n.retry,
                      onAction: _ctrl.packagesLoadError == null
                          ? null
                          : _ctrl.loadPackages,
                      isDark: isDark,
                    )
                  else
                    SizedBox(
                      height: 205,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        itemCount: offerPackages.take(4).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          final offer = offerPackages[index];
                          return _OfferCard(
                            package: offer,
                            l10n: l10n,
                            isDark: isDark,
                            onTap: () => _openPackage(offer),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 18),

                  // ── Upcoming Trip ─────────────────────────────────────
                  _SectionHeader(title: l10n.upcomingTrip, isDark: isDark),
                  const SizedBox(height: 14),
                  if (_ctrl.isLoadingTrip)
                    const _ShimmerCard(height: 160)
                  else if (_ctrl.upcomingTrip != null)
                    BoardingPassCard(
                      trip: _ctrl.upcomingTrip!,
                      onTap: () async {
                        final cancelled = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TripDetailsScreen(trip: _ctrl.upcomingTrip!),
                            ));
                        if (cancelled == true) _ctrl.loadUpcomingTrip();
                      },
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0)
                  else
                    _EmptyTripCard(l10n: l10n),
                  const SizedBox(height: 24),

                  // ── Zen AI promo ──────────────────────────────────────
                  _ZenPromoCard(l10n: l10n).animate().fade(delay: 300.ms),
                  const SizedBox(height: 18),
                  _PersonalizedRecommendationsCard(
                    l10n: l10n,
                    isDark: isDark,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TravelPreferencesScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

  */
}

*/
// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _GreetingHeader extends StatelessWidget {
  final String userName;
  final AppLocalizations l10n;
  final bool isDark;

  const _GreetingHeader(
      {required this.userName, required this.l10n, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName.isNotEmpty
                  ? l10n.commonGreetingNamed(userName)
                  : l10n.greeting,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(l10n.whereNext, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _NotificationsSheet.show(context, l10n),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
                  ListenableBuilder(
                    listenable: NotificationsStore.instance,
                    builder: (_, __) => NotificationsStore.instance.hasUnread
                        ? Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                  color: AppColors.accentRed,
                                  shape: BoxShape.circle),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeSearchCard extends StatefulWidget {
  final AppLocalizations l10n;
  final bool isDark;
  final List<TravelPackage> packages;

  const _HomeSearchCard({
    required this.l10n,
    required this.isDark,
    required this.packages,
  });

  @override
  State<_HomeSearchCard> createState() => _HomeSearchCardState();
}

class _HomeSearchCardState extends State<_HomeSearchCard> {
  TravelPackage? _selectedPackage;
  DateTime _travelDate = DateTime.now().add(const Duration(days: 7));
  int _travelers = 2;

  Future<void> _chooseDestination() async {
    if (widget.packages.isEmpty) return;
    final selected = await showModalBottomSheet<TravelPackage>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                widget.l10n.homeChooseDestination,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...widget.packages.map(
              (package) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(package.icon, color: AppColors.primary),
                ),
                title: Text(package.location),
                subtitle: Text(package.country),
                onTap: () => Navigator.pop(context, package),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _selectedPackage = selected);
    }
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) setState(() => _travelDate = date);
  }

  void _search() {
    final package = _selectedPackage ??
        (widget.packages.isEmpty ? null : widget.packages.first);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FlightSearchScreen(
          initialDestinationCode: package?.destinationCode,
          initialDestinationCity: package?.location,
          initialDepartureDate: _travelDate,
          initialPassengers: _travelers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? AppColors.darkSurface : AppColors.surface;
    final border = widget.isDark ? AppColors.darkBorder : AppColors.border;
    final foreground =
        widget.isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final package = _selectedPackage ??
        (widget.packages.isEmpty ? null : widget.packages.first);
    final dateLabel =
        MaterialLocalizations.of(context).formatMediumDate(_travelDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: widget.isDark
            ? const []
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.l10n.homeSearchTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight_rounded,
                    color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(widget.l10n.quickActionFlights,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _HomeSearchField(
            icon: Icons.place_outlined,
            label: widget.l10n.homeDestinationLabel,
            value: package == null
                ? widget.l10n.homeChooseDestination
                : '${package.location}, ${package.country}',
            isDark: widget.isDark,
            onTap: _chooseDestination,
          ),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final dateField = _HomeSearchField(
                icon: Icons.calendar_month_outlined,
                label: widget.l10n.homeTravelDateLabel,
                value: dateLabel,
                isDark: widget.isDark,
                onTap: _chooseDate,
              );
              final travelerSelector = Container(
                height: 54,
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkSurfaceSecondary
                      : AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_outline_rounded,
                        size: 18, color: foreground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_travelers ${widget.l10n.homeTravelersLabel}',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 36),
                      onPressed: _travelers > 1
                          ? () => setState(() => _travelers--)
                          : null,
                      icon: const Icon(Icons.remove_rounded, size: 16),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints:
                          const BoxConstraints.tightFor(width: 32, height: 36),
                      onPressed: _travelers < 9
                          ? () => setState(() => _travelers++)
                          : null,
                      icon: const Icon(Icons.add_rounded, size: 16),
                    ),
                  ],
                ),
              );

              if (constraints.maxWidth < 420) {
                return Column(
                  children: [
                    dateField,
                    const SizedBox(height: 9),
                    travelerSelector,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: dateField),
                  const SizedBox(width: 9),
                  Expanded(child: travelerSelector),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.search_rounded, size: 19),
              label: Text(widget.l10n.homeSearchButton),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSearchField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final VoidCallback onTap;

  const _HomeSearchField({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    return Material(
      color:
          isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 19),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10)),
                      const SizedBox(height: 2),
                      Text(value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeMessageCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isDark;

  const _HomeMessageCard({
    required this.message,
    required this.isDark,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}

class _PersonalizedRecommendationsCard extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback onTap;

  const _PersonalizedRecommendationsCard({
    required this.l10n,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded,
                  color: AppColors.primary, size: 21),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.homePersonalizedTitle,
                        style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(l10n.homePersonalizedMessage,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 5),
                    Text(l10n.homePersonalizedAction,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textHint),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AppLocalizations l10n;
  const _QuickActions({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.hotel_rounded,
        l10n.quickActionHotels,
        AppColors.accentTeal,
        AppRoutes.hotelSearch
      ),
      (
        Icons.directions_car_rounded,
        l10n.quickActionCars,
        AppColors.accentOrange,
        AppRoutes.carRental
      ),
      (
        Icons.explore_rounded,
        l10n.quickActionAttractions,
        AppColors.accentPurple,
        AppRoutes.attractions
      ),
      (
        Icons.local_taxi_rounded,
        l10n.quickActionTransfers,
        AppColors.accentGreen,
        AppRoutes.transfers
      ),
    ];
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final (icon, label, color, route) = actions[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(ctx, route),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          )
              .animate(delay: Duration(milliseconds: 80 * i))
              .fade()
              .slideX(begin: 0.15, end: 0);
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isDark;

  const _SectionHeader(
      {required this.title,
      this.actionLabel,
      this.onAction,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _EmptyTripCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyTripCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        color: AppColors.surfaceSecondary,
      ),
      child: Column(
        children: [
          const Icon(Icons.flight_takeoff_rounded,
              color: AppColors.textHint, size: 36),
          const SizedBox(height: 10),
          Text(l10n.noUpcomingTrip,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.flightSearch),
            child: Text(l10n.startPlanningWithZen),
          ),
        ],
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final TravelPackage package;
  final int index;
  final VoidCallback onTap;

  const _PackageCard(
      {required this.package, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: package.gradient,
            boxShadow: [
              BoxShadow(
                color: package.gradient.colors.first.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (package.imageUrl.isNotEmpty)
                  Image.network(
                    package.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => DecoratedBox(
                      decoration: BoxDecoration(gradient: package.gradient),
                    ),
                  )
                else
                  DecoratedBox(
                      decoration: BoxDecoration(gradient: package.gradient)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x22000000),
                        Color(0x00000000),
                        Color(0xD9000000),
                      ],
                      stops: [0, 0.38, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      package.country,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: ListenableBuilder(
                    listenable: FavoritesController.instance,
                    builder: (_, __) {
                      final isFav =
                          FavoritesController.instance.isFavorite(package.id);
                      return IconButton(
                        tooltip:
                            isFav ? 'Remove from saved' : 'Save destination',
                        onPressed: () => FavoritesController.instance.toggle(
                          FavoritePlace(
                            id: package.id,
                            title: package.title,
                            subtitle: package.location,
                            type: 'destination',
                            imageUrl: package.imageUrl,
                          ),
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.34),
                          foregroundColor: Colors.white,
                          fixedSize: const Size(36, 36),
                          padding: EdgeInsets.zero,
                        ),
                        icon: Icon(
                          isFav
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 18,
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: 15,
                  right: 15,
                  bottom: 13,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: AppColors.accentYellow, size: 15),
                          const SizedBox(width: 3),
                          Text(package.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(width: 7),
                          Text(package.location,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '\$${package.pricePerPerson.toStringAsFixed(0)} · ${package.durationLabel}',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.86)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 100 * index))
        .fade()
        .slideY(begin: 0.08, end: 0);
  }
}

class _OfferCard extends StatelessWidget {
  final TravelPackage package;
  final AppLocalizations l10n;
  final bool isDark;
  final VoidCallback onTap;

  const _OfferCard({
    required this.package,
    required this.l10n,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 270,
          child: Row(
            children: [
              SizedBox(
                width: 105,
                height: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (package.imageUrl.isNotEmpty)
                      Image.network(
                        package.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(gradient: package.gradient),
                        ),
                      )
                    else
                      DecoratedBox(
                          decoration:
                              BoxDecoration(gradient: package.gradient)),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(l10n.homeFeaturedOffer,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(package.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${package.location}, ${package.country}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10)),
                      const Spacer(),
                      Text(
                        '${l10n.homeStartingFrom} \$${package.pricePerPerson.toStringAsFixed(0)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(package.durationLabel,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonumentsRow extends StatelessWidget {
  final List<AttractionModel> monuments;
  const _MonumentsRow({required this.monuments});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: monuments.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final a = monuments[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(
                context, AppRoutes.attractionDetail,
                arguments: a),
            child: SizedBox(
              width: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppNetworkImage(
                      url: a.imageUrl,
                      fallbackIcon: attractionCategoryIcon(a.category),
                      fallbackGradient: AppColors.destinationGradients[
                          i % AppColors.destinationGradients.length],
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xE6000000)],
                          stops: [0.4, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(a.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13)),
                          Text(a.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ZenPromoCard extends StatelessWidget {
  final AppLocalizations l10n;
  const _ZenPromoCard({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => AppShellTabController.goToChatbot(),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.purpleGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accentPurple.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Zen AI Assistant',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(l10n.startPlanningWithZen,
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double? width;
  final double height;
  const _ShimmerCard({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor:
          isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
      highlightColor: isDark ? AppColors.darkBorder : AppColors.border,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

// ── Notifications (بيانات حقيقية من NotificationsStore) ────────────────────

class _NotificationsSheet extends StatefulWidget {
  final AppLocalizations l10n;
  const _NotificationsSheet({required this.l10n});

  static void show(BuildContext context, AppLocalizations l10n) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NotificationsSheet(l10n: l10n),
    );
    // اعتبر كل الإشعارات "مقروءة" فور فتح القائمة — النقطة الحمرا تختفي.
    NotificationsStore.instance.markAllRead();
  }

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  AppLocalizations get l10n => widget.l10n;

  (IconData, Color) _styleFor(NotifKind kind) => switch (kind) {
        NotifKind.booking => (
            Icons.check_circle_rounded,
            AppColors.accentGreen
          ),
        NotifKind.cancel => (Icons.cancel_rounded, AppColors.accentRed),
        NotifKind.chat => (Icons.auto_awesome_rounded, AppColors.accentPurple),
        NotifKind.promo => (Icons.local_offer_rounded, AppColors.accentOrange),
        NotifKind.reminder => (Icons.flight_takeoff_rounded, AppColors.primary),
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inHours < 1) return l10n.notifTimeAgoHours(0);
    if (diff.inHours < 24) return l10n.notifTimeAgoHours(diff.inHours);
    return l10n.notifTimeAgoDays(diff.inDays);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: NotificationsStore.instance,
      builder: (context, _) {
        final items = NotificationsStore.instance.all;
        return DraggableScrollableSheet(
          initialChildSize: items.isEmpty ? 0.35 : 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(l10n.notificationsTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Icon(Icons.notifications_rounded,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                        size: 20),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.notifications_off_outlined,
                                size: 40, color: AppColors.textHint),
                            const SizedBox(height: 10),
                            Text(l10n.notifEmptyTitle,
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = items[i];
                          final (icon, color) = _styleFor(n.kind);
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurfaceSecondary
                                  : AppColors.surfaceSecondary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(11)),
                                  child: Icon(icon, color: color, size: 19),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(n.title,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5)),
                                      const SizedBox(height: 3),
                                      Text(n.subtitle,
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12.5)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_timeAgo(n.createdAt),
                                    style: const TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 11)),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
