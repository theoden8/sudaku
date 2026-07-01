import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'DebugLog.dart';

/// Full-screen viewer for the in-app debug log buffer ([DebugLog]).
///
/// Push it with:
/// `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DebugLogScreen()))`.
class DebugLogScreen extends StatefulWidget {
  const DebugLogScreen({Key? key}) : super(key: key);

  @override
  State<DebugLogScreen> createState() => _DebugLogScreenState();
}

class _DebugLogScreenState extends State<DebugLogScreen> {
  final ScrollController _scrollController = ScrollController();
  LogLevel _minLevel = LogLevel.debug;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    DebugLog.instance.revision.addListener(_onLogChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    DebugLog.instance.revision.removeListener(_onLogChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onLogChanged() {
    if (!mounted) return;
    setState(() {});
    if (_autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Color _levelColor(LogLevel level, ColorScheme scheme) {
    switch (level) {
      case LogLevel.debug:
        return scheme.onSurface.withOpacity(0.55);
      case LogLevel.info:
        return scheme.primary;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return scheme.error;
    }
  }

  List<LogEntry> get _visibleEntries => DebugLog.instance.entries
      .where((e) => e.level.index >= _minLevel.index)
      .toList();

  Future<void> _copyAll() async {
    final entries = _visibleEntries;
    final text = entries.map((e) => e.format()).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${entries.length} log lines to clipboard')),
    );
  }

  void _confirmClear() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear logs?'),
        content: const Text('This removes all captured log lines from memory.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              DebugLog.instance.clear();
              Navigator.of(ctx).pop();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = _visibleEntries;

    return Scaffold(
      appBar: AppBar(
        title: Text('Debug logs (${entries.length})'),
        actions: [
          PopupMenuButton<LogLevel>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Minimum level',
            initialValue: _minLevel,
            onSelected: (level) => setState(() => _minLevel = level),
            itemBuilder: (ctx) => LogLevel.values
                .map((level) => PopupMenuItem<LogLevel>(
                      value: level,
                      child: Row(
                        children: [
                          if (level == _minLevel)
                            const Icon(Icons.check, size: 18)
                          else
                            const SizedBox(width: 18),
                          const SizedBox(width: 8),
                          Text('≥ ${level.label}'),
                        ],
                      ),
                    ))
                .toList(),
          ),
          IconButton(
            icon: Icon(_autoScroll
                ? Icons.vertical_align_bottom
                : Icons.vertical_align_center),
            tooltip: _autoScroll ? 'Auto-scroll on' : 'Auto-scroll off',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: entries.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: () => _confirmClear(),
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Text(
                'No log entries yet.',
                style: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
              ),
            )
          : Scrollbar(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: entries.length,
                itemBuilder: (ctx, i) {
                  final entry = entries[i];
                  final color = _levelColor(entry.level, scheme);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: SelectableText.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: '${entry.timeString} ',
                            style: TextStyle(
                              color: scheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                          TextSpan(
                            text: '${entry.level.label}'
                                '${entry.tag.isEmpty ? '' : ' [${entry.tag}]'}: ',
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: entry.message,
                            style: TextStyle(color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
