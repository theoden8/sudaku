import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;

/// Severity levels for captured log entries.
enum LogLevel { debug, info, warning, error }

extension LogLevelInfo on LogLevel {
  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

/// A single captured log line.
class LogEntry {
  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  LogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
  });

  String get timeString {
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}.${three(time.millisecond)}';
  }

  /// Plain-text representation used for copy/share.
  String format() {
    final tagPart = tag.isEmpty ? '' : ' [$tag]';
    return '$timeString ${level.label}$tagPart: $message';
  }
}

/// In-app debug log buffer.
///
/// Keeps a bounded ring buffer of recent log lines in memory so that they can
/// be inspected from within the app (there is no attached console on release
/// builds). Also captures `debugPrint` output, uncaught Flutter framework
/// errors and uncaught async errors so nothing is silently lost.
class DebugLog {
  DebugLog._();
  static final DebugLog instance = DebugLog._();

  /// Maximum number of retained entries. Older entries are dropped.
  static const int maxEntries = 2000;

  final ListQueue<LogEntry> _entries = ListQueue<LogEntry>();

  /// Bumps every time the log changes so UIs can rebuild.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _installed = false;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  int get length => _entries.length;

  void log(
    String message, {
    LogLevel level = LogLevel.debug,
    String tag = '',
    bool mirrorToConsole = true,
  }) {
    final entry = LogEntry(
      time: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
    );
    _entries.addLast(entry);
    while (_entries.length > maxEntries) {
      _entries.removeFirst();
    }
    revision.value++;

    // Mirror to the console in debug builds so the normal workflow still works.
    // Entries captured from debugPrint / framework errors already reach the
    // console through their original handler, so they are not mirrored again.
    if (kDebugMode && mirrorToConsole) {
      // ignore: avoid_print
      print(entry.format());
    }
  }

  void d(String message, {String tag = ''}) =>
      log(message, level: LogLevel.debug, tag: tag);
  void i(String message, {String tag = ''}) =>
      log(message, level: LogLevel.info, tag: tag);
  void w(String message, {String tag = ''}) =>
      log(message, level: LogLevel.warning, tag: tag);
  void e(String message, {String tag = ''}) =>
      log(message, level: LogLevel.error, tag: tag);

  void clear() {
    _entries.clear();
    revision.value++;
  }

  /// All entries as a single copy/share-ready string.
  String export() => _entries.map((e) => e.format()).join('\n');

  /// Installs global hooks: routes `debugPrint`, Flutter framework errors and
  /// uncaught async errors into the buffer. Safe to call more than once.
  void install() {
    if (_installed) return;
    _installed = true;

    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        log(message, level: LogLevel.debug, tag: 'print', mirrorToConsole: false);
      }
      // Preserve default behaviour (console output, rate limiting).
      previousDebugPrint(message, wrapWidth: wrapWidth);
    };

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      log(
        '${details.exceptionAsString()}\n${details.stack ?? ''}',
        level: LogLevel.error,
        tag: 'flutter',
        mirrorToConsole: false,
      );
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    // Uncaught async errors that reach the platform dispatcher.
    final binding = WidgetsBinding.instance;
    binding.platformDispatcher.onError = (Object error, StackTrace stack) {
      log('$error\n$stack', level: LogLevel.error, tag: 'async',
          mirrorToConsole: false);
      return false;
    };
  }
}
