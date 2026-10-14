import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../global_widgets/app_logo.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/flight_path_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';
import 'login_success_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _authController = AuthController();
  bool _showPw = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _authController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _authController.login(
        email: _emailCtrl.text.trim(), password: _pwCtrl.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LoginSuccessScreen()));
    } else {
      AppSnackbar.error(
          context,
          _authController.errorMessage ??
              AppLocalizations.of(context).genericError);
    }
  }

  Future<void> _loginSocial(Future<bool> Function() action) async {
    final ok = await action();
    if (!mounted) return;
    if (ok) {
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const LoginSuccessScreen()));
    } else if ((_authController.errorMessage ?? '').isNotEmpty) {
      // لو errorMessage فاضية، معناها المستخدم لغى العملية بنفسه — مفيش
      // داعي نوريه رسالة خطأ عادية.
      AppSnackbar.error(context, _authController.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // ── Plane decoration ─────────────────────────────────────
                const StraightFlightPlane(height: 32, color: AppColors.primary),
                const SizedBox(height: 20),
                // ── Logo ─────────────────────────────────────────────────
                Center(
                  child: const AppLogo(size: 44, color: AppColors.primary)
                      .animate()
                      .fade(duration: 600.ms)
                      .scale(curve: Curves.easeOutBack),
                ),
                const SizedBox(height: 16),
                Text(l10n.loginWelcome,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium)
                    .animate()
                    .fade(delay: 200.ms),
                const SizedBox(height: 6),
                Text(l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium)
                    .animate()
                    .fade(delay: 300.ms),
                const SizedBox(height: 36),

                // ── Demo hint (يظهر فقط في وضع المحاكاة) ──────────────────
                if (ApiService.useMockMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(l10n.demoLoginHint,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.primary))),
                      ],
                    ),
                  ).animate().fade(delay: 400.ms),

                // ── Fields ───────────────────────────────────────────────
                AuthTextField(
                  controller: _emailCtrl,
                  label: l10n.emailLabel,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: Validators.emailValidator(
                      l10n.emailLabel, l10n.genericError),
                ).animate().fade(delay: 450.ms).slideY(begin: 0.1, end: 0),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: _pwCtrl,
                  label: l10n.passwordLabel,
                  icon: Icons.lock_outlined,
                  obscureText: !_showPw,
                  textInputAction: TextInputAction.done,
                  validator: Validators.passwordValidator(
                      l10n.passwordLabel, l10n.genericError),
                  onFieldSubmitted: (_) => _login(),
                  suffixIcon: IconButton(
                    icon: Icon(_showPw
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showPw = !_showPw),
                  ),
                ).animate().fade(delay: 500.ms).slideY(begin: 0.1, end: 0),

                // ── Forgot password ──────────────────────────────────────
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.forgotPassword),
                    child: Text(l10n.forgotPassword),
                  ),
                ),

                // ── Login button ─────────────────────────────────────────
                ListenableBuilder(
                  listenable: _authController,
                  builder: (_, __) => PrimaryButton(
                    label: l10n.login,
                    isLoading: _authController.isLoading,
                    onPressed: _login,
                  ),
                ).animate().fade(delay: 550.ms),
                const SizedBox(height: 20),

                // ── Social login ──────────────────────────────────────────
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(l10n.orContinueWith,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12))),
                  const Expanded(child: Divider()),
                ]).animate().fade(delay: 560.ms),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _loginSocial(_authController.loginWithGoogle),
                      icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.continueWithGoogle,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _loginSocial(_authController.loginWithApple),
                      icon: const Icon(Icons.apple_rounded, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          l10n.continueWithApple,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                ]).animate().fade(delay: 580.ms),
                const SizedBox(height: 16),

                // ── Register link ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${l10n.noAccountYet} ',
                        style: Theme.of(context).textTheme.bodyMedium),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.register),
                      child: Text(l10n.createAccountNow,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ).animate().fade(delay: 600.ms),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
