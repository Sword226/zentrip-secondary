import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../global_widgets/app_logo.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/admin_dashboard_model.dart';
import '../../../../models/flight_model.dart';
import '../../../../models/partner_dashboard_model.dart';
import '../../../../routes/app_routes.dart';

enum _PartnerSection { overview, listings, reservations, customers }

class PartnerDashboardScreen extends StatefulWidget {
  const PartnerDashboardScreen({super.key});

  @override
  State<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends State<PartnerDashboardScreen> {
  _PartnerSection _section = _PartnerSection.overview;
  PartnerDashboardData? _dashboard;
  List<PartnerListing> _listings = [];
  List<PartnerReservation> _reservations = [];
  List<AdminCustomer> _customers = [];
  bool _loading = true;
  bool _loadingSection = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ApiService.instance.getPartnerDashboard();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess && result.data != null) {
        _dashboard = result.data;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  Future<void> _loadListings() async {
    final result = await ApiService.instance.getPartnerListings();
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      setState(() => _listings = result.data!);
    } else {
      setState(() => _error = result.errorMessage);
    }
  }

  Future<void> _selectSection(_PartnerSection section) async {
    setState(() {
      _section = section;
      _error = null;
    });
    if (section == _PartnerSection.overview) return;
    if (section == _PartnerSection.listings) {
      if (_listings.isEmpty) {
        setState(() => _loadingSection = true);
        await _loadListings();
        if (mounted) setState(() => _loadingSection = false);
      }
      return;
    }
    if (section == _PartnerSection.reservations && _reservations.isNotEmpty) {
      return;
    }
    if (section == _PartnerSection.customers && _customers.isNotEmpty) return;

    setState(() => _loadingSection = true);
    if (section == _PartnerSection.reservations) {
      final result = await ApiService.instance.getPartnerReservations();
      if (!mounted) return;
      setState(() {
        _loadingSection = false;
        if (result.isSuccess && result.data != null) {
          _reservations = result.data!;
        } else {
          _error = result.errorMessage;
        }
      });
    } else {
      final result = await ApiService.instance.getPartnerCustomers();
      if (!mounted) return;
      setState(() {
        _loadingSection = false;
        if (result.isSuccess && result.data != null) {
          _customers = result.data!;
        } else {
          _error = result.errorMessage;
        }
      });
    }
  }

  Future<void> _refresh() async {
    await _loadOverview();
    if (!mounted || _error != null) return;
    switch (_section) {
      case _PartnerSection.overview:
        break;
      case _PartnerSection.listings:
        await _loadListings();
        break;
      case _PartnerSection.reservations:
        final result = await ApiService.instance.getPartnerReservations();
        if (!mounted) return;
        setState(() {
          if (result.isSuccess && result.data != null) {
            _reservations = result.data!;
          } else {
            _error = result.errorMessage;
          }
        });
        break;
      case _PartnerSection.customers:
        final result = await ApiService.instance.getPartnerCustomers();
        if (!mounted) return;
        setState(() {
          if (result.isSuccess && result.data != null) {
            _customers = result.data!;
          } else {
            _error = result.errorMessage;
          }
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ApiService.instance.currentUser;
    if (user?.isPartner != true) {
      return Scaffold(body: Center(child: Text(l10n.adminNoAccess)));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBackground
            : AppColors.background,
        bottomNavigationBar: isWide ? null : _mobileNavigation(l10n),
        body: SafeArea(
          child: Row(
            children: [
              if (isWide) _sideNavigation(l10n, user!.name),
              Expanded(
                child: Column(
                  children: [
                    _topBar(l10n, user!.name, isWide),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _refresh,
                        child: _content(l10n, isWide),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _sideNavigation(AppLocalizations l10n, String name) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogo(size: 42, showBackground: true),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Zentrip',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800)),
                    Text(l10n.partnerWorkspaceLabel,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          _navItem(l10n.partnerOverview, Icons.space_dashboard_outlined,
              _PartnerSection.overview),
          const SizedBox(height: 8),
          _navItem(l10n.partnerListings, Icons.inventory_2_outlined,
              _PartnerSection.listings),
          const SizedBox(height: 8),
          _navItem(l10n.partnerReservations, Icons.book_online_outlined,
              _PartnerSection.reservations),
          const SizedBox(height: 8),
          _navItem(l10n.partnerCustomers, Icons.people_outline_rounded,
              _PartnerSection.customers),
          const Spacer(),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.divider),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            leading: const Icon(Icons.open_in_new_rounded, size: 20),
            title: Text(l10n.partnerBackToApp,
                style: const TextStyle(fontSize: 13)),
            onTap: () =>
                Navigator.pushReplacementNamed(context, AppRoutes.home),
          ),
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primarySurface,
            child: Text(name.isEmpty ? 'Z' : name[0].toUpperCase(),
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _navItem(String label, IconData icon, _PartnerSection section) {
    final selected = _section == section;
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _selectSection(section),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? AppColors.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                    color: selected ? AppColors.primary : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileNavigation(AppLocalizations l10n) => NavigationBar(
        selectedIndex: _section.index,
        onDestinationSelected: (index) =>
            _selectSection(_PartnerSection.values[index]),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.space_dashboard_outlined),
              label: l10n.partnerOverview),
          NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              label: l10n.partnerListings),
          NavigationDestination(
              icon: const Icon(Icons.book_online_outlined),
              label: l10n.partnerReservations),
          NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              label: l10n.partnerCustomers),
        ],
      );

  Widget _topBar(AppLocalizations l10n, String name, bool isWide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          bottom: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Row(
        children: [
          if (!isWide) ...[
            const AppLogo(size: 38, showBackground: true),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_sectionTitle(l10n),
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                if (isWide)
                  Text('${l10n.partnerWelcome}, $name',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          IconButton(
              tooltip: l10n.adminRefresh,
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded)),
          if (!isWide)
            IconButton(
                tooltip: l10n.partnerBackToApp,
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.home),
                icon: const Icon(Icons.home_outlined)),
        ],
      ),
    );
  }

  String _sectionTitle(AppLocalizations l10n) => switch (_section) {
        _PartnerSection.overview => l10n.partnerOverview,
        _PartnerSection.listings => l10n.partnerListings,
        _PartnerSection.reservations => l10n.partnerReservations,
        _PartnerSection.customers => l10n.partnerCustomers,
      };

  Widget _content(AppLocalizations l10n, bool isWide) {
    if (_loading && _dashboard == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _dashboard == null) {
      return _errorState(l10n.partnerLoadFailed);
    }
    if (_loadingSection) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) return _errorState(l10n.partnerLoadFailed);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(isWide ? 32 : 18, 24, isWide ? 32 : 18, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: switch (_section) {
            _PartnerSection.overview => _overview(l10n, isWide),
            _PartnerSection.listings => _listingsView(l10n, isWide),
            _PartnerSection.reservations => _reservationsView(l10n),
            _PartnerSection.customers => _customersView(l10n, isWide),
          },
        ),
      ),
    );
  }

  Widget _errorState(String message) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(AppLocalizations.of(context).adminRefresh)),
          ],
        ),
      );

  Widget _overview(AppLocalizations l10n, bool isWide) {
    final data = _dashboard;
    if (data == null) return const SizedBox.shrink();
    final columns = isWide ? 4 : 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${l10n.partnerSubtitle} ${data.companyName}',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, constraints) {
          final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricCard(
                  width: width,
                  title: l10n.partnerListingCount,
                  value: '${data.listingCount}',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.primary),
              _MetricCard(
                  width: width,
                  title: l10n.partnerActiveListings,
                  value: '${data.activeListingCount}',
                  icon: Icons.check_circle_outline,
                  color: AppColors.accentGreen),
              _MetricCard(
                  width: width,
                  title: l10n.partnerReservationCount,
                  value: '${data.reservationCount}',
                  icon: Icons.book_online_outlined,
                  color: AppColors.accentTeal),
              _MetricCard(
                  width: width,
                  title: l10n.partnerCustomerCount,
                  value: '${data.customerCount}',
                  icon: Icons.people_outline_rounded,
                  color: AppColors.accentOrange),
              _MetricCard(
                  width: width,
                  title: l10n.partnerBookedValue,
                  value: NumberFormat.currency(
                          locale: Localizations.localeOf(context).toString(),
                          symbol: '\$',
                          decimalDigits: 0)
                      .format(data.bookedValue),
                  icon: Icons.payments_outlined,
                  color: AppColors.accentOrange),
            ],
          );
        }),
        const SizedBox(height: 24),
        _sectionHeading(l10n.partnerRecentReservations),
        const SizedBox(height: 12),
        if (data.recentReservations.isEmpty)
          _emptyCard(l10n.partnerNoReservations)
        else
          ...data.recentReservations
              .map((item) => _reservationCard(item, l10n)),
      ],
    );
  }

  Widget _listingsView(AppLocalizations l10n, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionHeading(l10n.partnerManageListings)),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _editListing,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.partnerCreateListing),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _serviceLabel(l10n, _dashboard?.serviceType),
          style:
              TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        if (_listings.isEmpty)
          _emptyCard(l10n.partnerEmptyListings)
        else
          LayoutBuilder(builder: (context, constraints) {
            final columns = isWide ? 2 : 1;
            final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _listings
                  .map((listing) => SizedBox(
                      width: width, child: _listingCard(listing, l10n)))
                  .toList(),
            );
          }),
      ],
    );
  }

  Widget _listingCard(PartnerListing listing, AppLocalizations l10n) {
    final status =
        listing.active ? l10n.partnerStatusActive : l10n.partnerStatusPaused;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(listing.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                    color: listing.active
                        ? AppColors.accentGreen.withValues(alpha: .12)
                        : AppColors.accentOrange.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(status,
                    style: TextStyle(
                        color: listing.active
                            ? AppColors.accentGreen
                            : AppColors.accentOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${listing.city}, ${listing.country}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (listing.listingCode != null) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.partnerGeneratedCode}: ${listing.listingCode}'
              '${listing.type == 'flight' ? ' · ${listing.attributes['flight_number'] ?? ''}' : ''}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${_serviceLabel(l10n, _serviceForListingType(listing.type))} · ${NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(listing.price)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (listing.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(listing.description,
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => _editListing(listing),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.partnerEditListing),
              ),
              OutlinedButton(
                onPressed: () => _setListingActive(listing, !listing.active),
                child: Text(listing.active
                    ? l10n.partnerStatusPaused
                    : l10n.partnerStatusActive),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _serviceLabel(AppLocalizations l10n, String? serviceType) =>
      switch (serviceType) {
        'airline' => l10n.partnerTypeFlight,
        'hotel' => l10n.partnerTypeHotel,
        'car' => l10n.partnerTypeCar,
        'attraction' => l10n.partnerTypeAttraction,
        'transfer' => l10n.partnerTypeTransfer,
        'travel' => l10n.partnerTypePackage,
        _ => l10n.partnerServiceType,
      };

  String _serviceForListingType(String type) => switch (type) {
        'flight' => 'airline',
        'hotel' => 'hotel',
        'car' => 'car',
        'attraction' => 'attraction',
        'transfer' => 'transfer',
        'package' => 'travel',
        _ => '',
      };

  Future<void> _editListing([PartnerListing? existing]) async {
    final l10n = AppLocalizations.of(context);
    final user = ApiService.instance.currentUser!;
    final result = await showDialog<PartnerListing>(
      context: context,
      builder: (_) => _PartnerListingDialog(
        existing: existing,
        type: _listingType(user.partnerServiceType),
      ),
    );
    if (result == null || !mounted) return;
    final response = await ApiService.instance.savePartnerListing(result);
    if (!mounted) return;
    if (response.isFailure) {
      AppSnackbar.error(
          context, response.errorMessage ?? l10n.partnerListingSaveFailed);
      return;
    }
    AppSnackbar.success(context, l10n.partnerListingSaved);
    await _loadListings();
    if (!mounted) return;
    await _loadOverview();
  }

  Future<void> _setListingActive(PartnerListing listing, bool active) async {
    final l10n = AppLocalizations.of(context);
    final result =
        await ApiService.instance.setPartnerListingActive(listing, active);
    if (!mounted) return;
    if (result.isFailure) {
      AppSnackbar.error(
          context, result.errorMessage ?? l10n.partnerListingSaveFailed);
      return;
    }
    await _loadListings();
    if (!mounted) return;
    await _loadOverview();
  }

  String _listingType(String? serviceType) => switch (serviceType) {
        'airline' => 'flight',
        'hotel' => 'hotel',
        'car' => 'car',
        'attraction' => 'attraction',
        'transfer' => 'transfer',
        'travel' => 'package',
        _ => 'hotel',
      };

  Widget _reservationsView(AppLocalizations l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(l10n.partnerReservations),
          const SizedBox(height: 14),
          if (_reservations.isEmpty)
            _emptyCard(l10n.partnerNoReservations)
          else
            ..._reservations.map((item) => _reservationCard(item, l10n)),
        ],
      );

  Widget _reservationCard(PartnerReservation item, AppLocalizations l10n) {
    final date = item.reservationDate == null
        ? ''
        : DateFormat.yMMMd(Localizations.localeOf(context).toString())
            .format(item.reservationDate!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Panel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child:
                    Icon(Icons.book_online_outlined, color: AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${item.customerName} · $date'),
                  if (item.customerEmail.isNotEmpty ||
                      item.customerPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [item.customerEmail, item.customerPhone]
                          .where((value) => value.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    NumberFormat.currency(symbol: '\$', decimalDigits: 2)
                        .format(item.amount),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(item.status,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _customersView(AppLocalizations l10n, bool isWide) {
    if (_customers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(l10n.partnerCustomers),
          const SizedBox(height: 14),
          _emptyCard(l10n.partnerNoCustomers),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(l10n.partnerCustomerDetails),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final columns = isWide ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: _customers
                .map((customer) => SizedBox(
                      width: width,
                      child: _Panel(
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primarySurface,
                              child: Text(customer.name.isEmpty
                                  ? '?'
                                  : customer.name[0].toUpperCase()),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(customer.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  if (customer.email.isNotEmpty)
                                    Text(customer.email),
                                  if (customer.phone.isNotEmpty)
                                    Text(customer.phone),
                                ],
                              ),
                            ),
                            Text('${customer.reservationCount}',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }

  Widget _sectionHeading(String label) => Text(label,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800));

  Widget _emptyCard(String label) => _Panel(
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ),
      );
}

class _PartnerListingDialog extends StatefulWidget {
  final PartnerListing? existing;
  final String type;

  const _PartnerListingDialog({this.existing, required this.type});

  @override
  State<_PartnerListingDialog> createState() => _PartnerListingDialogState();
}

class _PartnerListingDialogState extends State<_PartnerListingDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _description;
  late final TextEditingController _image;
  late final TextEditingController _price;
  late final Map<String, TextEditingController> _attributeFields;
  late final Map<String, bool> _booleanAttributes;
  late final TextEditingController _originCity;
  late final TextEditingController _originCode;
  late final TextEditingController _destinationCity;
  late final TextEditingController _destinationCode;
  late final TextEditingController _departureTime;
  late final TextEditingController _arrivalTime;
  late final TextEditingController _transferPickupTime;
  late final TextEditingController _pickupLocation;
  late final TextEditingController _dropoffLocation;
  String? _error;

  @override
  void initState() {
    super.initState();
    final listing = widget.existing;
    _title = TextEditingController(text: listing?.title ?? '');
    _city = TextEditingController(text: listing?.city ?? '');
    _country = TextEditingController(text: listing?.country ?? '');
    _description = TextEditingController(text: listing?.description ?? '');
    _image = TextEditingController(
      text: widget.type == 'flight' ? '' : listing?.imageUrl ?? '',
    );
    _price =
        TextEditingController(text: listing == null ? '' : '${listing.price}');
    final attributes = {
      ..._starterAttributes(widget.type),
      ...?listing?.attributes,
    };
    final originCity = '${attributes['origin_city'] ?? listing?.city ?? ''}';
    final destinationCity =
        '${attributes['destination_city'] ?? attributes['destination'] ?? _destinationFromTitle(listing?.title)}';
    _originCity = TextEditingController(text: originCity);
    _originCode = TextEditingController(
      text:
          '${attributes['origin_code'] ?? AirportOption.byCity(originCity)?.code ?? ''}',
    );
    _destinationCity = TextEditingController(text: destinationCity);
    _destinationCode = TextEditingController(
      text:
          '${attributes['destination_code'] ?? AirportOption.byCity(destinationCity)?.code ?? ''}',
    );
    _departureTime = TextEditingController(
        text: _dateTimeFieldValue(attributes['departure_time']));
    _arrivalTime = TextEditingController(
        text: _dateTimeFieldValue(attributes['arrival_time']));
    _transferPickupTime = TextEditingController(
        text: _dateTimeFieldValue(attributes['pickup_time']));
    _pickupLocation =
        TextEditingController(text: '${attributes['pickup_location'] ?? ''}');
    _dropoffLocation =
        TextEditingController(text: '${attributes['dropoff_location'] ?? ''}');
    _attributeFields = {
      for (final key in _editableAttributeKeys(widget.type))
        if (!_booleanAttributeKeys.contains(key))
          key: TextEditingController(
            text: _attributeFieldValue(attributes[key]),
          ),
    };
    _booleanAttributes = {
      for (final key in _booleanAttributeKeys)
        if (_editableAttributeKeys(widget.type).contains(key))
          key: attributes[key] == true,
    };
  }

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _country.dispose();
    _description.dispose();
    _image.dispose();
    _price.dispose();
    for (final controller in _attributeFields.values) {
      controller.dispose();
    }
    _originCity.dispose();
    _originCode.dispose();
    _destinationCity.dispose();
    _destinationCode.dispose();
    _departureTime.dispose();
    _arrivalTime.dispose();
    _transferPickupTime.dispose();
    _pickupLocation.dispose();
    _dropoffLocation.dispose();
    super.dispose();
  }

  void _save() {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      setState(() => _error = l10n.partnerInvalidPrice);
      return;
    }
    if (widget.type == 'hotel' && _image.text.trim().isEmpty) {
      setState(() => _error = l10n.partnerHotelPhotoRequired);
      return;
    }
    if (widget.type == 'flight') {
      final departure = _parseDateTimeField(_departureTime.text);
      final arrival = _parseDateTimeField(_arrivalTime.text);
      if (departure == null || arrival == null || !arrival.isAfter(departure)) {
        setState(() => _error = l10n.partnerInvalidFlightTimes);
        return;
      }
      if (_airportFromInput(_originCity.text, _originCode.text) == null ||
          _airportFromInput(_destinationCity.text, _destinationCode.text) ==
              null) {
        setState(() => _error = l10n.partnerRequiredField);
        return;
      }
    } else if (widget.type != 'transfer' && !_isRegisteredCity(_city.text)) {
      setState(() => _error = l10n.partnerRequiredField);
      return;
    }
    if (widget.type == 'transfer' &&
        (!_isRegisteredCity(_pickupLocation.text) ||
            !_isRegisteredCity(_dropoffLocation.text))) {
      setState(() => _error = l10n.partnerRequiredField);
      return;
    }
    try {
      final decoded = <String, dynamic>{
        ...?widget.existing?.attributes,
        for (final entry in _attributeFields.entries)
          entry.key: _parseAttributeValue(entry.key, entry.value.text),
        ..._booleanAttributes,
      }..removeWhere((key, _) =>
          _generatedAttributeKeys.contains(key) ||
          _deferredFlightAttributeKeys.contains(key));
      if (widget.type == 'flight') {
        final departure = _parseDateTimeField(_departureTime.text)!;
        final arrival = _parseDateTimeField(_arrivalTime.text)!;
        final origin = _airportFromInput(_originCity.text, _originCode.text)!;
        final destination =
            _airportFromInput(_destinationCity.text, _destinationCode.text)!;
        decoded.addAll({
          'origin_city': origin.city,
          'origin_code': origin.code,
          'origin_country': origin.country,
          'origin_region': origin.region,
          'destination_city': destination.city,
          'destination_code': destination.code,
          'destination_country': destination.country,
          'destination_region': destination.region,
          'departure_time': departure.toIso8601String(),
          'arrival_time': arrival.toIso8601String(),
        });
      } else if (widget.type == 'transfer') {
        final pickupTime = _parseDateTimeField(_transferPickupTime.text);
        if (pickupTime == null) {
          setState(() => _error = l10n.partnerRequiredField);
          return;
        }
        decoded.addAll({
          'pickup_location': _pickupLocation.text.trim(),
          'dropoff_location': _dropoffLocation.text.trim(),
          'pickup_time': pickupTime.toIso8601String(),
        });
      }
      final listingCity = widget.type == 'flight'
          ? _originCity.text
          : widget.type == 'transfer'
              ? _pickupLocation.text
              : _city.text;
      final location = AirportOption.byCity(listingCity)!;
      decoded['location_code'] = location.code;
      decoded['location_region'] = location.region;
      Navigator.pop(
        context,
        PartnerListing(
          id: widget.existing?.id,
          type: widget.type,
          title: _title.text.trim(),
          city: location.city,
          country: location.country,
          description: _description.text.trim(),
          imageUrl: widget.type == 'flight' ? '' : _image.text.trim(),
          price: price,
          active: widget.existing?.active ?? true,
          attributes: decoded,
        ),
      );
    } on FormatException catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 600;
    return AlertDialog(
      title: Text(widget.existing == null
          ? l10n.partnerCreateListing
          : l10n.partnerEditListing),
      content: SizedBox(
        width: wide ? 520 : null,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_title, l10n.partnerListingTitle, required: true),
                if (widget.type == 'flight') ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(l10n.partnerFlightRoute,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                  ),
                  _airportField(
                    controller: _originCity,
                    codeController: _originCode,
                    label: l10n.partnerOriginCity,
                  ),
                  _airportField(
                    controller: _destinationCity,
                    codeController: _destinationCode,
                    label: l10n.partnerDestinationCity,
                  ),
                  _dateTimeField(_departureTime, l10n.partnerDepartureTime),
                  _dateTimeField(_arrivalTime, l10n.partnerArrivalTime),
                ] else if (widget.type != 'transfer')
                  _cityField(_city, l10n.partnerCity),
                if (widget.type == 'transfer') ...[
                  _cityField(_pickupLocation, l10n.transferPickupLabel),
                  _cityField(_dropoffLocation, l10n.transferDropoffLabel),
                  _dateTimeField(_transferPickupTime, l10n.transferDate),
                ],
                _field(_country, l10n.partnerCountry, readOnly: true),
                _field(_description, l10n.partnerDescription, maxLines: 3),
                if (widget.type != 'flight')
                  _field(_image, l10n.partnerImageUrl,
                      keyboardType: TextInputType.url),
                _field(
                  _price,
                  widget.type == 'flight'
                      ? l10n.partnerTicketPrice
                      : l10n.partnerPrice,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                ..._buildServiceFields(l10n),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.partnerCancel)),
        FilledButton(onPressed: _save, child: Text(l10n.partnerSave)),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? helperText,
    FormFieldValidator<String>? validator,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          readOnly: readOnly,
          decoration: _listingInputDecoration(
            labelText: label,
            helperText: helperText,
          ),
          validator: (value) {
            if (required && (value == null || value.trim().isEmpty)) {
              return AppLocalizations.of(context).partnerRequiredField;
            }
            return validator?.call(value);
          },
        ),
      );

  List<Widget> _buildServiceFields(AppLocalizations l10n) {
    final keys = _editableAttributeKeys(widget.type)
        .where((key) => !_hiddenAttributeKeys(widget.type).contains(key))
        .toList();
    return [
      for (final key in keys)
        if (_booleanAttributeKeys.contains(key))
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_attributeLabel(key, l10n)),
            value: _booleanAttributes[key] ?? false,
            onChanged: (value) =>
                setState(() => _booleanAttributes[key] = value),
          )
        else
          _field(
            _attributeFields[key]!,
            _attributeLabel(key, l10n),
            keyboardType: _numericAttributeKeys.contains(key)
                ? const TextInputType.numberWithOptions(decimal: true)
                : null,
            maxLines: _listAttributeKeys.contains(key) ? 2 : 1,
            required: _requiredAttributeKeys.contains(key),
            helperText: _listAttributeKeys.contains(key)
                ? l10n.partnerCommaSeparatedHint
                : null,
            validator: _numericAttributeKeys.contains(key)
                ? (value) => _validateNumericAttribute(key, value, l10n)
                : null,
          ),
    ];
  }

  InputDecoration _listingInputDecoration({
    required String labelText,
    String? helperText,
    Widget? suffixIcon,
  }) {
    if (widget.type != 'flight') {
      return InputDecoration(
        filled: false,
        labelText: labelText,
        helperText: helperText,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      );
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
    return InputDecoration(
      filled: true,
      fillColor:
          isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
      labelText: labelText,
      helperText: helperText,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  String _attributeLabel(String key, AppLocalizations l10n) => switch (key) {
        'seats_available' => l10n.partnerSeatsAvailable,
        'seat_class' => l10n.partnerSeatClass,
        'business_price' => l10n.partnerBusinessPrice,
        'address' => l10n.partnerAddress,
        'stars' => l10n.partnerStars,
        'rating' => l10n.partnerRating,
        'review_count' => l10n.partnerReviewCount,
        'amenities' => l10n.partnerAmenities,
        'brand' => l10n.partnerBrand,
        'model' => l10n.partnerModel,
        'category' => l10n.partnerCategory,
        'year' => l10n.partnerYear,
        'seats' => l10n.partnerSeats,
        'transmission' => l10n.partnerTransmission,
        'fuel_type' => l10n.partnerFuelType,
        'features' => l10n.partnerFeatures,
        'has_ac' => l10n.partnerAirConditioning,
        'has_gps' => l10n.partnerGps,
        'opening_hours' => l10n.partnerOpeningHours,
        'latitude' => l10n.partnerLatitude,
        'longitude' => l10n.partnerLongitude,
        'tags' => l10n.partnerTags,
        'vehicle_type' => l10n.partnerVehicleType,
        'max_passengers' => l10n.partnerMaxPassengers,
        'max_luggage' => l10n.partnerMaxLuggage,
        'duration_minutes' => l10n.partnerDurationMinutes,
        'included_services' => l10n.partnerIncludedServices,
        'duration_nights' => l10n.partnerDurationNights,
        'highlights' => l10n.partnerHighlights,
        _ => key.replaceAll('_', ' '),
      };

  String? _validateNumericAttribute(
    String key,
    String? value,
    AppLocalizations l10n,
  ) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty && _optionalAttributeKeys.contains(key)) return null;
    final number = num.tryParse(trimmed);
    if (number == null) return l10n.partnerInvalidServiceField;
    if (key == 'stars' && (number < 1 || number > 5)) {
      return l10n.partnerInvalidServiceField;
    }
    if (key == 'rating' && (number < 0 || number > 5)) {
      return l10n.partnerInvalidServiceField;
    }
    if (key == 'latitude' && (number < -90 || number > 90)) {
      return l10n.partnerInvalidServiceField;
    }
    if (key == 'longitude' && (number < -180 || number > 180)) {
      return l10n.partnerInvalidServiceField;
    }
    if (number < 0 ||
        (_integerAttributeKeys.contains(key) && number != number.round())) {
      return l10n.partnerInvalidServiceField;
    }
    if (const {'seats_available', 'seats', 'max_passengers'}.contains(key) &&
        number < 1) {
      return l10n.partnerInvalidServiceField;
    }
    if (const {'year', 'duration_nights', 'duration_minutes'}.contains(key) &&
        number < 1) {
      return l10n.partnerInvalidServiceField;
    }
    return null;
  }

  static String _attributeFieldValue(Object? value) {
    if (value == null) return '';
    if (value is List) return value.join(', ');
    return value.toString();
  }

  static Object? _parseAttributeValue(String key, String value) {
    final trimmed = value.trim();
    if (_listAttributeKeys.contains(key)) {
      return trimmed.isEmpty
          ? <String>[]
          : trimmed
              .split(',')
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList();
    }
    if (_numericAttributeKeys.contains(key)) {
      if (trimmed.isEmpty && _optionalAttributeKeys.contains(key)) return null;
      final parsed = num.parse(trimmed);
      return _integerAttributeKeys.contains(key) ? parsed.toInt() : parsed;
    }
    return trimmed;
  }

  Widget _dateTimeField(
    TextEditingController controller,
    String label,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _pickDateTime(controller),
          decoration: _listingInputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? AppLocalizations.of(context).partnerRequiredField
              : null,
        ),
      );

  Widget _airportField({
    required TextEditingController controller,
    required TextEditingController codeController,
    required String label,
  }) {
    var query = '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Autocomplete<AirportOption>(
        displayStringForOption: (airport) => airport.label,
        initialValue: TextEditingValue(
          text: controller.text.isEmpty
              ? ''
              : '${controller.text} [${codeController.text}]',
        ),
        optionsBuilder: (value) => AirportOption.supported
            .where((airport) => airport.matches(value.text)),
        onSelected: (airport) {
          controller.text = airport.city;
          codeController.text = airport.code;
          if (identical(controller, _originCity)) {
            _country.text = airport.country;
          }
          setState(() => _error = null);
        },
        fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
          return TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            onChanged: (value) {
              query = value;
              final airport = _airportFromInput(value, codeController.text);
              controller.text = airport?.city ?? value;
              if (airport == null) {
                codeController.clear();
              } else {
                codeController.text = airport.code;
              }
            },
            decoration: _listingInputDecoration(labelText: label),
            validator: (value) => _airportFromInput(
                          value ?? '',
                          codeController.text,
                        ) ==
                        null &&
                    _airportFromInput(
                          controller.text,
                          codeController.text,
                        ) ==
                        null
                ? AppLocalizations.of(context).partnerRequiredField
                : null,
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options
                    .map((airport) => ListTile(
                          title:
                              Text.rich(_highlightMatch(airport.label, query)),
                          subtitle: Text.rich(
                              _highlightMatch(airport.airportName, query)),
                          onTap: () => onSelected(airport),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cityField(TextEditingController controller, String label) {
    var query = '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Autocomplete<AirportOption>(
        displayStringForOption: (airport) => airport.city,
        initialValue: TextEditingValue(text: controller.text),
        optionsBuilder: (value) => AirportOption.supported
            .where((airport) => airport.matches(value.text)),
        onSelected: (airport) {
          controller.text = airport.city;
          if (identical(controller, _city) ||
              identical(controller, _pickupLocation)) {
            _country.text = airport.country;
          }
          setState(() => _error = null);
        },
        fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
          return TextFormField(
            controller: fieldController,
            focusNode: focusNode,
            onChanged: (value) {
              query = value;
              controller.text = value;
              if (identical(controller, _city) ||
                  identical(controller, _pickupLocation)) {
                final location = AirportOption.byCity(value);
                if (location != null) _country.text = location.country;
              }
            },
            decoration: _listingInputDecoration(labelText: label),
            validator: (value) => value == null || !_isRegisteredCity(value)
                ? AppLocalizations.of(context).partnerRequiredField
                : null,
          );
        },
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: options
                    .map((airport) => ListTile(
                          title:
                              Text.rich(_highlightMatch(airport.label, query)),
                          subtitle: Text.rich(
                              _highlightMatch(airport.airportName, query)),
                          onTap: () => onSelected(airport),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _highlightMatch(String value, String query) {
    final normalizedQuery = query.trim();
    final start = value.toLowerCase().indexOf(normalizedQuery.toLowerCase());
    if (normalizedQuery.isEmpty || start < 0) return TextSpan(text: value);
    final end = start + normalizedQuery.length;
    return TextSpan(children: [
      TextSpan(text: value.substring(0, start)),
      TextSpan(
        text: value.substring(start, end),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      TextSpan(text: value.substring(end)),
    ]);
  }

  Future<void> _pickDateTime(TextEditingController controller) async {
    final current = _parseDateTimeField(controller.text) ??
        DateTime.now().add(const Duration(days: 14));
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    controller.text = DateFormat('yyyy-MM-dd HH:mm').format(value);
    setState(() => _error = null);
  }

  static String _dateTimeFieldValue(Object? value) {
    final dateTime = _parseDateTimeField('$value');
    return dateTime == null
        ? ''
        : DateFormat('yyyy-MM-dd HH:mm').format(dateTime);
  }

  static DateTime? _parseDateTimeField(String value) =>
      DateTime.tryParse(value.trim().replaceFirst(' ', 'T'));

  static bool _isRegisteredCity(String city) =>
      AirportOption.byCity(city) != null;

  static AirportOption? _airportFromInput(String input, String code) {
    final value = input.trim();
    final match = RegExp(r'^(.*?)\s*\[([A-Za-z]{3})\]$').firstMatch(value);
    final city = match?.group(1)?.trim() ?? value;
    final displayedCode = match?.group(2)?.toUpperCase();
    final airport = displayedCode == null
        ? AirportOption.byCity(city)
        : AirportOption.byCode(displayedCode);
    if (airport == null || airport.city.toLowerCase() != city.toLowerCase()) {
      return null;
    }
    final normalizedCode = code.trim().toUpperCase();
    return normalizedCode.isEmpty || normalizedCode == airport.code
        ? airport
        : null;
  }

  static String _destinationFromTitle(String? title) {
    if (title == null) return '';
    final separator = title.toLowerCase().indexOf(' to ');
    return separator < 0 ? '' : title.substring(separator + 4).trim();
  }

  static const _generatedAttributeKeys = {
    'listing_code',
    'flight_number',
    'airline_code',
    'status',
    'is_active',
  };

  static const _numericAttributeKeys = {
    'seats_available',
    'business_price',
    'stars',
    'rating',
    'review_count',
    'latitude',
    'longitude',
    'year',
    'seats',
    'max_passengers',
    'max_luggage',
    'duration_nights',
    'duration_minutes',
  };

  static const _integerAttributeKeys = {
    'seats_available',
    'stars',
    'review_count',
    'year',
    'seats',
    'max_passengers',
    'max_luggage',
    'duration_nights',
  };

  static const _optionalAttributeKeys = {
    'business_price',
    'latitude',
    'longitude',
  };

  static const _listAttributeKeys = {
    'amenities',
    'features',
    'tags',
    'included_services',
    'highlights',
  };

  static const _booleanAttributeKeys = {'has_ac', 'has_gps'};
  static const _deferredFlightAttributeKeys = {'is_direct', 'stops'};

  static const _requiredAttributeKeys = {
    'seats_available',
    'seat_class',
    'duration_minutes',
    'stars',
    'brand',
    'model',
    'category',
    'year',
    'seats',
    'transmission',
    'fuel_type',
    'vehicle_type',
    'duration_nights',
  };

  static Set<String> _editableAttributeKeys(String type) =>
      _starterAttributes(type).keys.toSet();

  static Set<String> _hiddenAttributeKeys(String type) => switch (type) {
        'flight' => {
            'origin_city',
            'origin_code',
            'destination_city',
            'destination_code',
            'departure_time',
            'arrival_time',
          },
        'transfer' => {
            'pickup_location',
            'dropoff_location',
            'pickup_time',
          },
        _ => <String>{},
      };

  static Map<String, dynamic> _starterAttributes(String type) => switch (type) {
        'flight' => {
            'origin_city': '',
            'origin_code': '',
            'destination_city': '',
            'destination_code': '',
            'departure_time': '',
            'arrival_time': '',
            'duration_minutes': 120,
            'seat_class': 'Economy',
            'seats_available': 100,
            'business_price': null,
          },
        'hotel' => {
            'address': '',
            'stars': 3,
            'rating': 0,
            'review_count': 0,
            'amenities': <String>[],
            'latitude': null,
            'longitude': null,
          },
        'car' => {
            'brand': '',
            'model': '',
            'category': 'economy',
            'year': DateTime.now().year,
            'seats': 4,
            'transmission': 'automatic',
            'fuel_type': 'gasoline',
            'features': <String>[],
            'rating': 0,
            'has_ac': true,
            'has_gps': false,
          },
        'attraction' => {
            'category': 'landmark',
            'rating': 0,
            'review_count': 0,
            'tags': <String>[],
            'opening_hours': '',
            'latitude': 0,
            'longitude': 0,
          },
        'transfer' => {
            'vehicle_type': 'sedan',
            'max_passengers': 4,
            'max_luggage': 2,
            'pickup_location': '',
            'dropoff_location': '',
            'pickup_time': '',
            'duration_minutes': 60,
            'included_services': <String>[],
          },
        'package' => {
            'duration_nights': 3,
            'category': 'city',
            'highlights': <String>[],
          },
        _ => <String, dynamic>{},
      };
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 14),
              Text(value,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: child,
    );
  }
}
