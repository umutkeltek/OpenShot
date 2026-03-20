import Foundation
import os

struct FileNamer {
    private static let logger = Logger(subsystem: "com.openshot", category: "naming")

    /// Default template: "OpenShot_{date}_{time}"
    static let defaultTemplate = "OpenShot_{date}_{time}"

    /// Counter for auto-incrementing filenames within a session
    private static var counter: Int = 0

    /// Generate a filename from a template.
    /// Supported tokens: {date}, {time}, {datetime}, {mode}, {counter}, {app}, {title}
    static func generate(
        template: String? = nil,
        mode: String = "capture",
        appName: String? = nil,
        windowTitle: String? = nil,
        fileExtension: String = "png"
    ) -> String {
        let tmpl = template ?? Preferences.shared.fileNamingTemplate
        counter += 1

        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "HH-mm-ss"
        let time = dateFormatter.string(from: now)

        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let datetime = dateFormatter.string(from: now)

        var result = tmpl
        result = result.replacingOccurrences(of: "{date}", with: date)
        result = result.replacingOccurrences(of: "{time}", with: time)
        result = result.replacingOccurrences(of: "{datetime}", with: datetime)
        result = result.replacingOccurrences(of: "{mode}", with: mode)
        result = result.replacingOccurrences(of: "{counter}", with: String(format: "%04d", counter))
        result = result.replacingOccurrences(of: "{app}", with: appName ?? "")
        result = result.replacingOccurrences(of: "{title}", with: windowTitle ?? "")

        // Clean up double underscores from empty tokens
        while result.contains("__") {
            result = result.replacingOccurrences(of: "__", with: "_")
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return "\(result).\(fileExtension)"
    }
}
