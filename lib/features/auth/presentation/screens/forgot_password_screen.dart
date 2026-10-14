import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/primary_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _auth = AuthController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _auth.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _auth.sendResetCode(email: _emailCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(
          context, AppLocalizations.of(context).codeSentSuccess);
      Navigator.pushNamed(context, AppRoutes.verifyCode,
          arguments: _emailCtrl.text.trim());
    } else {
      AppSnackbar.error(context,
          _auth.errorMessage ?? AppLocalizations.of(context).genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: AppColors.primarySurface, shape: BoxShape.circle),
                child: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.primary, size: 36),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(l10n.forgotPasswordTitle,
                      style: Theme.of(context).textTheme.headlineSmall)
                  .animate()
                  .fade(delay: 150.ms),
              const SizedBox(height: 8),
              Text(l10n.forgotPasswordSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium)
                  .animate()
                  .fade(delay: 200.ms),
              const SizedBox(height: 32),
              AuthTextField(
                controller: _emailCtrl,
                label: l10n.emailLabel,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: Validators.emailValidator(
                    l10n.emailLabel, l10n.genericError),
                onFieldSubmitted: (_) => _send(),
              ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: _auth,
                builder: (_, __) => PrimaryButton(
                  label: l10n.sendCode,
                  isLoading: _auth.isLoading,
                  onPressed: _send,
                ),
              ).animate().fade(delay: 380.ms),
            ],
          ),
        ),
      ),
    );
  }
}
