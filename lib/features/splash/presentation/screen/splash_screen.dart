import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../features/favorites/logic/favorites_controller.dart';
import '../../../../features/notifications/logic/notifications_store.dart';
import '../../../../features/price_alerts/logic/price_alerts_store.dart';
import '../../../../global_widgets/app_logo.dart';
import '../../../../global_widgets/flight_path_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../routes/app_routes.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // مدة عرض شاشة الـ Splash قبل الانتقال التلقائي.
    const splashDuration = Duration(seconds: 4);
    final results = await Future.wait([
      Future.delayed(splashDuration),
      ApiService.instance.restoreSession(),
      SharedPreferences.getInstance()
          .then((p) => p.getBool(OnboardingScreen.seenKey) ?? false),
    ]);

    if (!mounted) return;
    final hasSession = results[1] as bool;
    final hasSeenOnboarding = results[2] as bool;

    if (hasSession) {
      // في main() حمّلنا المفضلة قبل ما نعرف مين المستخدم (كانت لسه
      // 'guest'). دلوقتي عرفنا هويته بعد استعادة الجلسة، فنعيد التحميل
      // ببيانات حسابه هو بالذات.
      await FavoritesController.instance.load();
      await NotificationsStore.instance.load();
      await PriceAlertsStore.instance.load();
      if (!mounted) return;
      final user = ApiService.instance.currentUser;
      final destination = user?.isAdmin == true
          ? AppRoutes.adminDashboard
          : user?.isPartner == true
              ? AppRoutes.partnerDashboard
              : AppRoutes.home;
      Navigator.pushReplacementNamed(context, destination);
    } else if (!hasSeenOnboarding) {
      Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        child: Stack(
          children: [
            const TakeoffPlaneAnimation(),
            // بقع ضوئية خلفية
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            // المحتوى المركزي
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 72, showBackground: true)
                      .animate()
                      .fade(duration: 800.ms)
                      .scale(
                          delay: 200.ms,
                          duration: 600.ms,
                          curve: Curves.easeOutBack),
                  const SizedBox(height: 28),
                  Text(
                    'Zentrip',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 3,
                    ),
                  )
                      .animate()
                      .fade(delay: 500.ms, duration: 500.ms)
                      .slideY(begin: 0.3, end: 0),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).welcomeTitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                  ).animate().fade(delay: 800.ms, duration: 500.ms),
                  const SizedBox(height: 80),
                  // Loading indicator
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ).animate().fade(delay: 1200.ms),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
