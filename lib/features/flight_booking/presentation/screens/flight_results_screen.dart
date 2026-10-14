import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../features/price_alerts/logic/price_alerts_store.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/flight_model.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/flight_controller.dart';

class FlightResultsScreen extends StatefulWidget {
  const FlightResultsScreen({super.key});

  @override
  State<FlightResultsScreen> createState() => _FlightResultsScreenState();
}

class _FlightResultsScreenState extends State<FlightResultsScreen> {
  FlightController? _ctrl;
  bool _priceCheckDone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= ModalRoute.of(context)?.settings.arguments as FlightController?;
    if (!_priceCheckDone && _ctrl != null) {
      _priceCheckDone = true;
      PriceAlertsStore.instance.checkResults(_ctrl!.results,
          promoTitle: AppLocalizations.of(context).notifPriceDropTitle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final ctrl = _ctrl;
    if (ctrl == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${ctrl.searchParams?.originCode ?? ''} → ${ctrl.searchParams?.destinationCode ?? ''}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: ListenableBuilder(
            listenable: ctrl,
            builder: (_, __) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  _SortChip(
                      label: l10n.cheapest,
                      selected: ctrl.sort == FlightSort.cheapest,
                      onTap: () => ctrl.setSort(FlightSort.cheapest)),
                  const SizedBox(width: 8),
                  _SortChip(
                      label: l10n.fastest,
                      selected: ctrl.sort == FlightSort.fastest,
                      onTap: () => ctrl.setSort(FlightSort.fastest)),
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (_, __) {
          if (ctrl.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (ctrl.results.isEmpty) {
            return Center(child: Text(l10n.flightNoResults));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: ctrl.results.length,
            itemBuilder: (_, i) => _FlightCard(
              flight: ctrl.results[i],
              isDark: isDark,
              l10n: l10n,
              onSelect: () {
                ctrl.selectFlight(ctrl.results[i]);
                Navigator.pushNamed(context, AppRoutes.flightBooking,
                    arguments: ctrl);
              },
            )
                .animate(delay: Duration(milliseconds: 80 * i))
                .fade()
                .slideY(begin: 0.05, end: 0),
          );
        },
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13)),
      ),
    );
  }
}

class _FlightCard extends StatefulWidget {
  final FlightModel flight;
  final bool isDark;
  final VoidCallback onSelect;
  final AppLocalizations l10n;
  const _FlightCard(
      {required this.flight,
      required this.isDark,
      required this.onSelect,
      required this.l10n});

  @override
  State<_FlightCard> createState() => _FlightCardState();
}

class _FlightCardState extends State<_FlightCard> {
  FlightModel get flight => widget.flight;
  bool get isDark => widget.isDark;
  AppLocalizations get l10n => widget.l10n;
  VoidCallback get onSelect => widget.onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(flight.airline,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.primary)),
              Row(children: [
                ListenableBuilder(
                  listenable: PriceAlertsStore.instance,
                  builder: (_, __) {
                    final tracking = PriceAlertsStore.instance.isTracking(
                        flight.originCode,
                        flight.destinationCode,
                        flight.departureTime);
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        if (tracking) {
                          await PriceAlertsStore.instance.untrack(
                              flight.originCode,
                              flight.destinationCode,
                              flight.departureTime);
                        } else {
                          await PriceAlertsStore.instance.track(
                            originCode: flight.originCode,
                            destinationCode: flight.destinationCode,
                            departureDate: flight.departureTime,
                            priceUsd: flight.economyPrice,
                          );
                        }
                      },
                      child: Icon(
                          tracking
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          size: 20,
                          color: tracking
                              ? AppColors.accentOrange
                              : AppColors.textSecondary),
                    );
                  },
                ),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(children: [
                Text(
                    '${flight.departureTime.hour.toString().padLeft(2, '0')}:${flight.departureTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
                Text(flight.originCode,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
              Expanded(
                child: Column(children: [
                  Text(flight.duration,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Row(children: [
                    Expanded(
                        child: Container(height: 1.5, color: AppColors.border)),
                    const Icon(Icons.flight_rounded,
                        color: AppColors.primary, size: 18),
                    Expanded(
                        child: Container(height: 1.5, color: AppColors.border)),
                  ]),
                ]),
              ),
              Column(children: [
                Text(
                    '${flight.arrivalTime.hour.toString().padLeft(2, '0')}:${flight.arrivalTime.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800)),
                Text(flight.destinationCode,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ]),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.seatsLeft(flight.seatsAvailable),
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.accentRed,
                      fontWeight: FontWeight.w600)),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('\$',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
                Text(flight.economyPrice.toStringAsFixed(0),
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary)),
                Text(l10n.perPerson,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSelect,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
              child: Text(l10n.flightSelectThis),
            ),
          ),
        ],
      ),
    );
  }
}
