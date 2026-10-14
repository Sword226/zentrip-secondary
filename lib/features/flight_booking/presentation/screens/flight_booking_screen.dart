import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../global_widgets/app_shell.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_load_error.dart';
import '../../../../global_widgets/payment_checkout_screen.dart';
import '../../../../features/notifications/logic/notifications_store.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/trip_model.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/flight_controller.dart';

class FlightBookingScreen extends StatefulWidget {
  const FlightBookingScreen({super.key});

  @override
  State<FlightBookingScreen> createState() => _FlightBookingScreenState();
}

class _FlightBookingScreenState extends State<FlightBookingScreen> {
  FlightController? _ctrl;
  bool _isBooking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= ModalRoute.of(context)?.settings.arguments as FlightController?;
  }

  Future<void> _book() async {
    if (_isBooking) return;
    final l10n = AppLocalizations.of(context);
    final flight = _ctrl?.selectedFlight;
    if (flight == null) {
      AppSnackbar.error(context, l10n.genericError);
      return;
    }
    setState(() => _isBooking = true);
    final availability = await ApiService.instance.checkFlightAvailability(
      departureDate: flight.departureTime,
      arrivalDate: flight.arrivalTime,
      returnDate: _ctrl?.searchParams?.returnDate,
    );
    if (!mounted) return;
    if (availability.isFailure || availability.data != true) {
      setState(() => _isBooking = false);
      AppSnackbar.error(
        context,
        availability.isFailure
            ? availability.errorMessage ?? l10n.genericError
            : l10n.flightScheduleConflict,
      );
      return;
    }
    await Future.delayed(const Duration(seconds: 2)); // simulate API
    if (!mounted) return;
    final ref =
        'ZT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    final totalPrice = flight.economyPrice * 1.12 + 12;
    setState(() => _isBooking = false);

    final paid = await PaymentCheckoutScreen.start(context,
        amountUsd: totalPrice,
        description: flight.flightNumber,
        referenceId: ref);
    if (!mounted) return;
    if (!paid) {
      AppSnackbar.error(context, l10n.paymentFailedMessage);
      return;
    }
    setState(() => _isBooking = true);

    final trip = TripModel(
      id: DateTime.now().millisecondsSinceEpoch,
      originCode: flight.originCode,
      originCity: flight.originCity,
      destinationCode: flight.destinationCode,
      destinationCity: flight.destinationCity,
      departureDate: flight.departureTime,
      arrivalDate: flight.arrivalTime,
      returnDate: _ctrl?.searchParams?.returnDate,
      flightNumber: flight.flightNumber,
      airline: flight.airline,
      airlineLogoUrl: flight.airlineLogoUrl,
      isDirect: flight.isDirect,
      seatClass: _ctrl?.searchParams?.seatClass ?? 'Economy',
      price: totalPrice,
      bookingRef: ref,
      status: 'upcoming',
      partnerListingId: flight.partnerListingId,
    );
    final createResult = await ApiService.instance.createFlightTrip(trip);
    if (createResult.isFailure) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      AppSnackbar.error(
          context,
          createResult.errorMessage == 'FLIGHT_SCHEDULE_CONFLICT'
              ? l10n.flightScheduleConflict
              : createResult.errorMessage ?? l10n.genericError);
      return;
    }
    if (!mounted) return;
    setState(() => _isBooking = false);
    AppSnackbar.success(context, l10n.flightBookingSuccess(ref));
    await NotificationsStore.instance.add(
      kind: NotifKind.booking,
      title: l10n.notifBookingConfirmedTitle,
      subtitle: '${flight.originCode} → ${flight.destinationCode}',
    );
    if (!mounted) return;
    AppShellTabController.goToTab(3); // تاب "رحلاتي"
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final ctrl = _ctrl;
    final flight = ctrl?.selectedFlight;
    final user = ApiService.instance.currentUser;
    if (flight == null) return const BookingLoadError();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.flightConfirmBookingTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Flight summary ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(flight.originCode,
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text(flight.originCity,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12)),
                          ]),
                      Column(children: [
                        const Icon(Icons.flight_rounded,
                            color: Colors.white, size: 20),
                        Container(
                            width: 80,
                            height: 1.5,
                            color: Colors.white.withValues(alpha: 0.3),
                            margin: const EdgeInsets.symmetric(vertical: 4)),
                      ]),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(flight.destinationCode,
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                            Text(flight.destinationCity,
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12)),
                          ]),
                    ]),
                const SizedBox(height: 14),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(flight.airline,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      Text(flight.flightNumber,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8))),
                      Text(flight.duration,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8))),
                    ]),
              ]),
            ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 20),

            // ── Passenger info ────────────────────────────────────────
            _Section(
                title: l10n.flightPassengerInfo,
                isDark: isDark,
                children: [
                  _InfoRow(l10n.nameLabel, user?.name ?? l10n.flightDemoUser),
                  _InfoRow(l10n.emailLabel, user?.email ?? 'demo@zentrip.app'),
                  _InfoRow(l10n.phoneLabel, user?.phone ?? '+201000000000'),
                ]).animate().fade(delay: 150.ms),
            const SizedBox(height: 16),

            // ── Price breakdown ───────────────────────────────────────
            _Section(title: l10n.flightPriceDetails, isDark: isDark, children: [
              _InfoRow(l10n.flightTicketPrice,
                  '\$${flight.economyPrice.toStringAsFixed(0)}'),
              _InfoRow(l10n.flightTaxesFees,
                  '\$${(flight.economyPrice * 0.12).toStringAsFixed(0)}'),
              _InfoRow(l10n.flightServiceFee, '\$12'),
              const Divider(),
              _InfoRow(l10n.flightTotal,
                  '\$${(flight.economyPrice * 1.12 + 12).toStringAsFixed(0)}',
                  isBold: true, color: AppColors.primary),
            ]).animate().fade(delay: 220.ms),
            const SizedBox(height: 28),

            // ── Book now ──────────────────────────────────────────────
            ElevatedButton.icon(
              onPressed: _isBooking ? null : _book,
              icon: _isBooking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_isBooking
                  ? l10n.flightBookingInProgress
                  : l10n.flightConfirmComplete),
            ).animate().fade(delay: 300.ms),
            const SizedBox(height: 10),
            Text(l10n.flightTermsNotice,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;
  const _Section(
      {required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(children: children),
      ),
    ]);
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  const _InfoRow(this.label, this.value, {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: isBold ? 16 : 14,
                  color: color)),
        ],
      ),
    );
  }
}
