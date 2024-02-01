// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import Segment
import Singular

@objc(SEGSingularDestination)
public class ObjCSegmentSingular: NSObject, ObjCPlugin, ObjCPluginShim {
  public func instance() -> EventPlugin { return SingularDestination() }
}

public class SingularDestination: DestinationPlugin, iOSLifecycle {
  public var key = "Singular"

  public var timeline = Segment.Timeline()

  public var type: Segment.PluginType = .destination

  public var analytics: Segment.Analytics?


  // internal config
  private let isSKANEnabled: Bool
  private let isManualSKANMode: Bool

  public init(isSKANEnabled: Bool = false, isManualSKANMode: Bool = false) {
    self.isSKANEnabled = isSKANEnabled
    self.isManualSKANMode = isManualSKANMode
    Singular.setWrapperName("Segment", andVersion: "1.2.0")
  }

  public func update(settings: Settings, type: UpdateType) {
    // we've already set up this singleton SDK, can't do it again, so skip.
    guard type == .initial else { return }

    // TODO: Update the proper types
    guard let singularSettings = settings.integrationSettings(forKey: key) else {
      analytics?.log(message: "Singular settings could not load")
      return
    }

    guard let apiKey = singularSettings["apiKey"] as? String, let secret = singularSettings["secret"] as? String else {
      analytics?.log(message: "Singular settings does not contain an apiKey or secret")
      return
    }

    analytics?.log(message: "Singular settings loaded")
    
    if let config = SingularConfig(apiKey: apiKey, andSecret: secret) {
      config.skAdNetworkEnabled = isSKANEnabled
      config.manualSkanConversionManagement = isManualSKANMode
      Singular.start(config)

      analytics?.log(message: "Singular started")
    }
  }

  public func track(event: TrackEvent) -> TrackEvent? {
    if let properties = event.properties?.dictionaryValue as? [String: Any], let revenue = extractRevenue(properties, key: "revenue") {
      let currency = properties["currency"] as? String
      analytics?.log(message: "Singular track revenue \(revenue)")
      Singular.customRevenue(event.event, currency: currency, amount: revenue)
    } else {
      analytics?.log(message: "Singular track event \(event.event)")
      Singular.event(event.event)
    }
    return event
  }

  public func identify(event: IdentifyEvent) -> IdentifyEvent? {
    if let userId = event.userId, !userId.isEmpty {
      Singular.setCustomUserId(userId)
      analytics?.log(message: "Singular identify \(userId)")
    }
    return nil
  }

  public func reset() {
    analytics?.log(message: "Singular reset")
    Singular.unsetCustomUserId()
  }
}

extension SingularDestination {
  private func extractRevenue(_ properties: [String: Any], key: String) -> Double? {
    var revenue: Double? = nil
    if let revenueProperty = properties[key] {
      if let revenueProperty = revenueProperty as? String {
        revenue = Double(revenueProperty)
      } else if let revenueProperty = revenueProperty as? NSNumber {
        revenue = revenueProperty.doubleValue
      }
    }

    return revenue
  }
}
