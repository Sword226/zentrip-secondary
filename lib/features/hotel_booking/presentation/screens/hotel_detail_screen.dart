import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../global_widgets/app_shell.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_load_error.dart';
import '../../../../global_widgets/payment_checkout_screen.dart';
import '../../../../features/notifications/logic/notifications_store.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/booking_model.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/hotel_controller.dart';

class HotelDetailScreen extends StatefulWidget {
  const HotelDetailScreen({super.key});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  HotelController? _ctrl;
  bool _isBooking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= ModalRoute.of(context)?.settings.arguments as HotelController?;
  }

  Future<void> _book() async {
    final l10n = AppLocalizations.of(context);
    final ctrl = _ctrl;
    final hotel = ctrl?.selectedHotel;
    if (hotel == null) {
      AppSnackbar.error(context, l10n.genericError);
      return;
    }
    final checkIn = ctrl?.searchParams?.checkIn ?? DateTime.now();
    final checkOut =
        ctrl?.searchParams?.checkOut ?? checkIn.add(const Duration(days: 1));
    final availability = await ApiService.instance.checkBookingAvailability(
      type: BookingType.hotel,
      title: hotel.name,
      startDate: checkIn,
      endDate: checkOut,
    );
    if (!mounted) return;
    if (availability.isFailure || availability.data != true) {
      AppSnackbar.error(
        context,
        availability.isFailure
            ? availability.errorMessage ?? l10n.genericError
            : l10n.bookingScheduleConflict,
      );
      return;
    }
    final nights = ctrl?.searchParams?.nights ?? 1;
    final totalPrice = hotel.pricePerNight * nights * 1.12;
    final ref =
        'ZT-H-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

    final paid = await PaymentCheckoutScreen.start(context,
        amountUsd: totalPrice, description: hotel.name, referenceId: ref);
    if (!mounted) return;
    if (!paid) {
      AppSnackbar.error(context, l10n.paymentFailedMessage);
      return;
    }

    setState(() => _isBooking = true);
    await Future.delayed(const Duration(seconds: 1));
    final booking = BookingModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: BookingType.hotel,
      title: hotel.name,
      subtitle: hotel.address,
      date: checkIn,
      endDate: checkOut,
      price: totalPrice,
      refCode: ref,
      status: 'upcoming',
      imageUrl: hotel.imageUrl,
      partnerListingId: hotel.partnerListingId,
    );
    final createResult = await ApiService.instance.createBooking(booking);
    if (createResult.isFailure) {
      if (!mounted) return;
      setState(() => _isBooking = false);
      AppSnackbar.error(
        context,
        createResult.errorMessage == 'BOOKING_SCHEDULE_CONFLICT'
            ? l10n.bookingScheduleConflict
            : createResult.errorMessage ?? l10n.genericError,
      );
      return;
    }
    setState(() => _isBooking = false);
    if (!mounted) return;
    AppSnackbar.success(context, l10n.hotelBookingSuccess);
    await NotificationsStore.instance.add(
        kind: NotifKind.booking,
        title: l10n.notifBookingConfirmedTitle,
        subtitle: hotel.name);
    if (!mounted) return;
    AppShellTabController.goToTab(3); // تاب "رحلاتي" — عشان يشوف حجزه فورًا
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final ctrl = _ctrl;
    final hotel = ctrl?.selectedHotel;
    final nights = ctrl?.searchParams?.nights ?? 1;
    if (hotel == null) return const BookingLoadError();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(hotel.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      shadows: [Shadow(blurRadius: 8)])),
              background: AppNetworkImage(
                url: hotel.imageUrl,
                fallbackIcon: Icons.hotel_rounded,
                fallbackGradient: AppColors.destinationGradients[
                    hotel.id.hashCode.abs() %
                        AppColors.destinationGradients.length],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Location + rating
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        const Icon(Icons.place_rounded,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(hotel.address,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ]),
                      Row(children: [
                        ...List.generate(
                            hotel.starRating,
                            (_) => const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 14)),
                        const SizedBox(width: 6),
                        Text('${hotel.rating} (${hotel.reviewCount})',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ]).animate().fade(duration: 300.ms),
                const SizedBox(height: 16),
                // Amenities
                Text(l10n.hotelAmenities,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: hotel.amenities
                      .map((a) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                                color: AppColors.primarySurface,
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(a,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ).animate().fade(delay: 100.ms),
                const SizedBox(height: 20),
                // Description
                Text(l10n.hotelAbout,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                        hotel.description.isEmpty
                            ? l10n.hotelDefaultDescription
                            : hotel.description,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(height: 1.7))
                    .animate()
                    .fade(delay: 150.ms),
                const SizedBox(height: 20),
                // Price summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            isDark ? AppColors.darkBorder : AppColors.border),
                  ),
                  child: Column(children: [
                    _Row(l10n.hotelNightPrice,
                        '\$${hotel.pricePerNight.toStringAsFixed(0)}'),
                    _Row(l10n.hotelNightsCount, l10n.hotelNightsValue(nights)),
                    _Row(l10n.hotelTaxesFees,
                        '\$${(hotel.pricePerNight * nights * 0.12).toStringAsFixed(0)}'),
                    const Divider(height: 20),
                    _Row(l10n.hotelTotal,
                        '\$${(hotel.pricePerNight * nights * 1.12).toStringAsFixed(0)}',
                        isBold: true, color: AppColors.primary),
                  ]),
                ).animate().fade(delay: 200.ms),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: _isBooking ? null : _book,
                  icon: _isBooking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.hotel_rounded),
                  label: Text(_isBooking
                      ? l10n.hotelBookingInProgress
                      : l10n.hotelBookNow),
                ).animate().fade(delay: 280.ms),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label, value;
  final bool isBold;
  final Color? color;
  const _Row(this.label, this.value, {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
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
