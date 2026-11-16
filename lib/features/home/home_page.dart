import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/router/app_routes.dart';
import '../../core/router/auth_return_intent.dart';
import '../../core/settings/settings_controller.dart';
import '../../core/theme/hope_v2_design.dart';
import '../../core/transactions/transaction_repository.dart';
import '../../core/transactions/wallet_repository.dart';
import '../../core/ui/hope_l10n.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/components.dart';
import '../../core/ui/premium_components.dart';
import '../jobs/jobs_page.dart';
import '../profile/profile_page.dart';
import '../transactions/transactions_page.dart';
import '../wallet/wallet_page.dart';
import 'premium_home_feed.dart';



part 'home_widgets.part.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final PageController _pageController = PageController();
  int tab = 0;
  late final List<Widget?> _tabs = List<Widget?>.filled(5, null);

  Widget _buildTab(int index) => _tabs[index] ??= switch (index) {
        0 => buildResponsiveHomeFeed(
            context,
            () => _selectTab(1),
            () => _scaffoldKey.currentState?.openDrawer(),
            () => _openCreate(context),
          ),
        1 => const JobsPage(
            key: ValueKey('explore'),
            showPrimaryNavigation: false,
          ),
        2 => TransactionsPage(
            key: const ValueKey('transactions'),
            repository: context.read<TransactionRepository>(),
            showPrimaryNavigation: false,
          ),
        3 => WalletPage(
            repository: context.read<WalletRepository>(),
            showPrimaryNavigation: false,
          ),
        4 => const ProfilePage(
            key: ValueKey('profile'),
            showPrimaryNavigation: false,
          ),
        _ => const SizedBox.shrink(),
      };

  void _selectTab(int value) {
    if (value == tab) return;
    setState(() => tab = value);
    if (!_pageController.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(value);
      return;
    }
    _pageController.animateToPage(
      value,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => this._buildHomeScaffold(context);


  String _t(BuildContext context, String fa, String en) =>
      Localizations.localeOf(context).languageCode == 'en' ? en : fa;

  Widget _drawerTile(BuildContext context, Object icon, String label, VoidCallback tap) =>
      ListTile(
        leading: HopeIconTile(icon, filled: true, size: 42),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        onTap: tap,
      );

  void _openCreate(BuildContext context) {
    final auth = context.read<AuthController>();
    if (auth.isGuest) {
      _showSignIn(context);
      return;
    }
    Navigator.push(context, HopeRoutes.createJob());
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({
    super.key,
    required this.active,
    required this.builder,
  });

  final bool active;
  final Widget Function() builder;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin<_KeepAliveTab> {
  Widget? _child;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Do not initialize off-screen domains until a user visits them. Once
    // visited, keep the subtree mounted so scroll and form state survive tabs.
    _child ??= widget.active ? widget.builder() : null;
    return _child ?? const SizedBox.shrink();
  }
}

Future<void> _resumeCreateAfterAuth(
  BuildContext context, {
  required bool register,
}) async {
  final result = await Navigator.push<AuthReturnIntent?>(
    context,
    register
        ? HopeRoutes.register(returnIntent: AuthReturnIntent.createJob)
        : HopeRoutes.login(returnIntent: AuthReturnIntent.createJob),
  );
  if (!context.mounted ||
      result != AuthReturnIntent.createJob ||
      !context.read<AuthController>().isAuthenticated) {
    return;
  }
  await Navigator.push(context, HopeRoutes.createJob());
}

void _showSignIn(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const HopeMark(size: 48),
            const SizedBox(height: 16),
            Text(HopeCopy.of(context).copy_start_here_555e56f, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 7),
            Text(HopeCopy.of(context).copy_create_an_account_or_log_in_to_post_opport_6bc74a1, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _resumeCreateAfterAuth(context, register: true);
              },
              icon: const HopeIcon( HopeV2Icons.userAdd, size: 21),
              label: Text(HopeCopy.of(context).copy_create_account_bfa3517),
            ),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetContext);
                _resumeCreateAfterAuth(context, register: false);
              },
              icon: const HopeIcon( HopeV2Icons.login, size: 21),
              label: Text(HopeCopy.of(context).copy_log_in_b4c960b),
            ),
          ],
        ),
      ),
    ),
  );
}
