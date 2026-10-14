import 'package:flutter/material.dart';
import '../features/splash/presentation/screen/splash_screen.dart';
import '../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/verify_code_screen.dart';
import '../features/auth/presentation/screens/reset_password_screen.dart';
import '../features/auth/presentation/screens/login_success_screen.dart';
import '../features/trips/presentation/screens/trip_details_screen.dart';
import '../features/trips/presentation/screens/search_flights_screen.dart';
import '../features/trips/presentation/screens/search_hotels_screen.dart';
import '../features/trips/presentation/screens/package_detail_screen.dart';
import '../features/flight_booking/presentation/screens/flight_search_screen.dart';
import '../features/flight_booking/presentation/screens/flight_results_screen.dart';
import '../features/flight_booking/presentation/screens/flight_booking_screen.dart';
import '../features/hotel_booking/presentation/screens/hotel_search_screen.dart';
import '../features/hotel_booking/presentation/screens/hotel_results_screen.dart';
import '../features/hotel_booking/presentation/screens/hotel_detail_screen.dart';
import '../features/car_rental/presentation/screens/car_rental_screen.dart';
import '../features/car_rental/presentation/screens/car_detail_screen.dart';
import '../features/attractions/presentation/screens/attractions_screen.dart';
import '../features/attractions/presentation/screens/attraction_detail_screen.dart';
import '../features/home/presentation/screens/packages_list_screen.dart';
import '../features/transfers/presentation/screens/transfers_screen.dart';
import '../features/profile/presentation/screens/terms_screen.dart';
import '../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../features/admin/presentation/screens/partner_dashboard_screen.dart';
import '../global_widgets/app_shell.dart';
import '../models/travel_package_model.dart';
import '../models/trip_model.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String auth = '/auth';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verifyCode = '/verify-code';
  static const String resetPassword = '/reset-password';
  static const String loginSuccess = '/login-success';
  static const String home = '/home';
  static const String tripDetails = '/trip-details';
  static const String searchFlights = '/search-flights';
  static const String searchHotels = '/search-hotels';
  static const String packageDetail = '/package-detail';
  static const String flightSearch = '/flight-search';
  static const String flightResults = '/flight-results';
  static const String flightBooking = '/flight-booking';
  static const String hotelSearch = '/hotel-search';
  static const String hotelResults = '/hotel-results';
  static const String hotelDetail = '/hotel-detail';
  static const String carRental = '/car-rental';
  static const String carDetail = '/car-detail';
  static const String attractions = '/attractions';
  static const String attractionDetail = '/attraction-detail';
  static const String packagesList = '/packages-list';
  static const String transfers = '/transfers';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String adminDashboard = '/admin-dashboard';
  static const String partnerDashboard = '/partner-dashboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fade(const SplashScreen(), settings);
      case onboarding:
        return _slide(const OnboardingScreen(), settings);
      case auth:
        return _fade(const AuthScreen(), settings);
      case register:
        return _slide(const RegisterScreen(), settings);
      case forgotPassword:
        return _slide(const ForgotPasswordScreen(), settings);
      case verifyCode:
        return _slide(const VerifyCodeScreen(), settings);
      case resetPassword:
        return _slide(const ResetPasswordScreen(), settings);
      case loginSuccess:
        return _fade(const LoginSuccessScreen(), settings);
      case home:
        return _fade(const AppShell(), settings);
      case tripDetails:
        final trip = settings.arguments as TripModel;
        return _slide(TripDetailsScreen(trip: trip), settings);
      case searchFlights:
        return _slide(const SearchFlightsScreen(), settings);
      case searchHotels:
        return _slide(const SearchHotelsScreen(), settings);
      case packageDetail:
        final pkg = settings.arguments as TravelPackage;
        return _slide(PackageDetailScreen(package: pkg), settings);
      case flightSearch:
        return _slide(const FlightSearchScreen(), settings);
      case flightResults:
        return _slide(const FlightResultsScreen(), settings);
      case flightBooking:
        return _slide(const FlightBookingScreen(), settings);
      case hotelSearch:
        return _slide(const HotelSearchScreen(), settings);
      case hotelResults:
        return _slide(const HotelResultsScreen(), settings);
      case hotelDetail:
        return _slide(const HotelDetailScreen(), settings);
      case carRental:
        return _slide(const CarRentalScreen(), settings);
      case carDetail:
        return _slide(const CarDetailScreen(), settings);
      case attractions:
        return _slide(const AttractionsScreen(), settings);
      case attractionDetail:
        return _slide(const AttractionDetailScreen(), settings);
      case packagesList:
        final args = settings.arguments is PackagesListArgs
            ? settings.arguments as PackagesListArgs
            : const PackagesListArgs(kind: PackagesListKind.ideas);
        return _slide(PackagesListScreen(args: args), settings);
      case transfers:
        return _slide(const TransfersScreen(), settings);
      case terms:
        return _slide(const TermsScreen(), settings);
      case privacy:
        return _slide(const TermsScreen(showPrivacy: true), settings);
      case adminDashboard:
        return _fade(const AdminDashboardScreen(), settings);
      case partnerDashboard:
        return _fade(const PartnerDashboardScreen(), settings);
      default:
        return _fade(const SplashScreen(), settings);
    }
  }

  // ملحوظة: لازم نمرر settings هنا وإلا أي بيانات مبعوتة عن طريق
  // Navigator.pushNamed(..., arguments: ...) هتضيع تمامًا، لأن الشاشة
  // اللي بتستقبلها بتقراها عن طريق ModalRoute.of(context)?.settings.arguments.
  static PageRouteBuilder _fade(Widget page, [RouteSettings? settings]) => PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      );

  static PageRouteBuilder _slide(Widget page, [RouteSettings? settings]) => PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: FadeTransition(opacity: animation, child: child),
        ),
      );
}
