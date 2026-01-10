import 'package:flutter/material.dart';
import '../models/blocking_rule.dart';
import '../services/rules_database.dart';
import '../services/platform_service.dart';
import 'rule_edit_screen.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  List<BlockingRule> _rules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRules();
  }

  Future<void> _loadRules() async {
    setState(() => _isLoading = true);
    final rules = await RulesDatabase.instance.getAllRules();
    setState(() {
      _rules = rules;
      _isLoading = false;
    });
  }

  Future<void> _syncRulesToNative() async {
    final enabledRules = _rules.where((r) => r.enabled).toList();
    await PlatformService.setBlockingRules(enabledRules);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _rules.removeAt(oldIndex);
      _rules.insert(newIndex, item);
    });

    await RulesDatabase.instance.reorderRules(_rules);
    await _syncRulesToNative();
  }

  Future<void> _toggleRule(BlockingRule rule) async {
    final updated = rule.copyWith(enabled: !rule.enabled);
    await RulesDatabase.instance.updateRule(updated);
    await _loadRules();
    await _syncRulesToNative();
  }

  Future<void> _deleteRule(BlockingRule rule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Delete "${rule.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && rule.id != null) {
      await RulesDatabase.instance.deleteRule(rule.id!);
      await _loadRules();
      await _syncRulesToNative();
    }
  }

  Future<void> _addRule() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const RuleEditScreen()),
    );

    if (result == true) {
      await _loadRules();
      await _syncRulesToNative();
    }
  }

  Future<void> _editRule(BlockingRule rule) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RuleEditScreen(rule: rule)),
    );

    if (result == true) {
      await _loadRules();
      await _syncRulesToNative();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocking Rules'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rules.isEmpty
              ? _buildEmptyState()
              : _buildRulesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRule,
        icon: const Icon(Icons.add),
        label: const Text('Add Rule'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rule,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No blocking rules yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first rule',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Drag to reorder. First matching rule wins.',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _rules.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final rule = _rules[index];
              return _RuleListTile(
                key: ValueKey(rule.id),
                rule: rule,
                index: index,
                onToggle: () => _toggleRule(rule),
                onEdit: () => _editRule(rule),
                onDelete: () => _deleteRule(rule),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RuleListTile extends StatelessWidget {
  final BlockingRule rule;
  final int index;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleListTile({
    super.key,
    required this.rule,
    required this.index,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.drag_handle,
              color: Colors.grey.shade400,
            ),
          ),
        ),
        title: Text(
          rule.displayName,
          style: TextStyle(
            decoration: rule.enabled ? null : TextDecoration.lineThrough,
            color: rule.enabled ? null : Colors.grey,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _typeColor(rule.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rule.typeLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: _typeColor(rule.type),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (rule.imagePath != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.image, size: 14, color: Colors.grey.shade600),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: rule.enabled,
              onChanged: (_) => onToggle(),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  Color _typeColor(RuleType type) {
    switch (type) {
      case RuleType.individual:
        return Colors.blue;
      case RuleType.nameContains:
        return Colors.orange;
      case RuleType.nameStartsWith:
        return Colors.purple;
      case RuleType.regex:
        return Colors.red;
      case RuleType.company:
        return Colors.green;
    }
  }
}
