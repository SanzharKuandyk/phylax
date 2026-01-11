import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/blocking_rule.dart';
import '../services/rules_database.dart';
import '../services/platform_service.dart';
import 'preview_screen.dart';

class RuleEditScreen extends StatefulWidget {
  final BlockingRule? rule;

  const RuleEditScreen({super.key, this.rule});

  @override
  State<RuleEditScreen> createState() => _RuleEditScreenState();
}

class _RuleEditScreenState extends State<RuleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late RuleType _selectedType;
  late TextEditingController _nameController;
  late TextEditingController _patternController;
  late double _textX;
  late double _textY;
  late double _imageScale;
  late double _imageOffsetX;
  late double _imageOffsetY;
  List<String> _imagePaths = [];
  List<String> _overlayTexts = [];
  bool _useDefaultQuotes = true;
  List<AppInfo> _installedApps = [];
  bool _isLoading = true;

  bool get _isEditing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.rule?.type ?? RuleType.individual;
    _nameController = TextEditingController(text: widget.rule?.name ?? '');
    _patternController = TextEditingController(text: widget.rule?.pattern ?? '');
    _textX = widget.rule?.textPositionX ?? 0.5;
    _textY = widget.rule?.textPositionY ?? 0.5;
    _imageScale = widget.rule?.imageScale ?? 1.0;
    _imageOffsetX = widget.rule?.imageOffsetX ?? 0.0;
    _imageOffsetY = widget.rule?.imageOffsetY ?? 0.0;
    _imagePaths = List.from(widget.rule?.imagePaths ?? []);

    // Check if using custom quotes or defaults
    final ruleTexts = widget.rule?.overlayTexts ?? [];
    _useDefaultQuotes = ruleTexts.isEmpty ||
        _listsEqual(ruleTexts, BlockingRule.defaultQuotes);
    _overlayTexts = _useDefaultQuotes ? [] : List.from(ruleTexts);

    _loadApps();
  }

  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _patternController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final apps = await PlatformService.getInstalledApps();
    setState(() {
      _installedApps = apps;
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);

    if (result != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'overlay_${DateTime.now().millisecondsSinceEpoch}${p.extension(result.path)}';
      final savedPath = p.join(appDir.path, fileName);
      await File(result.path).copy(savedPath);

      setState(() {
        _imagePaths.add(savedPath);
        // Reset image transformations when first image is added
        if (_imagePaths.length == 1) {
          _imageScale = 1.0;
          _imageOffsetX = 0.0;
          _imageOffsetY = 0.0;
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
      if (_imagePaths.isEmpty) {
        _imageScale = 1.0;
        _imageOffsetX = 0.0;
        _imageOffsetY = 0.0;
      }
    });
  }

  void _addQuote() {
    setState(() {
      _overlayTexts.add('');
    });
  }

  void _removeQuote(int index) {
    setState(() {
      _overlayTexts.removeAt(index);
    });
  }

  void _updateQuote(int index, String value) {
    _overlayTexts[index] = value;
  }

  String? _validatePattern(String? value) {
    final pattern = value?.trim() ?? '';
    if (pattern.isEmpty) {
      switch (_selectedType) {
        case RuleType.individual:
          return 'Please select an app';
        case RuleType.nameContains:
          return 'Please enter text to search for';
        case RuleType.nameStartsWith:
          return 'Please enter text to match';
        case RuleType.regex:
          return 'Please enter a regex pattern';
        case RuleType.company:
          return 'Please select or enter a company prefix';
      }
    }

    if (_selectedType == RuleType.regex) {
      try {
        RegExp(pattern);
      } catch (_) {
        return 'Invalid regex pattern';
      }
    }

    return null;
  }

  Future<void> _save() async {
    // Validate pattern manually for app picker since it's not a TextFormField
    final patternError = _validatePattern(_patternController.text);
    if (patternError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(patternError), backgroundColor: Colors.red),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final ruleName = _nameController.text.trim();

    // Get overlay texts - use defaults if toggle is on, otherwise use custom
    List<String>? overlayTexts;
    if (_useDefaultQuotes) {
      overlayTexts = null; // Will use defaults
    } else {
      // Filter out empty quotes
      overlayTexts = _overlayTexts
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (overlayTexts.isEmpty) {
        overlayTexts = null; // Fall back to defaults
      }
    }

    final rule = BlockingRule(
      id: widget.rule?.id,
      name: ruleName.isEmpty ? null : ruleName,
      type: _selectedType,
      pattern: _patternController.text.trim(),
      order: widget.rule?.order ?? -1,
      enabled: widget.rule?.enabled ?? true,
      imagePaths: _imagePaths,
      overlayTexts: overlayTexts,
      textPositionX: _textX,
      textPositionY: _textY,
      imageScale: _imageScale,
      imageOffsetX: _imageOffsetX,
      imageOffsetY: _imageOffsetY,
    );

    if (_isEditing) {
      await RulesDatabase.instance.updateRule(rule);
    } else {
      await RulesDatabase.instance.insertRule(rule);
    }

    if (mounted) Navigator.pop(context, true);
  }

  void _openPreview() async {
    // Use first image for preview, or null if none
    final previewImage = _imagePaths.isNotEmpty ? _imagePaths.first : null;
    // Use first custom text, or first default quote
    final previewText = _useDefaultQuotes
        ? BlockingRule.defaultQuotes.first
        : (_overlayTexts.isNotEmpty && _overlayTexts.first.isNotEmpty
            ? _overlayTexts.first
            : BlockingRule.defaultQuotes.first);

    final result = await Navigator.push<PreviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          imagePath: previewImage,
          text: previewText,
          textX: _textX,
          textY: _textY,
          imageScale: _imageScale,
          imageOffsetX: _imageOffsetX,
          imageOffsetY: _imageOffsetY,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _textX = result.textX;
        _textY = result.textY;
        _imageScale = result.imageScale;
        _imageOffsetX = result.imageOffsetX;
        _imageOffsetY = result.imageOffsetY;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Rule' : 'New Rule'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Rule Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Rule Name (optional)',
                      hintText: 'e.g., "Social Media Block"',
                      border: OutlineInputBorder(),
                      helperText: 'Leave empty for auto-generated name',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Rule Type Selection
                  Text('Rule Type', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _buildTypeSelector(),
                  const SizedBox(height: 24),

                  // Pattern Input (varies by type)
                  _buildPatternInput(),
                  const SizedBox(height: 24),

                  // Overlay Configuration
                  Text('Overlay Settings', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  _buildImagePicker(),
                  const SizedBox(height: 16),
                  _buildTextInput(),
                  const SizedBox(height: 16),
                  _buildOverlayPreview(),
                ],
              ),
            ),
    );
  }

  Widget _buildTypeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: RuleType.values.map((type) {
        final isSelected = _selectedType == type;
        return ChoiceChip(
          label: Text(_typeLabel(type)),
          selected: isSelected,
          onSelected: (_) => setState(() {
            _selectedType = type;
            _patternController.clear();
          }),
        );
      }).toList(),
    );
  }

  Widget _buildPatternInput() {
    switch (_selectedType) {
      case RuleType.individual:
        return _buildAppPicker();
      case RuleType.company:
        return _buildCompanyPicker();
      case RuleType.nameContains:
      case RuleType.nameStartsWith:
        return TextFormField(
          controller: _patternController,
          decoration: InputDecoration(
            labelText: _selectedType == RuleType.nameContains
                ? 'App name contains'
                : 'App name starts with',
            hintText: 'e.g., TikTok, Instagram',
            border: const OutlineInputBorder(),
          ),
          validator: _validatePattern,
        );
      case RuleType.regex:
        return TextFormField(
          controller: _patternController,
          decoration: const InputDecoration(
            labelText: 'Regex Pattern',
            hintText: r'e.g., com\.facebook\..*',
            border: OutlineInputBorder(),
            helperText: 'Matches against package name',
          ),
          validator: _validatePattern,
        );
    }
  }

  Widget _buildAppPicker() {
    final hasSelection = _patternController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Select App', style: Theme.of(context).textTheme.titleSmall),
            if (!hasSelection) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Required',
                  style: TextStyle(fontSize: 10, color: Colors.red.shade700),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (hasSelection)
          Card(
            child: ListTile(
              leading: const Icon(Icons.android, color: Colors.green),
              title: Text(
                _installedApps
                    .firstWhere(
                      (a) => a.packageName == _patternController.text,
                      orElse: () => AppInfo(
                        packageName: _patternController.text,
                        appName: _patternController.text,
                      ),
                    )
                    .appName,
              ),
              subtitle: Text(
                _patternController.text,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _patternController.clear()),
              ),
            ),
          )
        else
          SizedBox(
            height: 300,
            child: Card(
              child: _installedApps.isEmpty
                  ? const Center(child: Text('No apps found'))
                  : ListView.builder(
                      itemCount: _installedApps.length,
                      itemBuilder: (context, index) {
                        final app = _installedApps[index];
                        return ListTile(
                          leading: Icon(
                            app.isSystemApp ? Icons.phone_android : Icons.android,
                            size: 20,
                            color: app.isSystemApp ? Colors.blue : Colors.green,
                          ),
                          title: Text(app.appName),
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: app.isSystemApp
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'System',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => setState(
                            () => _patternController.text = app.packageName,
                          ),
                        );
                      },
                    ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompanyPicker() {
    final knownCompanies = {
      'com.facebook': 'Meta (Facebook)',
      'com.instagram': 'Meta (Instagram)',
      'com.whatsapp': 'Meta (WhatsApp)',
      'com.google': 'Google',
      'com.bytedance': 'ByteDance',
      'com.zhiliaoapp': 'ByteDance (TikTok)',
      'com.ss.android': 'ByteDance',
      'com.twitter': 'X (Twitter)',
      'com.snap': 'Snap',
      'com.tencent': 'Tencent',
      'com.microsoft': 'Microsoft',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Company', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: knownCompanies.entries.map((e) {
            return ChoiceChip(
              label: Text(e.value),
              selected: _patternController.text == e.key,
              onSelected: (_) => setState(() => _patternController.text = e.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _patternController,
          decoration: const InputDecoration(
            labelText: 'Or enter custom prefix',
            hintText: 'e.g., com.example',
            border: OutlineInputBorder(),
          ),
          validator: _validatePattern,
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Overlay Images', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              '(${_imagePaths.length} added, random selection)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_imagePaths.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imagePaths.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePaths[index]),
                          height: 100,
                          width: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(_imagePaths.isEmpty ? 'Add Image' : 'Add More Images'),
        ),
      ],
    );
  }

  Widget _buildTextInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Overlay Quotes', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 8),
            Text(
              '(random selection)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Use default motivational quotes'),
          subtitle: Text(
            _useDefaultQuotes
                ? '${BlockingRule.defaultQuotes.length} inspiring quotes'
                : 'Using custom quotes',
            style: const TextStyle(fontSize: 12),
          ),
          value: _useDefaultQuotes,
          onChanged: (value) {
            setState(() {
              _useDefaultQuotes = value;
              if (!value && _overlayTexts.isEmpty) {
                _overlayTexts.add(''); // Add empty quote field
              }
            });
          },
          contentPadding: EdgeInsets.zero,
        ),
        if (_useDefaultQuotes) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Default quotes include:',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                ),
                const SizedBox(height: 4),
                ...BlockingRule.defaultQuotes.take(3).map(
                      (q) => Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '"$q"',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                Text(
                  '...and ${BlockingRule.defaultQuotes.length - 3} more',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          ...List.generate(_overlayTexts.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _overlayTexts[index],
                      decoration: InputDecoration(
                        labelText: 'Quote ${index + 1}',
                        hintText: 'Enter your motivational quote',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => _updateQuote(index, value),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: _overlayTexts.length > 1 ? () => _removeQuote(index) : null,
                  ),
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addQuote,
            icon: const Icon(Icons.add),
            label: const Text('Add Quote'),
          ),
        ],
      ],
    );
  }

  Widget _buildOverlayPreview() {
    return OutlinedButton.icon(
      onPressed: _openPreview,
      icon: const Icon(Icons.preview),
      label: const Text('Preview & Edit Position'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  String _typeLabel(RuleType type) {
    switch (type) {
      case RuleType.individual:
        return 'Single App';
      case RuleType.nameContains:
        return 'Name Contains';
      case RuleType.nameStartsWith:
        return 'Name Starts With';
      case RuleType.regex:
        return 'Regex';
      case RuleType.company:
        return 'Company';
    }
  }
}
