import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:zabb/services/auth_service.dart';

class ProblemsScreen extends StatefulWidget {
  const ProblemsScreen({super.key});

  @override
  State<ProblemsScreen> createState() => _ProblemsScreenState();
}

class _ProblemsScreenState extends State<ProblemsScreen> {
  final _auth = AuthService.instance;
  late Future<List<Map<String, dynamic>>> _future;
  Timer? _refreshTimer;
  int _countdownSeconds = 30;
  int _itemCount = 0;
  
  // Filter state that persists across refreshes
  int? _selectedSeverity;
  String? _selectedHostname;

  @override
  void initState() {
    super.initState();
    _future = _auth.fetchProblems();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _countdownSeconds = 30;
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _countdownSeconds--;
        if (_countdownSeconds <= 0) {
          _refreshData();
        }
      });
    });
  }

  void _refreshData() {
    setState(() {
      _future = _auth.fetchProblems();
      _startRefreshTimer();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset('assets/zabb.svg', height: 24, width: 24),
            const SizedBox(width: 8),
            const Text('Problems'),
          ],
        ),
        actions: [
          // Item count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_itemCount items',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Countdown timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _countdownSeconds <= 5 ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_countdownSeconds}s',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _countdownSeconds <= 5 ? Colors.orange : Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Configuration button
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to configuration screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration screen - coming soon')),
              );
            },
            tooltip: 'Settings',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await _auth.logout();
                if (mounted) {
                  // Navigate to root and clear entire navigation stack
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Logout failed: $e')),
                  );
                }
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            // Print errors to stdout for easier debugging on Linux
            // ignore: avoid_print
            print('ProblemsScreen error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? const [];
          
          if (items.isEmpty) {
            // Update item count for empty list
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _itemCount != 0) {
                setState(() {
                  _itemCount = 0;
                });
              }
            });
            return const Center(child: Text('No problems'));
          }
          // Build a sortable table view of problems
          return _ProblemsTable(
            items: items, 
            onDetails: (p) => _showDetails(context, p),
            onRefresh: _refreshData,
            selectedSeverity: _selectedSeverity,
            selectedHostname: _selectedHostname,
            onFilterChanged: (severity, hostname, filteredCount) {
              setState(() {
                _selectedSeverity = severity;
                _selectedHostname = hostname;
                _itemCount = filteredCount;
              });
            },
          );
        },
      ),
    );
  }

  int _parseInt(dynamic value, {required int defaultValue}) {
    if (value is int) return value;
    if (value is String) {
      final v = int.tryParse(value);
      if (v != null) return v;
    }
    return defaultValue;
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || parts.isNotEmpty) parts.add('${hours}h');
    parts.add('${mins}m');
    return parts.join(' ');
  }

  void _showDetails(BuildContext context, Map<String, dynamic> problem) {
    showDialog(
      context: context,
      builder: (context) {
        final acknowledgesList = problem['acknowledges'] as List?;
        final eventId = (problem['eventid'] ?? '').toString();
        final triggerId = problem['objectid']?.toString() ?? '';
        final hostname = triggerId.isNotEmpty ? AuthService.instance.getHostNameByTriggerId(triggerId) : 'Unknown';
        final severity = _parseInt(problem['severity'] ?? 0, defaultValue: 0);
        final clock = _parseInt(problem['clock'] ?? 0, defaultValue: 0);
        final tags = problem['tags'] as List?;
        
        // Format timestamp
        final timestamp = clock > 0 
            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(clock * 1000))
            : 'Unknown';
            
        // Calculate duration
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final duration = clock > 0 ? Duration(seconds: now - clock) : Duration.zero;
        
        return AlertDialog(
          title: Text(
            problem['name'] ?? 'Problem Details',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Host information
                  _buildDetailSection('Host Information', [
                    _buildDetailRow('Hostname:', hostname),
                    _buildDetailRow('Trigger ID:', triggerId),
                  ]),
                  
                  const SizedBox(height: 16),
                  
                  // Problem information
                  _buildDetailSection('Problem Information', [
                    _buildDetailRow('Event ID:', problem['eventid']?.toString() ?? 'N/A'),
                    _buildDetailRow('Severity:', _getSeverityText(severity)),
                    _buildDetailRow('Started:', timestamp),
                    _buildDetailRow('Duration:', _formatDuration(duration)),
                  ]),
                  
                  const SizedBox(height: 16),
                  
                  // Full description
                  _buildDetailSection('Description', [
                    GestureDetector(
                      onTap: () => _copyToClipboard(problem['name']?.toString() ?? 'No description available'),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                problem['name']?.toString() ?? 'No description available',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.copy,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                  
                  // Tags section
                  if (tags != null && tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Tags', [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: tags.map((tag) {
                          final tagStr = tag is Map ? '${tag['tag'] ?? ''}${tag['value'] != null ? ':${tag['value']}' : ''}' : tag.toString();
                          return GestureDetector(
                            onTap: () => _copyToClipboard(tagStr),
                            child: Chip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(tagStr, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.copy,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                ],
                              ),
                              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
                  ],
                  
                  // Acknowledgment information
                  if (acknowledgesList != null && acknowledgesList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildDetailSection('Acknowledgments (${acknowledgesList.length})', 
                      acknowledgesList.map((ack) {
                        final ackTime = _parseInt(ack['clock'] ?? 0, defaultValue: 0);
                        final ackTimeStr = ackTime > 0 
                            ? DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(ackTime * 1000))
                            : 'Unknown time';
                        final user = ack['alias']?.toString() ?? ack['name']?.toString() ?? 'Unknown user';
                        final message = ack['message']?.toString() ?? 'No message';
                        
                        return GestureDetector(
                          onTap: () => _copyToClipboard('$user - $ackTimeStr: $message'),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('$user - $ackTimeStr', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 4),
                                      SelectableText(message),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.copy,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  // Raw data section (for debugging)
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Raw Data'),
                    children: [
                      GestureDetector(
                        onTap: () => _copyToClipboard(_formatJson(problem)),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _formatJson(problem),
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.copy,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: eventId.isEmpty
                  ? null
                  : () async {
                      try {
                        await AuthService.instance.acknowledgeEvent(eventId: eventId);
                        if (!mounted) return;
                        Navigator.pop(context);
                        // Refresh the problems list
                        setState(() {
                          _future = _auth.fetchProblems();
                        });
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Acknowledge failed: $e')));
                      }
                    },
              child: const Text('Acknowledge'),
            ),
            TextButton(
              onPressed: eventId.isEmpty
                  ? null
                  : () async {
                      try {
                        await AuthService.instance.closeEvent(eventId: eventId);
                        if (!mounted) return;
                        Navigator.pop(context);
                        // Refresh the problems list
                        setState(() {
                          _future = _auth.fetchProblems();
                        });
                      } catch (e) {
                        if (!mounted) return;
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Close failed: $e')));
                      }
                    },
              child: const Text('Close problem'),
            ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        );
      },
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: _buildCopyableText(value),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableText(String text, {TextStyle? style}) {
    return GestureDetector(
      onTap: () => _copyToClipboard(text),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: SelectableText(
                text,
                style: style ?? Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy,
              size: 16,
              color: Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied: $text'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getSeverityText(int severity) {
    final severityNames = {
      0: 'Not classified',
      1: 'Information',
      2: 'Warning',
      3: 'Average',
      4: 'High',
      5: 'Disaster',
    };
    return '${severityNames[severity] ?? 'Unknown'} ($severity)';
  }

  String _formatJson(Map<String, dynamic> data) {
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } catch (e) {
      return data.toString();
    }
  }

}

class _ProblemsTable extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic>) onDetails;
  final VoidCallback onRefresh;
  final int? selectedSeverity;
  final String? selectedHostname;
  final void Function(int?, String?, int) onFilterChanged;
  
  const _ProblemsTable({
    required this.items, 
    required this.onDetails, 
    required this.onRefresh,
    required this.selectedSeverity,
    required this.selectedHostname,
    required this.onFilterChanged,
  });

  @override
  State<_ProblemsTable> createState() => _ProblemsTableState();
}

class _ProblemsTableState extends State<_ProblemsTable> {
  int _sortColumnIndex = 0;
  bool _sortAscending = false; // default DESC by severity
  
  int? get _selectedSeverity => widget.selectedSeverity;
  String? get _selectedHostname => widget.selectedHostname;
  
  @override
  void initState() {
    super.initState();
    // Notify parent of initial filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rows = _rows;
      widget.onFilterChanged(_selectedSeverity, _selectedHostname, rows.length);
    });
  }
  
  @override
  void didUpdateWidget(_ProblemsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Notify parent when widget updates (after refresh)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rows = _rows;
      widget.onFilterChanged(_selectedSeverity, _selectedHostname, rows.length);
    });
  }

  List<Map<String, dynamic>> get _rows {
    return _getRowsWithFilter(_selectedSeverity, _selectedHostname);
  }
  
  List<Map<String, dynamic>> _getRowsWithFilter(int? severityFilter, String? hostnameFilter) {
    var rows = List<Map<String, dynamic>>.from(widget.items);
    
    // Apply severity filter if one is selected
    if (severityFilter != null) {
      rows = rows.where((item) => _valueInt(item['severity']) == severityFilter).toList();
    }
    
    // Apply hostname filter if one is selected
    if (hostnameFilter != null) {
      rows = rows.where((item) => _hostOf(item) == hostnameFilter).toList();
    }
    
    rows.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // severity
          cmp = _valueInt(a['severity']).compareTo(_valueInt(b['severity']));
          break;
        case 1: // start time
          cmp = _valueInt(a['clock']).compareTo(_valueInt(b['clock']));
          break;
        case 2: // duration
          final da = _durationSeconds(a);
          final db = _durationSeconds(b);
          cmp = da.compareTo(db);
          break;
        case 3: // name
          cmp = _valueString(a['name'] ?? a['message']).compareTo(_valueString(b['name'] ?? b['message']));
          break;
        case 4: // host
          cmp = _hostOf(a).compareTo(_hostOf(b));
          break;
        default:
          cmp = 0;
      }
      return _sortAscending ? cmp : -cmp;
    });
    return rows;
  }

  int _valueInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _valueString(dynamic v) => (v ?? '').toString();

  int _durationSeconds(Map<String, dynamic> p) {
    final clock = _valueInt(p['clock']);
    final rclock = _valueInt(p['r_clock']);
    final end = rclock != 0 ? rclock : (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    return (end - clock).abs();
  }

  String _hostOf(Map<String, dynamic> p) {
    // Use objectid (trigger ID) to find host in AuthService cache
    final triggerId = p['objectid']?.toString();
    if (triggerId != null && triggerId.isNotEmpty && triggerId != '0') {
      return AuthService.instance.getHostNameByTriggerId(triggerId);
    }
    return 'No host';
  }

  String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final mins = d.inMinutes % 60;
    final parts = <String>[];
    if (days > 0) parts.add('${days}d');
    if (hours > 0 || parts.isNotEmpty) parts.add('${hours}h');
    parts.add('${mins}m');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final rows = _rows;
    return Column(
      children: [
        // Fixed header
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: DataTable(
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            headingRowHeight: 56,
            columnSpacing: 12,
            columns: [
              DataColumn(
                label: const SizedBox(width: 96, child: Text('Severity')),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const SizedBox(width: 132, child: Text('Start')),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const SizedBox(width: 92, child: Text('Duration')),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const Text('Name'),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const SizedBox(width: 132, child: Text('Host')),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
            ],
            rows: const [], // Empty header table
          ),
        ),
        // Scrollable content
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final p = rows[index];
              final severity = _valueInt(p['severity']);
              final clock = _valueInt(p['clock']);
              final start = clock == 0 ? '' : df.format(DateTime.fromMillisecondsSinceEpoch(clock * 1000));
              final duration = Duration(seconds: _durationSeconds(p));
              final name = _valueString(p['name'] ?? p['message']);
              final host = _hostOf(p);
              final acknowledged = (p['acknowledges'] is List) && (p['acknowledges'] as List).isNotEmpty;
              
              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Severity column
                    SizedBox(
                      width: 80,
                      child: Row(
                        children: [
                          _SeverityDot(
                            severity: severity,
                            isSelected: _selectedSeverity == severity,
                            onTap: () {
                              final newSeverity = _selectedSeverity == severity ? null : severity;
                              final rows = _getRowsWithFilter(newSeverity, _selectedHostname);
                              widget.onFilterChanged(newSeverity, _selectedHostname, rows.length);
                            },
                          ),
                          const SizedBox(width: 8),
                          Text(severity.toString()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Start column
                    GestureDetector(
                      onTap: () => widget.onDetails(p),
                      child: SizedBox(
                        width: 120, 
                        child: Text(
                          start, 
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Duration column
                    GestureDetector(
                      onTap: () => widget.onDetails(p),
                      child: SizedBox(
                        width: 80, 
                        child: Text(
                          _formatDuration(duration), 
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Name column (expandable)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onDetails(p),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            if (acknowledged) const SizedBox(width: 6),
                            if (acknowledged) const Text('✅'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Host column - match header width (132)
                    SizedBox(
                      width: 132,
                      child: GestureDetector(
                        onTap: () {
                          final newHostname = _selectedHostname == host ? null : host;
                          final rows = _getRowsWithFilter(_selectedSeverity, newHostname);
                          widget.onFilterChanged(_selectedSeverity, newHostname, rows.length);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _selectedHostname == host ? Colors.blue.withOpacity(0.1) : null,
                            border: _selectedHostname == host ? Border.all(color: Colors.blue, width: 1) : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  host,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: _selectedHostname == host ? Colors.blue : Colors.black,
                                    fontWeight: _selectedHostname == host ? FontWeight.bold : null,
                                  ),
                                ),
                              ),
                              if (_selectedHostname == host)
                                const Icon(Icons.filter_alt, size: 16, color: Colors.blue),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SeverityDot extends StatelessWidget {
  final int severity;
  final bool isSelected;
  final VoidCallback onTap;
  
  const _SeverityDot({
    required this.severity,
    this.isSelected = false,
    required this.onTap,
  });

  Color _colorFor(int s, BuildContext context) {
    switch (s) {
      case 1:
        return Colors.blue; // Information
      case 2:
        return Colors.yellow.shade700; // Warning
      case 3:
        return Colors.orange; // Average
      case 4:
        return Colors.deepOrange; // High
      case 5:
        return Colors.red; // Disaster
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(severity, context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
        ),
        child: CircleAvatar(
          radius: 12, 
          backgroundColor: color, 
          child: Icon(
            isSelected ? Icons.filter_alt : Icons.check, 
            color: Colors.white, 
            size: 14
          )
        ),
      ),
    );
  }
}
