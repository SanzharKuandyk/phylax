package com.example.overlay_app

enum class RuleType {
    INDIVIDUAL,      // 0 - Match specific package name
    NAME_CONTAINS,   // 1 - App name contains string
    NAME_STARTS_WITH,// 2 - App name starts with string
    REGEX,           // 3 - Package name matches regex
    COMPANY          // 4 - Package name starts with company prefix
}

data class BlockingRule(
    val type: RuleType,
    val pattern: String,
    val enabled: Boolean = true,
    val imagePath: String? = null,
    val overlayText: String = "Stay Focused!",
    val textX: Float = 0.5f,
    val textY: Float = 0.5f,
    val imageScale: Float = 1.0f,
    val imageOffsetX: Float = 0.0f,
    val imageOffsetY: Float = 0.0f
) {
    companion object {
        fun fromMap(map: Map<String, Any?>): BlockingRule {
            return BlockingRule(
                type = RuleType.values()[map["type"] as Int], // corrected
                pattern = map["pattern"] as String,
                enabled = map["enabled"] as? Boolean ?: true,
                imagePath = map["imagePath"] as? String,
                overlayText = map["overlayText"] as? String ?: "Stay Focused!",
                textX = (map["textX"] as? Double)?.toFloat() ?: 0.5f,
                textY = (map["textY"] as? Double)?.toFloat() ?: 0.5f,
                imageScale = (map["imageScale"] as? Double)?.toFloat() ?: 1.0f,
                imageOffsetX = (map["imageOffsetX"] as? Double)?.toFloat() ?: 0.0f,
                imageOffsetY = (map["imageOffsetY"] as? Double)?.toFloat() ?: 0.0f
            )
        }
    }
}
