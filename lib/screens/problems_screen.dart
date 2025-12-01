import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zabb/services/auth_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

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
  int _refreshInterval = 30; // Default 30 seconds
  
  // Notification settings
  bool _notificationsEnabled = true;
  String _selectedSoundFile = '';
  Map<int, String> _severitySounds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  Set<String> _knownProblemIds = {};
  
  // Sort settings that persist across refreshes
  String _sortBy = 'clock'; // Default sort by time
  bool _sortAscending = false; // Default newest first
  
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
    _loadNotificationSettings();
    _loadSortSettings();
    _initializeKnownProblems();
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

  Future<void> _loadSortSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sortBy = prefs.getString('sort_by') ?? 'clock';
      _sortAscending = prefs.getBool('sort_ascending') ?? false;
    });
  }

  Future<void> _saveSortSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sort_by', _sortBy);
    await prefs.setBool('sort_ascending', _sortAscending);
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
    _countdownSeconds = _refreshInterval;
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
      _future = _auth.fetchProblems().then((problems) {
        _checkForNewProblems(problems);
        return problems;
      });
      _startRefreshTimer();
    });
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _selectedSoundFile = prefs.getString('selected_sound_file') ?? '';
      
      // Load severity-specific sounds
      for (int severity = 0; severity <= 5; severity++) {
        _severitySounds[severity] = prefs.getString('severity_sound_$severity') ?? '';
      }
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('selected_sound_file', _selectedSoundFile);
    
    // Save severity-specific sounds
    for (int severity = 0; severity <= 5; severity++) {
      await prefs.setString('severity_sound_$severity', _severitySounds[severity] ?? '');
    }
  }

  Future<void> _playNotificationSound() async {
    if (_selectedSoundFile.isNotEmpty) {
      try {
        if (_selectedSoundFile.startsWith('sounds/')) {
          await _audioPlayer.play(AssetSource(_selectedSoundFile));
        } else {
          await _audioPlayer.play(DeviceFileSource(_selectedSoundFile));
        }
      } catch (e) {
        print('Error playing notification sound: $e');
      }
    }
  }

  Future<void> _playNotificationSoundForSeverity(int severity) async {
    final soundFile = _severitySounds[severity] ?? _selectedSoundFile;
    if (soundFile.isNotEmpty) {
      try {
        if (soundFile.startsWith('sounds/')) {
          await _audioPlayer.play(AssetSource(soundFile));
        } else {
          await _audioPlayer.play(DeviceFileSource(soundFile));
        }
      } catch (e) {
        print('Error playing severity notification sound: $e');
      }
    }
  }

  void _checkForNewProblems(List<Map<String, dynamic>> problems) {
    if (!_notificationsEnabled) return;
    
    final currentProblemIds = problems.map((p) => p['eventid'].toString()).toSet();
    final newProblems = currentProblemIds.difference(_knownProblemIds);
    
    if (newProblems.isNotEmpty && _knownProblemIds.isNotEmpty) {
      // Find the highest severity of new problems and get the first new problem details
      int highestSeverity = 0;
      Map<String, dynamic>? firstNewProblem;
      
      for (final problem in problems) {
        if (newProblems.contains(problem['eventid'].toString())) {
          final severity = int.tryParse(problem['priority'].toString()) ?? 0;
          if (severity > highestSeverity) {
            highestSeverity = severity;
            firstNewProblem = problem;
          }
          // If we haven't found a problem yet, take this one
          if (firstNewProblem == null) {
            firstNewProblem = problem;
          }
        }
      }
      
      _playNotificationSoundForSeverity(highestSeverity);
      
      // Show popup for the first new problem
      if (firstNewProblem != null && mounted) {
        _showNewProblemPopup(context, firstNewProblem, newProblems.length);
      }
    }
    
    _knownProblemIds = currentProblemIds;
  }

  Future<void> _initializeKnownProblems() async {
    try {
      final problems = await _auth.fetchProblems();
      _knownProblemIds = problems.map((p) => p['eventid'].toString()).toSet();
    } catch (e) {
      print('Error initializing known problems: $e');
    }
  }

  void _showNewProblemPopup(BuildContext context, Map<String, dynamic> problem, int totalNewProblems) {
    final triggerId = problem['objectid']?.toString() ?? '';
    final hostname = triggerId.isNotEmpty ? AuthService.instance.getHostNameByTriggerId(triggerId) : 'Unknown';
    final severity = _parseInt(problem['severity'] ?? 0, defaultValue: 0);
    final problemName = problem['name']?.toString() ?? 'Unknown Problem';
    final clock = _parseInt(problem['clock'] ?? 0, defaultValue: 0);
    
    // Format timestamp
    final timestamp = clock > 0 
        ? DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(clock * 1000))
        : 'Unknown';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning,
              color: _getColorForSeverity(severity),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'New Problem${totalNewProblems > 1 ? 's' : ''} Detected',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (totalNewProblems > 1)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalNewProblems new problems detected. Showing details of the most severe.',
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            _buildDetailRow('Host:', hostname),
            _buildDetailRow('Time:', timestamp),
            _buildDetailRow('Severity:', _getSeverityText(severity)),
            const SizedBox(height: 8),
            Text(
              'Problem:',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getColorForSeverity(severity).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getColorForSeverity(severity).withOpacity(0.3)),
              ),
              child: Text(
                problemName,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDetails(context, problem);
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  Color _getColorForSeverity(int severity) {
    switch (severity) {
      case 5: return Colors.red; // Disaster
      case 4: return Colors.deepOrange; // High
      case 3: return Colors.orange; // Average
      case 2: return Colors.yellow.shade700; // Warning
      case 1: return Colors.blue; // Information
      default: return Colors.grey; // Not classified
    }
  }

  void _showConfigurationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configuration', style: TextStyle(fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings, size: 18),
              title: const Text('Server Settings', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Configure Zabbix server connection', style: TextStyle(fontSize: 10)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/configure');
              },
              dense: true,
            ),
            const Divider(height: 8),
            ListTile(
              leading: Icon(
                _notificationsEnabled ? Icons.notifications : Icons.notifications_off,
                size: 18,
              ),
              title: const Text('Notifications', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Configure audio notifications', style: TextStyle(fontSize: 10)),
              onTap: () {
                Navigator.pop(context);
                _showNotificationConfigScreen(context);
              },
              dense: true,
            ),
            const Divider(height: 8),
            SwitchListTile(
              title: const Text('Ignore Acknowledged', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Hide acknowledged problems from the list', style: TextStyle(fontSize: 10)),
              value: _ignoreAcknowledged,
              onChanged: (value) {
                _saveIgnoreAcknowledgedSetting(value);
                Navigator.pop(context);
              },
              secondary: const Icon(Icons.visibility_off, size: 18),
              dense: true,
            ),
            const Divider(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text('Ignore Severities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            ..._buildSeveritySwitches(context),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red, size: 18),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontSize: 12)),
              subtitle: const Text('Sign out from current session', style: TextStyle(fontSize: 10)),
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

  void _showNotificationConfigScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _NotificationConfigScreen(
          notificationsEnabled: _notificationsEnabled,
          selectedSoundFile: _selectedSoundFile,
          severitySounds: Map.from(_severitySounds),
          onSettingsChanged: (enabled, defaultSound, severitySounds) {
            setState(() {
              _notificationsEnabled = enabled;
              _selectedSoundFile = defaultSound;
              _severitySounds = Map.from(severitySounds);
            });
            _saveNotificationSettings();
          },
          audioPlayer: _audioPlayer,
        ),
      ),
    );
  }

  Future<void> _selectSoundFile(BuildContext context) async {
    final List<String> soundOptions = [
      'sounds/notification.wav',
      'sounds/alert.mp3', 
      'sounds/bell.wav',
      'sounds/chime.flac',
      'sounds/explosion.mp3'
    ];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Sound', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...soundOptions.map((sound) => ListTile(
              leading: const Icon(Icons.music_note, size: 18),
              title: Text(sound.split('/').last, style: const TextStyle(fontSize: 14)),
              onTap: () {
                setState(() {
                  _selectedSoundFile = sound;
                });
                _saveNotificationSettings();
                Navigator.pop(context);
              },
              dense: true,
            )),
            const Divider(height: 8),
            ListTile(
              leading: const Icon(Icons.folder_open, size: 18),
              title: const Text('Browse Files...', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              subtitle: const Text('Choose custom audio file', style: TextStyle(fontSize: 11)),
              onTap: () => _pickCustomSoundFile(context),
              dense: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomSoundFile(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final String filePath = result.files.single.path!;
        setState(() {
          _selectedSoundFile = filePath;
        });
        await _saveNotificationSettings();
        
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: ${result.files.single.name}'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error picking sound file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting file. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
            sortBy: _sortBy,
            sortAscending: _sortAscending,
            onSortChanged: (sortBy, ascending) {
              setState(() {
                _sortBy = sortBy;
                _sortAscending = ascending;
              });
              _saveSortSettings();
            },
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
        title: Text('Ignore $name', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
        subtitle: null,
        value: _ignoreSeverities[severity] ?? false,
        onChanged: (value) {
          _saveIgnoreSeveritySetting(severity, value);
        },
        secondary: Icon(icon, size: 16),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: -4),
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
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
  
  final String sortBy;
  final bool sortAscending;
  final Function(String, bool) onSortChanged;
  
  const _ProblemsTable({
    Key? key,
    required this.items, 
    required this.onDetails, 
    required this.onRefresh,
    required this.selectedSeverity,
    required this.selectedHostname,
    required this.searchQuery,
    required this.ignoreAcknowledged,
    required this.ignoreSeverities,
    required this.onFilterChanged,
    required this.sortBy,
    required this.sortAscending,
    required this.onSortChanged,
  }) : super(key: key);

  @override
  State<_ProblemsTable> createState() => _ProblemsTableState();
}

class _ProblemsTableState extends State<_ProblemsTable> {
  late int _sortColumnIndex;
  late bool _sortAscending;
  
  int? get _selectedSeverity => widget.selectedSeverity;
  String? get _selectedHostname => widget.selectedHostname;
  
  @override
  void initState() {
    super.initState();
    _updateSortFromWidget();
    // Notify parent of initial filtered count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rows = _rows;
      widget.onFilterChanged(_selectedSeverity, _selectedHostname, rows.length);
    });
  }
  
  @override
  void didUpdateWidget(_ProblemsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSortFromWidget();
    // Notify parent when widget updates (after refresh)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rows = _rows;
      widget.onFilterChanged(_selectedSeverity, _selectedHostname, rows.length);
    });
  }
  
  void _updateSortFromWidget() {
    // Map sortBy string to column index
    switch (widget.sortBy) {
      case 'priority':
        _sortColumnIndex = 0;
        break;
      case 'clock':
        _sortColumnIndex = 1;
        break;
      case 'name':
        _sortColumnIndex = 2;
        break;
      default:
        _sortColumnIndex = 0;
    }
    _sortAscending = widget.sortAscending;
  }
  
  void _updateSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
    });
    
    // Notify parent of sort changes
    String sortBy;
    switch (columnIndex) {
      case 0:
        sortBy = 'priority';
        break;
      case 1:
        sortBy = 'clock';
        break;
      case 2:
      case 3: // Name column
        sortBy = 'name';
        break;
      default:
        sortBy = 'priority';
    }
    widget.onSortChanged(sortBy, ascending);
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
                onSort: (i, asc) => _updateSort(i, asc),
              ),
              DataColumn(
                label: const SizedBox(width: 50, child: Text('Start', style: TextStyle(fontSize: 12))),
                onSort: (i, asc) => _updateSort(i, asc),
              ),
              DataColumn(
                label: const SizedBox(width: 60, child: Text('Duration', style: TextStyle(fontSize: 12))),
                onSort: (i, asc) => _updateSort(i, asc),
              ),
              DataColumn(
                label: const Text('Name', style: TextStyle(fontSize: 12)),
                onSort: (i, asc) => _updateSort(i, asc),
              ),
              DataColumn(
                label: const SizedBox(width: 80, child: Text('Host', style: TextStyle(fontSize: 12))),
                onSort: (i, asc) => _updateSort(i, asc),
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

class _NotificationConfigScreen extends StatefulWidget {
  final bool notificationsEnabled;
  final String selectedSoundFile;
  final Map<int, String> severitySounds;
  final Function(bool, String, Map<int, String>) onSettingsChanged;
  final AudioPlayer audioPlayer;

  const _NotificationConfigScreen({
    required this.notificationsEnabled,
    required this.selectedSoundFile,
    required this.severitySounds,
    required this.onSettingsChanged,
    required this.audioPlayer,
  });

  @override
  State<_NotificationConfigScreen> createState() => _NotificationConfigScreenState();
}

class _NotificationConfigScreenState extends State<_NotificationConfigScreen> {
  late bool _notificationsEnabled;
  late String _defaultSoundFile;
  late Map<int, String> _severitySounds;

  final Map<int, String> _severityNames = {
    0: 'Not classified',
    1: 'Information',
    2: 'Warning', 
    3: 'Average',
    4: 'High',
    5: 'Disaster',
  };

  final Map<int, IconData> _severityIcons = {
    0: Icons.help_outline,
    1: Icons.info_outline,
    2: Icons.warning_amber_outlined,
    3: Icons.error_outline,
    4: Icons.priority_high,
    5: Icons.dangerous_outlined,
  };

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.notificationsEnabled;
    _defaultSoundFile = widget.selectedSoundFile;
    _severitySounds = Map.from(widget.severitySounds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings', style: TextStyle(fontSize: 16)),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // General notification toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Notifications', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      subtitle: const Text('Play sounds for new Zabbix problems', style: TextStyle(fontSize: 13)),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        _saveSettings();
                      },
                    ),
                  ],
                ),
              ),
            ),
            
            if (_notificationsEnabled) ...[
              const SizedBox(height: 16),
              
              // Default sound selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Default Sound', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.audiotrack),
                        title: const Text('Select Default Sound'),
                        subtitle: Text(_getDisplayName(_defaultSoundFile)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_defaultSoundFile.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                onPressed: () => _testSound(_defaultSoundFile),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _selectSoundForDefault(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Per-severity sound configuration
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Severity-Specific Sounds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const Text('Override default sound for specific problem severities', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 12),
                      ..._severityNames.entries.map((entry) {
                        final severity = entry.key;
                        final name = entry.value;
                        final icon = _severityIcons[severity] ?? Icons.circle_outlined;
                        final soundFile = _severitySounds[severity] ?? '';
                        
                        return ListTile(
                          leading: Icon(icon, size: 20),
                          title: Text(name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            soundFile.isEmpty ? 'Use default sound' : _getDisplayName(soundFile),
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (soundFile.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.play_arrow, size: 18),
                                  onPressed: () => _testSound(soundFile),
                                ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 18),
                                onSelected: (value) {
                                  if (value == 'select') {
                                    _selectSoundForSeverity(severity);
                                  } else if (value == 'clear') {
                                    _clearSeveritySound(severity);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'select',
                                    child: Row(
                                      children: [
                                        Icon(Icons.audiotrack, size: 16),
                                        SizedBox(width: 8),
                                        Text('Select Sound'),
                                      ],
                                    ),
                                  ),
                                  if (soundFile.isNotEmpty)
                                    const PopupMenuItem(
                                      value: 'clear',
                                      child: Row(
                                        children: [
                                          Icon(Icons.clear, size: 16),
                                          SizedBox(width: 8),
                                          Text('Use Default'),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          dense: true,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getDisplayName(String soundFile) {
    if (soundFile.isEmpty) return 'No sound selected';
    if (soundFile.startsWith('sounds/')) {
      return soundFile.split('/').last;
    }
    return soundFile.split('/').last;
  }

  Future<void> _testSound(String soundFile) async {
    try {
      if (soundFile.startsWith('sounds/')) {
        await widget.audioPlayer.play(AssetSource(soundFile));
      } else {
        await widget.audioPlayer.play(DeviceFileSource(soundFile));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing sound: $e')),
        );
      }
    }
  }

  void _selectSoundForDefault() async {
    final result = await _showSoundSelectionDialog();
    if (result != null) {
      setState(() {
        _defaultSoundFile = result;
      });
      _saveSettings();
    }
  }

  void _selectSoundForSeverity(int severity) async {
    final result = await _showSoundSelectionDialog();
    if (result != null) {
      setState(() {
        _severitySounds[severity] = result;
      });
      _saveSettings();
    }
  }

  void _clearSeveritySound(int severity) {
    setState(() {
      _severitySounds[severity] = '';
    });
    _saveSettings();
  }

  Future<String?> _showSoundSelectionDialog() async {
    final soundOptions = [
      'sounds/notification.wav',
      'sounds/alert.mp3',
      'sounds/bell.wav', 
      'sounds/chime.flac',
      'sounds/explosion.mp3'
    ];

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Sound'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...soundOptions.map((sound) => ListTile(
              leading: const Icon(Icons.music_note, size: 18),
              title: Text(sound.split('/').last),
              onTap: () => Navigator.pop(context, sound),
              dense: true,
            )),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.folder_open, size: 18),
              title: const Text('Browse Files...'),
              onTap: () async {
                Navigator.pop(context);
                final customFile = await _pickCustomSoundFile();
                if (customFile != null) {
                  Navigator.of(context).pop(customFile);
                }
              },
              dense: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickCustomSoundFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected: ${result.files.single.name}')),
          );
        }
        return filePath;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error selecting file')),
        );
      }
    }
    return null;
  }

  void _saveSettings() {
    widget.onSettingsChanged(_notificationsEnabled, _defaultSoundFile, _severitySounds);
  }
}
