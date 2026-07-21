import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _codeFocus = FocusNode();
  Timer? _countdown;
  bool _wasCodeEntry = false;

  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _phoneFocus.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth is! AuthSignedOut) {
      return const SizedBox.shrink();
    }
    if (!_phoneFocus.hasFocus && _phoneController.text != auth.phoneNumber) {
      _phoneController.value = TextEditingValue(
        text: auth.phoneNumber,
        selection: TextSelection.collapsed(offset: auth.phoneNumber.length),
      );
    }
    if (_wasCodeEntry && !auth.isCodeEntry) {
      _codeController.clear();
    }
    _wasCodeEntry = auth.isCodeEntry;

    final now = ref.read(authClockProvider)();
    final expired = auth.isChallengeExpired(now);
    final resendSeconds = auth.resendSecondsRemaining(now);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FoodHeader(compact: constraints.maxHeight < 680),
                        const SizedBox(height: 24),
                        Text(
                          auth.isCodeEntry ? '输入验证码' : '登录好好吃饭',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          auth.isCodeEntry
                              ? '验证码已发送至 ${auth.phoneNumber}'
                              : '使用手机号码继续',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 20),
                        if (auth.noticeMessage case final notice?) ...[
                          _StatusMessage(
                            key: const Key('auth-notice'),
                            message: notice,
                            error: false,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (auth.isCodeEntry)
                          _buildCodeForm(
                            auth,
                            expired: expired,
                            resendSeconds: resendSeconds,
                          )
                        else
                          _buildPhoneForm(auth),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoneForm(AuthSignedOut auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('auth-phone-input'),
          controller: _phoneController,
          focusNode: _phoneFocus,
          enabled: !auth.busy,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          maxLength: 16,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[+0-9]')),
          ],
          decoration: const InputDecoration(
            labelText: '手机号码',
            hintText: '13812345678',
            prefixIcon: Icon(LucideIcons.smartphone),
            border: OutlineInputBorder(),
          ),
          onSubmitted: auth.busy ? null : (_) => _submitPhone(),
        ),
        if (auth.errorMessage case final error?) ...[
          const SizedBox(height: 4),
          _StatusMessage(message: error, error: true),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('auth-request-code'),
          onPressed: auth.busy ? null : _submitPhone,
          child: _ButtonContent(
            busy: auth.busy,
            icon: LucideIcons.arrowRight,
            label: '获取验证码',
          ),
        ),
      ],
    );
  }

  Widget _buildCodeForm(
    AuthSignedOut auth, {
    required bool expired,
    required int resendSeconds,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('auth-code-input'),
          controller: _codeController,
          focusNode: _codeFocus,
          enabled: !auth.busy && !expired,
          autofocus: true,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '6 位验证码',
            prefixIcon: Icon(LucideIcons.shieldCheck),
            border: OutlineInputBorder(),
          ),
          onSubmitted: auth.busy || expired ? null : (_) => _submitCode(),
        ),
        if (auth.errorMessage case final error?) ...[
          const SizedBox(height: 4),
          _StatusMessage(message: error, error: true),
        ] else if (expired) ...[
          const SizedBox(height: 4),
          const _StatusMessage(message: '验证码已过期，请重新获取', error: true),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('auth-verify-code'),
          onPressed: auth.busy || expired ? null : _submitCode,
          child: _ButtonContent(
            busy: auth.busy,
            icon: LucideIcons.logIn,
            label: '登录',
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final actions = <Widget>[
              TextButton.icon(
                key: const Key('auth-edit-phone'),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  ref.read(authControllerProvider.notifier).editPhoneNumber();
                },
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
                label: const Text('修改手机号'),
              ),
              TextButton.icon(
                key: const Key('auth-resend-code'),
                onPressed: auth.busy || (!expired && resendSeconds > 0)
                    ? null
                    : () =>
                          ref.read(authControllerProvider.notifier).resendOtp(),
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: Text(
                  !expired && resendSeconds > 0
                      ? '${resendSeconds}s 后重发'
                      : '重新发送',
                ),
              ),
            ];
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions,
              );
            }
            return Row(
              children: [
                Expanded(child: actions[0]),
                const SizedBox(width: 8),
                Expanded(child: actions[1]),
              ],
            );
          },
        ),
      ],
    );
  }

  void _submitPhone() {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).requestOtp(_phoneController.text);
  }

  void _submitCode() {
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).verifyOtp(_codeController.text);
  }
}

class _FoodHeader extends StatelessWidget {
  const _FoodHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: compact ? 112 : 156,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/oats-breakfast.webp', fit: BoxFit.cover),
            const ColoredBox(color: Color(0x52000000)),
            const Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.utensils, color: Colors.white, size: 22),
                    SizedBox(width: 9),
                    Flexible(
                      child: Text(
                        '好好吃饭',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.busy,
    required this.icon,
    required this.label,
  });

  final bool busy;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Center(
        child: busy
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label),
                  const SizedBox(width: 8),
                  Icon(icon, size: 18),
                ],
              ),
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.error, super.key});

  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.tomato : AppColors.green;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? LucideIcons.circleAlert : LucideIcons.circleCheck,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
