import 'package:flutter/material.dart';

import '../../app_config.dart';
import '../../core/theme/app_theme.dart';
import '../habits/widgets/gold_widgets.dart';
import 'auth_service.dart';

enum _Mode { signIn, signUp }

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  _Mode _mode = _Mode.signIn;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _googleBusy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password needs at least 6 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == _Mode.signIn) {
        await widget.auth.signInWithEmail(email, password);
      } else {
        await widget.auth.signUpWithEmail(
          email,
          password,
          displayName: _name.text,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.describe(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleBusy = true;
      _error = null;
    });
    try {
      await widget.auth.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.describe(e));
    } finally {
      if (mounted) setState(() => _googleBusy = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    try {
      await widget.auth.sendPasswordReset(email);
      if (mounted) showSnack(context, 'Password reset email sent to $email.');
    } catch (e) {
      if (mounted) setState(() => _error = AuthService.describe(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isSignUp = _mode == _Mode.signUp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: CarryoverMark(size: 76)),
                  const SizedBox(height: 20),
                  Text(
                    AppConfig.appName,
                    textAlign: TextAlign.center,
                    style: t.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Golden habits, kept daily.',
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: 32),
                  _ModeToggle(
                    mode: _mode,
                    onChanged: (m) => setState(() {
                      _mode = m;
                      _error = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (isSignUp) ...[
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Your name'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: _obscure,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ),
                  ),
                  if (!isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _forgot,
                        child: const Text('Forgot password?'),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE4E1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error!,
                        style: t.bodySmall
                            ?.copyWith(color: const Color(0xFF5C1510)),
                      ),
                    ),
                  ],
                  GoldButton(
                    label: isSignUp ? 'Create account' : 'Sign in',
                    loading: _busy,
                    onPressed: _googleBusy ? null : _submit,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: t.bodySmall
                                ?.copyWith(color: AppColors.inkFaint)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: (_busy || _googleBusy) ? null : _google,
                    child: _googleBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _GoogleG(),
                              SizedBox(width: 12),
                              Text('Continue with Google'),
                            ],
                          ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Your data is stored privately in your own Firebase project.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: AppColors.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget option(_Mode m, String label) {
      final selected = mode == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: t.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          option(_Mode.signIn, 'Sign in'),
          option(_Mode.signUp, 'Create account'),
        ],
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.white,
        border: Border.all(color: AppColors.line),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Color(0xFF4285F4),
          height: 1,
        ),
      ),
    );
  }
}
