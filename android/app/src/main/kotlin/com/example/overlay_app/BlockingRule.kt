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
    val imagePaths: List<String> = emptyList(),
    val overlayTexts: List<String> = defaultQuotes,
    val textX: Float = 0.5f,
    val textY: Float = 0.5f,
    val imageScale: Float = 1.0f,
    val imageOffsetX: Float = 0.0f,
    val imageOffsetY: Float = 0.0f
) {
    companion object {
        val defaultQuotes = listOf(
            "Your future self will thank you.",
            "Small steps lead to big changes.",
            "Is this helping you become who you want to be?",
            "You're stronger than this urge.",
            "What could you accomplish instead?",
            "Every moment is a fresh beginning.",
            "Choose growth over comfort.",
            "Your time is precious. Use it wisely.",
            "Break the loop. Build something better.",
            "This too shall pass."
        )

        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any?>): BlockingRule {
            val imagePaths = (map["imagePaths"] as? List<*>)?.filterIsInstance<String>() ?: emptyList()
            val overlayTexts = (map["overlayTexts"] as? List<*>)?.filterIsInstance<String>()
                ?.takeIf { it.isNotEmpty() } ?: defaultQuotes

            return BlockingRule(
                type = RuleType.values()[map["type"] as Int],
                pattern = map["pattern"] as String,
                enabled = map["enabled"] as? Boolean ?: true,
                imagePaths = imagePaths,
                overlayTexts = overlayTexts,
                textX = (map["textX"] as? Double)?.toFloat() ?: 0.5f,
                textY = (map["textY"] as? Double)?.toFloat() ?: 0.5f,
                imageScale = (map["imageScale"] as? Double)?.toFloat() ?: 1.0f,
                imageOffsetX = (map["imageOffsetX"] as? Double)?.toFloat() ?: 0.0f,
                imageOffsetY = (map["imageOffsetY"] as? Double)?.toFloat() ?: 0.0f
            )
        }
    }

    // Helper to get a random image path (or null if empty)
    fun getRandomImagePath(): String? = imagePaths.randomOrNull()

    // Helper to get a random text
    fun getRandomText(): String = overlayTexts.randomOrNull() ?: defaultQuotes.random()
}
