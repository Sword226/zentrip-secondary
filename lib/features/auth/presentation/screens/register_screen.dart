import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/phone_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/auth_controller.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/photo_picker_avatar.dart';
import '../widgets/primary_button.dart';
import 'login_success_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthController();
  File? _photo;
  bool _showPw = false;
  bool _showConfirm = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _pwCtrl.dispose(); _confirmCtrl.dispose(); _auth.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      AppSnackbar.warning(context, AppLocalizations.of(context).mustAcceptTerms);
      return;
    }
    final ok = await _auth.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _pwCtrl.text,
      photo: _photo,
    );
    if (!mounted) return;
    if (ok) {
      AppSnackbar.success(context, AppLocalizations.of(context).accountCreatedSuccess);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginSuccessScreen()));
    } else {
      AppSnackbar.error(context, _auth.errorMessage ?? AppLocalizations.of(context).genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccountTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Photo Picker ─────────────────────────────────────────
              Center(
                child: PhotoPickerAvatar(
                  initialFile: _photo,
                  onChanged: (f) => setState(() => _photo = f),
                ),
              ).animate().fade(duration: 400.ms).scale(curve: Curves.easeOutBack),
              const SizedBox(height: 28),

              // ── Fields ───────────────────────────────────────────────
              AuthTextField(
                controller: _nameCtrl,
                label: l10n.nameLabel,
                icon: Icons.person_outline,
                validator: Validators.requiredValidator(l10n.nameLabel, minLength: 2),
              ).animate().fade(delay: 100.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _emailCtrl,
                label: l10n.emailLabel,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.emailValidator(l10n.emailLabel, l10n.genericError),
              ).animate().fade(delay: 160.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 14),
              PhoneField(
                controller: _phoneCtrl,
                label: l10n.phoneLabel,
                validator: Validators.phoneValidator(l10n.phoneLabel, l10n.genericError),
              ).animate().fade(delay: 200.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _pwCtrl,
                label: l10n.passwordLabel,
                icon: Icons.lock_outlined,
                obscureText: !_showPw,
                validator: Validators.passwordValidator(l10n.passwordLabel, l10n.genericError),
                suffixIcon: IconButton(
                  icon: Icon(_showPw ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showPw = !_showPw),
                ),
              ).animate().fade(delay: 240.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 14),
              AuthTextField(
                controller: _confirmCtrl,
                label: l10n.confirmPasswordLabel,
                icon: Icons.lock_outlined,
                obscureText: !_showConfirm,
                textInputAction: TextInputAction.done,
                validator: Validators.confirmPasswordValidator(
                  () => _pwCtrl.text,
                  l10n.confirmPasswordLabel,
                  l10n.genericError,
                ),
                onFieldSubmitted: (_) => _register(),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showConfirm = !_showConfirm),
                ),
              ).animate().fade(delay: 280.ms).slideY(begin: 0.08, end: 0),
              const SizedBox(height: 20),

              // ── Terms ────────────────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _acceptedTerms ? AppColors.primary : Colors.transparent,
                        border: Border.all(color: _acceptedTerms ? AppColors.primary : AppColors.border, width: 1.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _acceptedTerms ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        children: [
                          Text(l10n.agreeToTermsPrefix, style: Theme.of(context).textTheme.bodyMedium),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.terms),
                            child: Text(l10n.termsAndConditions, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: AppColors.primary)),
                          ),
                          Text(l10n.andWord, style: Theme.of(context).textTheme.bodyMedium),
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.privacy),
                            child: Text(l10n.privacyPolicy, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade(delay: 320.ms),
              const SizedBox(height: 24),

              // ── Submit ───────────────────────────────────────────────
              ListenableBuilder(
                listenable: _auth,
                builder: (_, __) => PrimaryButton(
                  label: l10n.signup,
                  isLoading: _auth.isLoading,
                  onPressed: _register,
                ),
              ).animate().fade(delay: 380.ms),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${l10n.alreadyHaveAccount} ', style: Theme.of(context).textTheme.bodyMedium),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(l10n.login, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
