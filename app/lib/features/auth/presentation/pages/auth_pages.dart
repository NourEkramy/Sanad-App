import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/failure_messages.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/sanad_logo.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/repositories/auth_repository.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_form_cubits.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primaryDark,
    body: Container(
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SanadLogo(size: 96, onDark: true),
            const SizedBox(height: AppSpacing.lg),
            Text(context.l10n.appName, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.appTagline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Shared layout for the signed-out screens: brand header + white sheet.
class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.child, this.showBack = false});

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showBack)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: IconButton(
                          tooltip: context.l10n.commonBack,
                          onPressed: () => context.go(Routes.login),
                          icon: const BackButtonIcon(),
                        ),
                      ),
                    const Align(alignment: AlignmentDirectional.centerStart, child: SanadLogo(size: 64)),
                    const SizedBox(height: AppSpacing.xl),
                    Text(title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: AppSpacing.xl),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    FocusScope.of(context).unfocus();
    context.read<LoginCubit>().submit(email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final status = context.watch<AuthCubit>().state;
    final expired = status is Unauthenticated && status.sessionExpired;
    return BlocBuilder<LoginCubit, SubmitState>(
      builder: (context, state) {
        final failure = state.failure;
        return _AuthScaffold(
          title: l.loginTitle,
          subtitle: l.loginSubtitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (expired && state.status == FormStatus.idle) ...[
                InlineBanner.warning(message: l.loginSessionExpired, icon: Icons.lock_clock_rounded),
                const SizedBox(height: AppSpacing.md),
              ],
              if (failure != null && failure is! ValidationFailure) ...[
                InlineBanner.error(message: context.failureMessage(failure)),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                controller: _email,
                label: l.loginEmail,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email, AutofillHints.username],
                errorText: context.fieldError(failure, 'email'),
                textDirection: TextDirection.ltr,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _password,
                label: l.loginPassword,
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(context),
                errorText: context.fieldError(failure, 'password'),
                suffix: IconButton(
                  tooltip: _obscure ? l.loginShowPassword : l.loginHidePassword,
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(onPressed: () => context.go(Routes.forgotPassword), child: Text(l.loginForgot)),
              ),
              const SizedBox(height: AppSpacing.sm),
              PrimaryButton(
                label: l.loginSubmit,
                loading: state.submitting || state.status == FormStatus.success,
                onPressed: () => _submit(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<ForgotPasswordCubit, SubmitState>(
      builder: (context, state) => _AuthScaffold(
        showBack: true,
        title: l.forgotTitle,
        subtitle: l.forgotBody,
        child: state.status == FormStatus.success
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InlineBanner(
                    message: l.forgotSent(_email.text.trim()),
                    icon: Icons.mark_email_read_rounded,
                    color: AppColors.success,
                    background: AppColors.successSoft,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(onPressed: () => context.go(Routes.login), child: Text(l.loginSubmit)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.failure != null && context.fieldError(state.failure, 'email') == null) ...[
                    InlineBanner.error(message: context.failureMessage(state.failure!)),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AppTextField(
                    controller: _email,
                    label: l.loginEmail,
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    errorText: context.fieldError(state.failure, 'email'),
                    textDirection: TextDirection.ltr,
                    onSubmitted: (_) => context.read<ForgotPasswordCubit>().submit(_email.text),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: l.forgotSubmit,
                    loading: state.submitting,
                    onPressed: () => context.read<ForgotPasswordCubit>().submit(_email.text),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Shown after opening a password-reset link, and reused to change the
/// password from the profile screen.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key, this.fromProfile = false});

  final bool fromProfile;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final form = BlocConsumer<PasswordCubit, SubmitState>(
      listener: (context, state) async {
        if (state.status != FormStatus.success) return;
        context.showSuccess(l.resetDone);
        if (widget.fromProfile) {
          context.pop();
        } else {
          // Recovery sessions are single-purpose: sign in again normally.
          await context.read<AuthCubit>().signOut();
        }
      },
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.failure != null && state.failure is! ValidationFailure) ...[
            InlineBanner.error(message: context.failureMessage(state.failure!)),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            controller: _password,
            label: l.resetNewPassword,
            obscureText: true,
            prefixIcon: Icons.lock_outline_rounded,
            autofillHints: const [AutofillHints.newPassword],
            errorText: context.fieldError(state.failure, 'password'),
            helper: l.validationPasswordTooShort,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _confirm,
            label: l.resetConfirmPassword,
            obscureText: true,
            prefixIcon: Icons.lock_outline_rounded,
            autofillHints: const [AutofillHints.newPassword],
            errorText: context.fieldError(state.failure, 'confirmation'),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l.resetSubmit,
            loading: state.submitting,
            onPressed: () =>
                context.read<PasswordCubit>().submit(password: _password.text, confirmation: _confirm.text),
          ),
        ],
      ),
    );
    if (widget.fromProfile) {
      return Scaffold(
        appBar: AppBar(title: Text(l.changePassword)),
        body: SafeArea(
          child: SingleChildScrollView(padding: AppSpacing.page, child: form),
        ),
      );
    }
    return _AuthScaffold(title: l.resetTitle, subtitle: l.resetBody, child: form);
  }
}

class NotConfiguredPage extends StatelessWidget {
  const NotConfiguredPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: EmptyView(
        icon: Icons.settings_suggest_rounded,
        title: context.l10n.notConfiguredTitle,
        message: context.l10n.notConfiguredBody,
      ),
    ),
  );
}
