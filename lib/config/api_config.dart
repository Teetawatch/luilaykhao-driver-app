/// Build-time configuration for the driver app.
///
/// Override the API endpoint without editing code by passing a `--dart-define`,
/// e.g. for local development against the Laravel backend:
///
///   flutter run \
///     --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1   # Android emulator
///
/// Defaults to production so a plain `flutter run` / `flutter build` targets
/// the live backend. The driver app does not use Reverb, so there is no
/// realtime/websocket config here (unlike the customer app).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://luilaykhao.com/api/v1',
  );
}
