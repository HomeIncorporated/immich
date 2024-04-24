import 'dart:async';

import 'package:immich_mobile/core/log/model/log_message.model.dart';

abstract class LogRepository {
  /// Fetches all logs
  FutureOr<List<LogMessage>> fetchLogs();

  /// Truncates the logs to the most recent [limit]. Defaults to recent 250 logs
  FutureOr<void> truncateLogs({int limit = 250});
}
