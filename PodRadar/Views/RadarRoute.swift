import Foundation

/// Typed navigation path for the Radar tab's Devices flow: list → finder
/// → save location. A shared `NavigationPath` (owned by RadarView, passed
/// down as a Binding) lets SaveLocationView pop all the way back to the
/// Devices list on save, instead of just one level.
enum RadarRoute: Hashable {
    case finder(deviceID: String)
    case saveLocation(deviceID: String, deviceName: String)
}
