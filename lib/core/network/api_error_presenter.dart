import 'api_client.dart';

/// Converts transport/API failures into stable, non-sensitive UI messages.
/// Callers should still keep the original exception for telemetry/logging.
String apiErrorMessage(Object error, {String fallback = 'عملیات ناموفق بود.'}) {
  if (error is ApiException) {
    switch (error.code) {
      case 'UNAUTHENTICATED':
      case 'INVALID_TOKEN':
        return 'نیاز به ورود مجدد دارید.';
      case 'FORBIDDEN':
        return 'دسترسی به این بخش مجاز نیست.';
      case 'JOB_NOT_HIRABLE':
        return 'این موقعیت دیگر قابل استخدام نیست.';
      case 'CANDIDATE_ALREADY_HIRED':
        return 'برای این موقعیت قبلاً فردی استخدام شده است.';
      case 'VALIDATION_ERROR':
        return 'اطلاعات واردشده را بررسی کنید.';
      case 'WEAK_PASSWORD':
        return 'رمز عبور باید بین ۱۲ تا ۱۲۸ کاراکتر باشد.';
      case 'INVALID_EMAIL':
        return 'ایمیل واردشده معتبر نیست.';
      case 'EMAIL_IN_USE':
        return 'این ایمیل قبلاً برای یک حساب ثبت شده است.';
      case 'RATE_LIMITED':
        return 'درخواست‌های زیادی ارسال شده؛ کمی بعد دوباره تلاش کنید.';
      case 'NETWORK_ERROR':
      case 'TIMEOUT':
        return 'ارتباط با سرور برقرار نشد. دوباره تلاش کنید.';
    }
  }
  return fallback;
}
