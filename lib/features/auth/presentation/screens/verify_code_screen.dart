import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pinput/pinput.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/auth_controller.dart';
import '../widgets/primary_button.dart';

class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key});

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  static const int _resendCooldownSeconds = 60;
  static const int _maxAttempts = 3;

  final _auth = AuthController();
  final _pinController = TextEditingController();
  String _code = '';
  String? _email;

  int _secondsLeft = _resendCooldownSeconds;
  Timer? _timer;
  int _failedAttempts = 0;
  bool _locked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // الإيميل بييجي كـ argument من شاشة "نسيت كلمة المرور" — لازم للـ resend.
    _email ??= ModalRoute.of(context)?.settings.arguments as String?;
    _auth.pendingResetEmail = _email;
  }

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendCooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pinController.dispose();
    _auth.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_locked) return;
    if (_code.length < 6) {
      AppSnackbar.warning(context, AppLocalizations.of(context).commonEnterSixDigitCode);
      return;
    }
    final ok = await _auth.verifyResetCode(code: _code);
    if (!mounted) return;
    if (ok) {
      Navigator.pushNamed(context, AppRoutes.resetPassword);
      return;
    }

    _failedAttempts++;
    if (_failedAttempts >= _maxAttempts) {
      // بعد 3 محاولات خطأ: نقفل الحقل ونجبر المستخدم يطلب كود جديد.
      setState(() {
        _locked = true;
        _secondsLeft = 0; // فتح زرار "إعادة الإرسال" فورًا
      });
      _timer?.cancel();
      _pinController.clear();
      _code = '';
      AppSnackbar.error(context, AppLocalizations.of(context).tooManyAttempts);
    } else {
      final remaining = _maxAttempts - _failedAttempts;
      _pinController.clear();
      _code = '';
      AppSnackbar.error(context, AppLocalizations.of(context).codeInvalidWithAttempts(remaining));
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    if (_email == null || _email!.isEmpty) {
      // مفيش إيميل متاح (مثلاً لو الشاشة اتفتحت مباشرة بدون المرور بشاشة نسيت كلمة المرور).
      Navigator.pop(context);
      return;
    }
    final ok = await _auth.sendResetCode(email: _email!);
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, AppLocalizations.of(context).codeSentSuccess);
      setState(() {
        _locked = false;
        _failedAttempts = 0;
      });
      _pinController.clear();
      _code = '';
      _startCooldown();
    } else {
      AppSnackbar.error(context, _auth.errorMessage ?? AppLocalizations.of(context).genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final defaultTheme = PinTheme(
      width: 54, height: 58,
      textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );
    final canResend = _secondsLeft == 0;

    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
              child: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 36),
            ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(l10n.verifyCodeTitle, style: Theme.of(context).textTheme.headlineSmall)
                .animate().fade(delay: 150.ms),
            const SizedBox(height: 8),
            Text(l10n.verifyCodeSubtitle, style: Theme.of(context).textTheme.bodyMedium)
                .animate().fade(delay: 200.ms),
            if (ApiService.useMockMode) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.mockVerifyCodeHint, style: const TextStyle(fontSize: 11, color: AppColors.primary))),
                  ],
                ),
              ).animate().fade(delay: 240.ms),
            ],
            const SizedBox(height: 40),
            Center(
              child: Pinput(
                length: 6,
                controller: _pinController,
                enabled: !_locked,
                defaultPinTheme: defaultTheme,
                focusedPinTheme: defaultTheme.copyDecorationWith(
                  border: Border.all(color: AppColors.primary, width: 2),
                  color: AppColors.primarySurface,
                ),
                onChanged: (v) => _code = v,
                onCompleted: (_) => _verify(),
              ),
            ).animate().fade(delay: 280.ms),
            if (_locked) ...[
              const SizedBox(height: 12),
              Text(
                l10n.tooManyAttempts,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            ListenableBuilder(
              listenable: _auth,
              builder: (_, __) => PrimaryButton(
                label: l10n.verifyButton,
                isLoading: _auth.isLoading,
                onPressed: _locked ? null : _verify,
              ),
            ).animate().fade(delay: 360.ms),
            const SizedBox(height: 20),
            Center(
              child: ListenableBuilder(
                listenable: _auth,
                builder: (_, __) => TextButton(
                  onPressed: canResend && !_auth.isLoading ? _resend : null,
                  child: Text(
                    canResend ? l10n.resendCode : l10n.resendCodeIn(_secondsLeft),
                    style: TextStyle(color: canResend ? AppColors.primary : AppColors.textHint),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
