import Foundation

/// Bridge for communication between FinderSync extension and main ZipMip app
public struct FinderSyncBridge: Sendable {
    public static let appGroupIdentifier = "group.com.zipmip.app"
    public static let urlScheme = "zipmip"

    public enum Action: String, Codable, Sendable {
        case extractHere = "extractHere"
        case extractToSubfolder = "extractToSubfolder"
        case extractWithPassword = "extractWithPassword"
        case openInBrowser = "openInBrowser"
        case compressToZip = "compressToZip"
        case compressTo7z = "compressTo7z"
        case compressCustom = "compressCustom"
    }

    /// Generates a URL scheme link to trigger an action in the main app
    public static func makeActionURL(action: Action, targetPaths: [String]) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = action.rawValue
        
        let pathItems = targetPaths.map { URLQueryItem(name: "path", value: $0) }
        components.queryItems = pathItems
        
        return components.url
    }

    /// Parses incoming URL scheme action
    public static func parseAction(from url: URL) -> (action: Action, paths: [URL])? {
        guard url.scheme == urlScheme, let host = url.host, let action = Action(rawValue: host) else {
            return nil
        }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathStrings = components?.queryItems?.filter { $0.name == "path" }.compactMap { $0.value } ?? []
        let urls = pathStrings.map { URL(fileURLWithPath: $0) }

        return (action, urls)
    }
}
