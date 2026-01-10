import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/platform_service.dart';
import 'services/rules_database.dart';
import 'screens/rules_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  hideNavigationBar(); // hides buttons on start
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Blocker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasOverlayPermission = false;
  bool _hasUsageStatsPermission = false;
  bool _isMonitoring = false;
  int _ruleCount = 0;

  static const String _monitoringKey = 'is_monitoring_enabled';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
      _loadRuleCount();
      _checkMonitoringStatus();
    }
  }

  Future<void> _initializeState() async {
    await _checkPermissions();
    await _loadRuleCount();
    await _checkMonitoringStatus();

    // If monitoring was enabled before, re-sync rules
    if (_isMonitoring) {
      final rules = await RulesDatabase.instance.getEnabledRules();
      await PlatformService.setBlockingRules(rules);
    }
  }

  Future<void> _checkPermissions() async {
    final overlay = await PlatformService.hasOverlayPermission();
    final usageStats = await PlatformService.hasUsageStatsPermission();
    setState(() {
      _hasOverlayPermission = overlay;
      _hasUsageStatsPermission = usageStats;
    });
  }

  Future<void> _loadRuleCount() async {
    final rules = await RulesDatabase.instance.getEnabledRules();
    setState(() => _ruleCount = rules.length);
  }

  Future<void> _checkMonitoringStatus() async {
    // Check if service is actually running
    final isRunning = await PlatformService.isMonitoring();

    // Also check saved preference
    final prefs = await SharedPreferences.getInstance();
    final wasEnabled = prefs.getBool(_monitoringKey) ?? false;

    // If service should be running but isn't, restart it
    if (wasEnabled &&
        !isRunning &&
        _hasOverlayPermission &&
        _hasUsageStatsPermission) {
      await _syncAndStartMonitoring();
    } else {
      setState(() => _isMonitoring = isRunning);
    }
  }

  Future<void> _syncAndStartMonitoring() async {
    // Load rules from database and send to native
    final rules = await RulesDatabase.instance.getEnabledRules();
    await PlatformService.setBlockingRules(rules);
    await PlatformService.startMonitoring();

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringKey, true);

    setState(() => _isMonitoring = true);
  }

  Future<void> _stopMonitoring() async {
    await PlatformService.stopMonitoring();

    // Save preference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringKey, false);

    setState(() => _isMonitoring = false);
  }

  void _openRulesScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RulesScreen()),
    );
    _loadRuleCount();

    // Re-sync rules if monitoring
    if (_isMonitoring) {
      final rules = await RulesDatabase.instance.getEnabledRules();
      await PlatformService.setBlockingRules(rules);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allPermissionsGranted =
        _hasOverlayPermission && _hasUsageStatsPermission;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Blocker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _isMonitoring ? Icons.shield : Icons.shield_outlined,
                      size: 64,
                      color: _isMonitoring ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isMonitoring
                          ? 'Protection Active'
                          : 'Protection Inactive',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_isMonitoring)
                      Text(
                        'Monitoring $_ruleCount blocking rules',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Permissions Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Permissions',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    _PermissionRow(
                      label: 'Overlay Permission',
                      granted: _hasOverlayPermission,
                      onRequest: PlatformService.requestOverlayPermission,
                    ),
                    const SizedBox(height: 8),
                    _PermissionRow(
                      label: 'Usage Stats Permission',
                      granted: _hasUsageStatsPermission,
                      onRequest: PlatformService.requestUsageStatsPermission,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Rules Card
            Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.rule)),
                title: const Text('Blocking Rules'),
                subtitle: Text('$_ruleCount rules configured'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openRulesScreen,
              ),
            ),
            const SizedBox(height: 24),

            // Start/Stop Button
            if (allPermissionsGranted)
              FilledButton.icon(
                onPressed: _isMonitoring
                    ? _stopMonitoring
                    : _syncAndStartMonitoring,
                icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _isMonitoring ? 'Stop Protection' : 'Start Protection',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: _isMonitoring ? Colors.red : null,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Grant all permissions to enable protection',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),

            if (_ruleCount == 0 && allPermissionsGranted) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openRulesScreen,
                icon: const Icon(Icons.add),
                label: const Text('Create your first blocking rule'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionRow({
    required this.label,
    required this.granted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.error_outline,
          color: granted ? Colors.green : Colors.orange,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        if (!granted)
          TextButton(onPressed: onRequest, child: const Text('Grant'))
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('Granted', style: TextStyle(color: Colors.green)),
          ),
      ],
    );
  }
}

void hideNavigationBar() {
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode
        .immersiveSticky, // keeps the navbar hidden and brings it back only on swipe
  );
}
