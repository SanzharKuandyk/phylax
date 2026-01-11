import 'dart:convert';

enum RuleType {
  individual, // Match specific package name
  nameContains, // App name contains string
  nameStartsWith, // App name starts with string
  regex, // Package name matches regex
  company, // Package name starts with company prefix (e.g., com.facebook)
}

class BlockingRule {
  final int? id;
  final String? name; // Custom rule name, null means auto-generated
  final RuleType type;
  final String pattern; // package name, search string, regex, or company prefix
  final int order; // Lower = higher priority
  final bool enabled;

  // Overlay configuration - multiple images and texts (random selection)
  final List<String> imagePaths; // Multiple images, shown randomly
  final List<String> overlayTexts; // Multiple quotes/texts, shown randomly
  final double textPositionX; // 0-1
  final double textPositionY; // 0-1
  final double imageScale;
  final double imageOffsetX;
  final double imageOffsetY;

  BlockingRule({
    this.id,
    this.name,
    required this.type,
    required this.pattern,
    required this.order,
    this.enabled = true,
    List<String>? imagePaths,
    List<String>? overlayTexts,
    this.textPositionX = 0.5,
    this.textPositionY = 0.5,
    this.imageScale = 1.0,
    this.imageOffsetX = 0.0,
    this.imageOffsetY = 0.0,
  })  : imagePaths = imagePaths ?? [],
        overlayTexts = overlayTexts ?? defaultQuotes;

  // Legacy getters for backwards compatibility
  String? get imagePath => imagePaths.isNotEmpty ? imagePaths.first : null;
  String get overlayText => overlayTexts.isNotEmpty ? overlayTexts.first : defaultQuotes.first;

  static const List<String> defaultQuotes = [
    "Your future self will thank you.",
    "Small steps lead to big changes.",
    "Is this helping you become who you want to be?",
    "You're stronger than this urge.",
    "What could you accomplish instead?",
    "Every moment is a fresh beginning.",
    "Choose growth over comfort.",
    "Your time is precious. Use it wisely.",
    "Break the loop. Build something better.",
    "This too shall pass.",
  ];

  BlockingRule copyWith({
    int? id,
    String? name,
    RuleType? type,
    String? pattern,
    int? order,
    bool? enabled,
    List<String>? imagePaths,
    List<String>? overlayTexts,
    double? textPositionX,
    double? textPositionY,
    double? imageScale,
    double? imageOffsetX,
    double? imageOffsetY,
  }) {
    return BlockingRule(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      pattern: pattern ?? this.pattern,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
      imagePaths: imagePaths ?? this.imagePaths,
      overlayTexts: overlayTexts ?? this.overlayTexts,
      textPositionX: textPositionX ?? this.textPositionX,
      textPositionY: textPositionY ?? this.textPositionY,
      imageScale: imageScale ?? this.imageScale,
      imageOffsetX: imageOffsetX ?? this.imageOffsetX,
      imageOffsetY: imageOffsetY ?? this.imageOffsetY,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'pattern': pattern,
      'order_index': order,
      'enabled': enabled ? 1 : 0,
      'image_paths': jsonEncode(imagePaths),
      'overlay_texts': jsonEncode(overlayTexts),
      'text_position_x': textPositionX,
      'text_position_y': textPositionY,
      'image_scale': imageScale,
      'image_offset_x': imageOffsetX,
      'image_offset_y': imageOffsetY,
    };
  }

  factory BlockingRule.fromMap(Map<String, dynamic> map) {
    // Handle migration from old single value columns to new array columns
    List<String> imagePaths = [];
    List<String> overlayTexts = [];

    // Try new columns first
    if (map['image_paths'] != null) {
      final decoded = jsonDecode(map['image_paths'] as String);
      imagePaths = List<String>.from(decoded);
    } else if (map['image_path'] != null) {
      // Migrate from old single column
      imagePaths = [map['image_path'] as String];
    }

    if (map['overlay_texts'] != null) {
      final decoded = jsonDecode(map['overlay_texts'] as String);
      overlayTexts = List<String>.from(decoded);
    } else if (map['overlay_text'] != null) {
      // Migrate from old single column
      overlayTexts = [map['overlay_text'] as String];
    }

    return BlockingRule(
      id: map['id'] as int?,
      name: map['name'] as String?,
      type: RuleType.values[map['type'] as int],
      pattern: map['pattern'] as String,
      order: map['order_index'] as int,
      enabled: (map['enabled'] as int) == 1,
      imagePaths: imagePaths,
      overlayTexts: overlayTexts.isEmpty ? null : overlayTexts,
      textPositionX: (map['text_position_x'] as num?)?.toDouble() ?? 0.5,
      textPositionY: (map['text_position_y'] as num?)?.toDouble() ?? 0.5,
      imageScale: (map['image_scale'] as num?)?.toDouble() ?? 1.0,
      imageOffsetX: (map['image_offset_x'] as num?)?.toDouble() ?? 0.0,
      imageOffsetY: (map['image_offset_y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    return _autoGeneratedName;
  }

  String get _autoGeneratedName {
    switch (type) {
      case RuleType.individual:
        return pattern.split('.').last; // Show last part of package name
      case RuleType.nameContains:
        return 'Name contains "$pattern"';
      case RuleType.nameStartsWith:
        return 'Name starts with "$pattern"';
      case RuleType.regex:
        return 'Regex: $pattern';
      case RuleType.company:
        return 'Company: ${_companyName(pattern)}';
    }
  }

  String get typeLabel {
    switch (type) {
      case RuleType.individual:
        return 'App';
      case RuleType.nameContains:
        return 'Contains';
      case RuleType.nameStartsWith:
        return 'Starts with';
      case RuleType.regex:
        return 'Regex';
      case RuleType.company:
        return 'Company';
    }
  }

  static String _companyName(String prefix) {
    final knownCompanies = {
      'com.facebook': 'Meta',
      'com.instagram': 'Meta',
      'com.whatsapp': 'Meta',
      'com.meta': 'Meta',
      'com.google': 'Google',
      'com.bytedance': 'ByteDance',
      'com.zhiliaoapp': 'ByteDance (TikTok)',
      'com.ss.android': 'ByteDance',
      'com.twitter': 'X (Twitter)',
      'com.x': 'X',
      'com.snap': 'Snap',
      'com.snapchat': 'Snap',
      'com.tencent': 'Tencent',
      'com.microsoft': 'Microsoft',
      'com.amazon': 'Amazon',
    };
    return knownCompanies[prefix] ?? prefix;
  }
}
