import Foundation

enum OpenShotError: LocalizedError {
    case captureNotPermitted
    case captureFailedNoImage
    case captureFailedNoContent
    case screenNotFound
    case windowNotFound
    case recordingAlreadyInProgress
    case recordingNotInProgress
    case assetWriterFailed(String)
    case gifExportFailed(String)
    case ocrFailed(String)
    case fileIOFailed(String)
    case invalidConfiguration(String)

    var errorDescription: String? {
        switch self {
        case .captureNotPermitted:
            return "Screen recording permission has not been granted. Please enable it in System Settings > Privacy & Security > Screen Recording."
        case .captureFailedNoImage:
            return "The screen capture failed because no image data was produced."
        case .captureFailedNoContent:
            return "The screen capture failed because no content was available to capture."
        case .screenNotFound:
            return "No screen could be found for the requested capture."
        case .windowNotFound:
            return "The target window could not be found or is no longer available."
        case .recordingAlreadyInProgress:
            return "A screen recording is already in progress. Stop the current recording before starting a new one."
        case .recordingNotInProgress:
            return "No screen recording is currently in progress."
        case .assetWriterFailed(let detail):
            return "The video asset writer failed: \(detail)"
        case .gifExportFailed(let detail):
            return "GIF export failed: \(detail)"
        case .ocrFailed(let detail):
            return "Text recognition (OCR) failed: \(detail)"
        case .fileIOFailed(let detail):
            return "File operation failed: \(detail)"
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        }
    }
}
