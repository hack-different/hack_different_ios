//
//  AppConfiguration.swift
//  HackDifferent
//

import AudienceKit
import Foundation
import UIKit

/// Runtime configuration loaded from `Info.plist` (populated by `.xcconfig`) with
/// defaults pinned to the Hack Different AudienceKit audience.
public struct AppConfiguration: Sendable, Hashable {
    public static let defaultBaseURL = AudienceKitSDK.productionBaseURL
    public static let defaultAudienceID = "2416ce6c-f28a-4460-8b6f-840f3c0027c9"
    public static let defaultAudienceHost = "hack-different.admin.audiencekit.com"
    public static let defaultFacebookAppID = "713525445368431"

    public let baseURL: URL
    public let host: String
    public let audienceID: String
    public let facebookAppID: String?
    public let environment: AudienceKitEnvironment
    public let coverPassPrefix: String
    public let feeLabel: String
    public let marketingVersion: String
    public let buildNumber: String

    public init(
        baseURL: URL = Self.defaultBaseURL,
        host: String = Self.defaultAudienceHost,
        audienceID: String = Self.defaultAudienceID,
        facebookAppID: String? = Self.defaultFacebookAppID,
        environment: AudienceKitEnvironment = .production,
        coverPassPrefix: String = "HMC1",
        feeLabel: String = "Hack Different fee",
        marketingVersion: String = "1.0.0",
        buildNumber: String = "1"
    ) {
        self.baseURL = baseURL
        self.host = host
        self.audienceID = audienceID
        self.facebookAppID = facebookAppID
        self.environment = environment
        self.coverPassPrefix = coverPassPrefix
        self.feeLabel = feeLabel
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> AppConfiguration {
        let info = bundle.infoDictionary ?? [:]

        let serverString = Self.nonEmpty(info["AudienceKitServerBase"] as? String)
        let baseURL = serverString.flatMap(URL.init(string:)) ?? Self.defaultBaseURL

        let host = Self.nonEmpty(info["AudienceKitHost"] as? String) ?? defaultAudienceHost
        let audienceID = Self.nonEmpty(info["AudienceKitAudienceID"] as? String) ?? defaultAudienceID
        let facebookAppID = Self.nonEmpty(info["FacebookAppID"] as? String) ?? defaultFacebookAppID

        let envRaw = Self.nonEmpty(info["AudienceKitEnvironment"] as? String) ?? "production"
        let environment = AudienceKitEnvironment(rawValue: envRaw)

        let coverPassPrefix = Self.nonEmpty(info["AudienceKitCoverPassPrefix"] as? String) ?? "HMC1"
        let feeLabel = Self.nonEmpty(info["AudienceKitFeeLabel"] as? String) ?? "Hack Different fee"
        let marketingVersion = Self.nonEmpty(info["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        let buildNumber = Self.nonEmpty(info["CFBundleVersion"] as? String) ?? "1"

        return AppConfiguration(
            baseURL: baseURL,
            host: host,
            audienceID: audienceID,
            facebookAppID: facebookAppID,
            environment: environment,
            coverPassPrefix: coverPassPrefix,
            feeLabel: feeLabel,
            marketingVersion: marketingVersion,
            buildNumber: buildNumber
        )
    }

    public var audienceKitConfiguration: AudienceKitConfiguration {
        AudienceKitConfiguration(
            baseURL: baseURL,
            host: host,
            audienceID: audienceID,
            facebookAppID: facebookAppID,
            environment: environment,
            coverPassPrefix: coverPassPrefix,
            feeLabel: feeLabel
        )
    }

    @MainActor
    public func currentDeviceDescription() -> DeviceDescription {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingCString: $0)
            }
        }
        return DeviceDescription(
            identifier: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            type: "apple",
            model: machine ?? UIDevice.current.model,
            version: marketingVersion,
            build: buildNumber
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              !trimmed.hasPrefix("$(")
        else {
            return nil
        }
        return trimmed
    }
}
