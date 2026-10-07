import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../../app/providers.dart';
import '../../../core/models/enums.dart';
import '../data/demo_accounts.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: AppColors.redBright, size: 48),
            SizedBox(height: 16),
            Text('WatchGuy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  var busy = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showAppMessage(context, error.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.redBright, size: 36),
            const SizedBox(height: 20),
            const Text('WatchGuy', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Security cameras, using the phones you already have.',
              style: TextStyle(color: AppColors.muted, fontSize: 16, height: 1.4),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/reset-password'),
                child: const Text('Forgot password'),
              ),
            ),
            PrimaryButton(
              label: 'Sign in',
              busy: busy,
              onPressed: () => _run(() => ref.read(sessionControllerProvider.notifier).signIn(email.text, password.text)),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Continue with Google',
              onPressed: busy ? null : () => _run(() => ref.read(sessionControllerProvider.notifier).signInWithGoogle()),
            ),
            if (Theme.of(context).platform == TargetPlatform.iOS) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                label: 'Continue with Apple',
                onPressed: busy ? null : () => _run(() => ref.read(sessionControllerProvider.notifier).signInWithApple()),
              ),
            ],
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.push('/sign-up'),
              child: const Text('Create an account'),
            ),
            if (!ref.watch(appConfigProvider).firebaseConfigured) ...[
              const SizedBox(height: 12),
              const Text(
                'DEMO ACCOUNTS',
                style: TextStyle(letterSpacing: 1.2, color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 8),
              for (final account in demoAccounts) ...[
                AppCard(
                  onTap: busy
                      ? null
                      : () => _run(
                            () => ref.read(sessionControllerProvider.notifier).signIn(account.email, demoPassword),
                          ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(account.detail, style: const TextStyle(color: AppColors.muted)),
                            Text(account.email, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              const Text(
                'Password $demoPassword. These accounts stay on this phone.',
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  var busy = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Create account', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('You can add operators to this organization later.', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name')),
          const SizedBox(height: 12),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Create account',
            busy: busy,
            onPressed: () async {
              setState(() => busy = true);
              try {
                await ref.read(sessionControllerProvider.notifier).signUp(name.text, email.text, password.text);
              } catch (error) {
                if (context.mounted) showAppMessage(context, error.toString());
              } finally {
                if (mounted) setState(() => busy = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final email = TextEditingController();
  var busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We will send a reset link if this email has an account.'),
            const SizedBox(height: 20),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Send reset link',
              busy: busy,
              onPressed: () async {
                setState(() => busy = true);
                try {
                  await ref.read(sessionControllerProvider.notifier).resetPassword(email.text);
                  if (context.mounted) showAppMessage(context, 'Check your email for the reset link.');
                } catch (error) {
                  if (context.mounted) showAppMessage(context, error.toString());
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(sessionControllerProvider).user?.email ?? 'your email';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text('Verify your email', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('Open the link sent to $email, then continue.', style: const TextStyle(color: AppColors.muted, height: 1.4)),
              const Spacer(),
              PrimaryButton(
                label: 'I verified my email',
                onPressed: () async {
                  try {
                    await ref.read(sessionControllerProvider.notifier).confirmVerification();
                  } catch (error) {
                    if (context.mounted) showAppMessage(context, error.toString());
                  }
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrganizationSetupScreen extends ConsumerStatefulWidget {
  const OrganizationSetupScreen({super.key});

  @override
  ConsumerState<OrganizationSetupScreen> createState() => _OrganizationSetupScreenState();
}

class _OrganizationSetupScreenState extends ConsumerState<OrganizationSetupScreen> {
  final name = TextEditingController();
  var busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Text('Name your organization', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              const Text(
                'Cameras and operators you add later belong to this organization.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Organization name')),
              const Spacer(),
              PrimaryButton(
                label: 'Continue',
                busy: busy,
                onPressed: () async {
                  if (name.text.trim().isEmpty) return;
                  setState(() => busy = true);
                  await ref.read(sessionControllerProvider.notifier).createOrganization(name.text);
                  if (mounted) setState(() => busy = false);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ModeSelectScreen extends ConsumerWidget {
  const ModeSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Text('How do you want to use this phone?', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.15)),
              const SizedBox(height: 8),
              const Text('You can change this later in settings.', style: TextStyle(color: AppColors.muted)),
              const Spacer(),
              _ModeCard(
                icon: Icons.videocam_outlined,
                title: 'Use as camera',
                body: 'This phone watches one place and reports what it sees.',
                onTap: () => ref.read(sessionControllerProvider.notifier).chooseMode(AppMode.camera),
              ),
              const SizedBox(height: 12),
              _ModeCard(
                icon: Icons.grid_view_rounded,
                title: 'Open dashboard',
                body: 'Watch every camera, alert, and incident from here.',
                onTap: () => ref.read(sessionControllerProvider.notifier).chooseMode(AppMode.dashboard),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.redBright),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: AppColors.muted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
