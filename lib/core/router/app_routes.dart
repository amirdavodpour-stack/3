import 'package:flutter/material.dart';

import 'auth_return_intent.dart';

import '../../features/about/about_page.dart';
import '../../features/admin/admin_page.dart';
import '../../features/admin/admin_operations_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/password_reset_page.dart';
import '../../features/auth/register_page.dart';
import '../../features/marketplace/create_job_page.dart';
import '../marketplace/job.dart';
import '../../features/marketplace/job_detail_page.dart';
import '../../features/offers/offers_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/notifications/notification_devices_page.dart';
import '../../features/privacy/privacy_center_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/applications/my_applications_page.dart';
import '../../features/jobs/saved_searches_page.dart';
import '../../features/jobs/jobs_page.dart';
import '../../features/transactions/transaction_page.dart';
import '../../features/wallet/wallet_page.dart';
import '../transactions/transaction_repository.dart';
import '../transactions/wallet_repository.dart';
import '../uploads/upload_queue.dart';

/// Central place where every in-app destination is turned into a [Route].
///
/// Features no longer construct `MaterialPageRoute` themselves; they ask
/// [HopeRoutes] for a route and hand it to `Navigator.push(...)`. This keeps
/// page construction and routing policy (transitions, animation, future
/// deep-link wiring) in one file, and lets the feature layer depend on
/// routing intent instead of concrete page wiring — the same reason
/// repositories already live behind abstractions in `lib/core`.
abstract final class HopeRoutes {
  /// Auth flows.
  static Route<AuthReturnIntent?> login({AuthReturnIntent? returnIntent}) =>
      _page(LoginPage(returnIntent: returnIntent));
  static Route<AuthReturnIntent?> register({AuthReturnIntent? returnIntent}) =>
      _page(RegisterPage(returnIntent: returnIntent));
  static Route<void> passwordReset() => _page(const PasswordResetPage());

  /// Account & content destinations.
  static Route<void> notifications() => _page(const NotificationsPage());
  static Route<void> notificationDevices() => _page(const NotificationDevicesPage());
  static Route<void> privacyCenter() => _page(const PrivacyCenterPage());
  static Route<void> profile() => _page(const ProfilePage());
  static Route<void> myApplications() => _page(const MyApplicationsPage());
  static Route<void> savedSearches() => _page(const SavedSearchesPage());
  static Route<void> jobs() => _page(const JobsPage());
  static Route<void> offers({String? jobId}) => _page(OffersPage(jobId: jobId));
  static Route<void> admin() => _page(const AdminPage());
  static Route<void> adminOperations() => _page(const AdminOperationsPage());
  static Route<void> about() => _page(const AboutHopePage());
  static Route<WalletPage> wallet({required WalletRepository repository}) =>
      _page(WalletPage(repository: repository));
  static Route<void> createJob() => _page(const CreateJobPage());

  /// Marketplace.
  static Route<JobDetailPage> jobDetail(HopeJob job) =>
      _page(JobDetailPage(job: job));
  static Route<TransactionPage> transaction({
    required TransactionRepository repository,
    required UploadQueue uploadQueue,
    required String jobId,
  }) =>
      _page(TransactionPage(
        repository: repository,
        uploadQueue: uploadQueue,
        jobId: jobId,
      ));

  static Route<T> _page<T>(Widget page) => MaterialPageRoute<T>(
        builder: (_) => page,
      );
}
