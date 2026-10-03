import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/auth_controller.dart';

/// Prevents admin-only surfaces from rendering for guests and standard users.
///
/// Backend authorization remains authoritative; this guard keeps admin
/// screens out of the client UI even when a route is opened directly.
class AdminOnly extends StatelessWidget {
  const AdminOnly({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthController>().user?['role']
        ?.toString()
        .trim()
        .toUpperCase();

    if (role == 'ADMIN') return child;

    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      appBar: AppBar(
        title: Text(isEn ? 'Restricted access' : 'دسترسی محدود'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isEn
                ? 'Admin access is restricted.'
                : 'دسترسی به بخش مدیریت فقط برای مدیران مجاز است.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
