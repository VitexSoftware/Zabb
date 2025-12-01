import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  
  // Filter state that persists across refreshes
  int? _selectedSeverity;
  String? _selectedHostname;
  String _searchQuery = '';
  bool _ignoreAcknowledged = true; // Default enabled to hide acknowledged problems
  
  // Severity ignore settings (default: show all severities)
  Map<int, bool> _ignoreSeverities = {
    0: false, // Not classified
    1: false, // Information
    2: false, // Warning
    3: false, // Average
    4: false, // High
    5: false, // Disaster
  };

  @override
  void initState() {
    super.initState();
    _future = _auth.fetchProblems();
    _startRefreshTimer();
    _loadIgnoreAcknowledgedSetting();
    _loadIgnoreSeveritySettings();
  }

  Future<void> _loadIgnoreAcknowledgedSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ignoreAcknowledged = prefs.getBool('ignore_acknowledged') ?? true;
    });
  }

  Future<void> _saveIgnoreAcknowledgedSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ignore_acknowledged', value);
    setState(() {
      _ignoreAcknowledged = value;
    });
  }

  Future<void> _loadIgnoreSeveritySettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      for (int severity = 0; severity <= 5; severity++) {
        _ignoreSeverities[severity] = prefs.getBool('ignore_severity_$severity') ?? false;
      }
    });
  }

  Future<void> _saveIgnoreSeveritySetting(int severity, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ignore_severity_$severity', value);
    setState(() {
      _ignoreSeverities[severity] = value;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  void _showConfigurationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Server Settings'),
              subtitle: const Text('Configure Zabbix server connection'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/configure');
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Ignore Acknowledged'),
              subtitle: const Text('Hide acknowledged problems from the list'),
              value: _ignoreAcknowledged,
              onChanged: (value) {
                _saveIgnoreAcknowledgedSetting(value);
                Navigator.pop(context);
              },
              secondary: const Icon(Icons.visibility_off),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Ignore Severities', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ..._buildSeveritySwitches(context),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Sign out from current session'),
              onTap: () async {
                Navigator.pop(context); // Close dialog first
                try {
                  await _auth.logout();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/welcome',
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
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset('assets/zabb.svg', height: 24, width: 24),
            const SizedBox(width: 16),
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: GestureDetector(
                      onTap: () => _searchFocusNode.requestFocus(),
                      child: const Icon(Icons.search, size: 20),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    hintStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
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
            onPressed: () => _showConfigurationDialog(context),
            tooltip: 'Settings',
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
            searchQuery: _searchQuery,
            ignoreAcknowledged: _ignoreAcknowledged,
            ignoreSeverities: _ignoreSeverities,
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

  List<Widget> _buildSeveritySwitches(BuildContext context) {
    final severityNames = {
      0: 'Not classified',
      1: 'Information',
      2: 'Warning',
      3: 'Average',
      4: 'High',
      5: 'Disaster',
    };
    
    final severityIcons = {
      0: Icons.help_outline,
      1: Icons.info_outline,
      2: Icons.warning_amber_outlined,
      3: Icons.error_outline,
      4: Icons.priority_high,
      5: Icons.dangerous_outlined,
    };

    return severityNames.entries.map((entry) {
      final severity = entry.key;
      final name = entry.value;
      final icon = severityIcons[severity] ?? Icons.circle_outlined;
      
      return SwitchListTile(
        title: Text('Ignore $name'),
        subtitle: Text('Hide $name severity problems'),
        value: _ignoreSeverities[severity] ?? false,
        onChanged: (value) {
          _saveIgnoreSeveritySetting(severity, value);
        },
        secondary: Icon(icon),
        dense: true,
      );
    }).toList();
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
  final String searchQuery;
  final bool ignoreAcknowledged;
  final Map<int, bool> ignoreSeverities;
  final void Function(int?, String?, int) onFilterChanged;
  
  const _ProblemsTable({
    required this.items, 
    required this.onDetails, 
    required this.onRefresh,
    required this.selectedSeverity,
    required this.selectedHostname,
    required this.searchQuery,
    required this.ignoreAcknowledged,
    required this.ignoreSeverities,
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
    
    // Apply search filter if search query exists
    if (widget.searchQuery.isNotEmpty) {
      rows = rows.where((item) {
        final problemName = _valueString(item['name'] ?? item['message']).toLowerCase();
        final hostname = _hostOf(item).toLowerCase();
        return problemName.contains(widget.searchQuery) || hostname.contains(widget.searchQuery);
      }).toList();
    }
    
    // Apply severity filter if one is selected
    if (severityFilter != null) {
      rows = rows.where((item) => _valueInt(item['severity']) == severityFilter).toList();
    }
    
    // Apply hostname filter if one is selected
    if (hostnameFilter != null) {
      rows = rows.where((item) => _hostOf(item) == hostnameFilter).toList();
    }
    
    // Apply acknowledged filter if enabled
    if (widget.ignoreAcknowledged) {
      rows = rows.where((item) {
        final acknowledges = item['acknowledges'] as List?;
        return acknowledges == null || acknowledges.isEmpty;
      }).toList();
    }
    
    // Apply severity ignore filters
    rows = rows.where((item) {
      final severity = _valueInt(item['severity']);
      final ignoreThisSeverity = widget.ignoreSeverities[severity] ?? false;
      return !ignoreThisSeverity;
    }).toList();
    
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

  Widget _buildDateTimeColumn(DateTime dateTime) {
    final now = DateTime.now();
    final isToday = dateTime.year == now.year && 
                   dateTime.month == now.month && 
                   dateTime.day == now.day;
    
    if (isToday) {
      // Show only time for today's events
      return Text(
        DateFormat('HH:mm').format(dateTime),
        style: const TextStyle(fontSize: 11),
      );
    } else {
      // Show date and time on separate lines for older events
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('MM-dd').format(dateTime),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
          Text(
            DateFormat('HH:mm').format(dateTime),
            style: const TextStyle(fontSize: 11),
          ),
        ],
      );
    }
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
            columnSpacing: 4,
            columns: [
              DataColumn(
                label: const SizedBox(width: 32, child: Text('Sev', style: TextStyle(fontSize: 12))),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const SizedBox(width: 50, child: Text('Start', style: TextStyle(fontSize: 12))),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const SizedBox(width: 60, child: Text('Duration', style: TextStyle(fontSize: 12))),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const Text('Name', style: TextStyle(fontSize: 12)),
                onSort: (i, asc) => setState(() { _sortColumnIndex = i; _sortAscending = asc; }),
              ),
              DataColumn(
                label: const SizedBox(width: 80, child: Text('Host', style: TextStyle(fontSize: 12))),
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
              final startDateTime = clock == 0 ? null : DateTime.fromMillisecondsSinceEpoch(clock * 1000);
              final duration = Duration(seconds: _durationSeconds(p));
              final name = _valueString(p['name'] ?? p['message']);
              final host = _hostOf(p);
              final acknowledged = (p['acknowledges'] is List) && (p['acknowledges'] as List).isNotEmpty;
              
              return Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    // Severity column
                    SizedBox(
                      width: 32,
                      child: _SeverityDot(
                        severity: severity,
                        isSelected: _selectedSeverity == severity,
                        onTap: () {
                          final newSeverity = _selectedSeverity == severity ? null : severity;
                          final rows = _getRowsWithFilter(newSeverity, _selectedHostname);
                          widget.onFilterChanged(newSeverity, _selectedHostname, rows.length);
                        },
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Start column with responsive formatting
                    GestureDetector(
                      onTap: () => widget.onDetails(p),
                      child: SizedBox(
                        width: 50,
                        child: startDateTime == null 
                            ? const Text('', style: TextStyle(fontSize: 11))
                            : _buildDateTimeColumn(startDateTime),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Duration column
                    GestureDetector(
                      onTap: () => widget.onDetails(p),
                      child: SizedBox(
                        width: 60, 
                        child: Text(
                          _formatDuration(duration), 
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
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
                                maxLines: 2,
                                style: const TextStyle(fontSize: 12, height: 1.2),
                              ),
                            ),
                            if (acknowledged) const SizedBox(width: 2),
                            if (acknowledged) const Text('✅', style: TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    // Host column - compact mobile layout
                    SizedBox(
                      width: 80,
                      child: GestureDetector(
                        onTap: () {
                          final newHostname = _selectedHostname == host ? null : host;
                          final rows = _getRowsWithFilter(_selectedSeverity, newHostname);
                          widget.onFilterChanged(_selectedSeverity, newHostname, rows.length);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                          decoration: BoxDecoration(
                            color: _selectedHostname == host ? Colors.blue.withOpacity(0.1) : null,
                            border: _selectedHostname == host ? Border.all(color: Colors.blue, width: 1) : null,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            host,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: _selectedHostname == host ? Colors.blue : Colors.black87,
                              fontWeight: _selectedHostname == host ? FontWeight.bold : null,
                            ),
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
