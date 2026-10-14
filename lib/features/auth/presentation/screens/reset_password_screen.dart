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

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthController();
  bool _showPw = false, _showConfirm = false;

  @override
  void dispose() {
    _pwCtrl.dispose(); _confirmCtrl.dispose(); _auth.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await _auth.resetPassword(code: '', newPassword: _pwCtrl.text);
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, AppLocalizations.of(context).passwordResetSuccess);
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.auth, (_) => false);
    } else {
      AppSnackbar.error(context, _auth.errorMessage ?? AppLocalizations.of(context).genericError);
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
                width: 72, height: 72,
                decoration: const BoxDecoration(color: AppColors.primarySurface, shape: BoxShape.circle),
                child: const Icon(Icons.key_rounded, color: AppColors.primary, size: 36),
              ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 24),
              Text(l10n.resetPasswordTitle, style: Theme.of(context).textTheme.headlineSmall)
                  .animate().fade(delay: 150.ms),
              const SizedBox(height: 8),
              Text(l10n.resetPasswordSubtitle, style: Theme.of(context).textTheme.bodyMedium)
                  .animate().fade(delay: 200.ms),
              const SizedBox(height: 32),
              AuthTextField(
                controller: _pwCtrl,
                label: l10n.newPasswordLabel,
                icon: Icons.lock_outlined,
                obscureText: !_showPw,
                validator: Validators.passwordValidator(l10n.newPasswordLabel, l10n.genericError),
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _confirmCtrl,
                label: l10n.confirmPasswordLabel,
                icon: Icons.lock_outlined,
                obscureText: !_showConfirm,
                textInputAction: TextInputAction.done,
                validator: Validators.confirmPasswordValidator(() => _pwCtrl.text, l10n.confirmPasswordLabel, l10n.genericError),
                onFieldSubmitted: (_) => _reset(),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ).animate().fade(delay: 360.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 28),
              ListenableBuilder(
                listenable: _auth,
                builder: (_, __) => PrimaryButton(
                  label: l10n.saveNewPassword,
                  isLoading: _auth.isLoading,
                  onPressed: _reset,
                ),
              ).animate().fade(delay: 420.ms),
            ],
          ),
        ),
      ),
    );
  }
}
