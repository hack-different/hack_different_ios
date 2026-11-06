package com.hackdifferent.core

import com.audiencekit.AudienceKitConfiguration
import com.audiencekit.AudienceKitEnvironment
import com.audiencekit.AudienceKitSDK

/**
 * Runtime configuration for Hack Different on Android, matching iOS `AppConfiguration`.
 */
public data class AppConfig(
    val baseUrl: String = DEFAULT_BASE_URL,
    val host: String = DEFAULT_AUDIENCE_HOST,
    val audienceId: String = DEFAULT_AUDIENCE_ID,
    val facebookAppId: String? = DEFAULT_FACEBOOK_APP_ID,
    val appleServicesId: String = DEFAULT_APPLE_SERVICES_ID,
    val environment: AudienceKitEnvironment = AudienceKitEnvironment.PRODUCTION,
    val coverPassPrefix: String = "HMC1",
    val feeLabel: String = "Hack Different fee",
    val versionName: String = "1.0.0",
    val versionCode: String = "1",
) {
    public val audienceKitConfiguration: AudienceKitConfiguration
        get() = AudienceKitConfiguration(
            baseUrl = baseUrl,
            host = host,
            audienceId = audienceId,
            facebookAppId = facebookAppId,
            environment = environment,
        )

    public companion object {
        public const val DEFAULT_BASE_URL: String = AudienceKitSDK.PRODUCTION_BASE_URL
        public const val DEFAULT_AUDIENCE_ID: String = "2416ce6c-f28a-4460-8b6f-840f3c0027c9"
        public const val DEFAULT_AUDIENCE_HOST: String = "hack-different.admin.audiencekit.com"
        public const val DEFAULT_FACEBOOK_APP_ID: String = "713525445368431"
        public const val DEFAULT_APPLE_SERVICES_ID: String = "com.hackdifferent.app"
    }
}
