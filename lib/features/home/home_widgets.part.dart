part of 'home_page.dart';


Widget buildResponsiveHomeFeed(
  BuildContext context,
  VoidCallback onOpenExplore,
  VoidCallback onOpenMenu,
  VoidCallback onOpenCreate,
) =>
    HopeResponsive(
      child: PremiumHomeFeed(
        onOpenExplore: onOpenExplore,
        onOpenMenu: onOpenMenu,
        onOpenCreate: onOpenCreate,
      ),
    );
