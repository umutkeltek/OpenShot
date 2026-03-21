import AppKit
import os

struct SoundEffects {

    private static let logger = Logger(subsystem: "com.openshot.app", category: "SoundEffects")

    /// Plays the capture sound effect.
    /// Uses the system screen capture sound if available,
    /// otherwise falls back to a subtle system click sound.
    static func playCapture() {
        let preferences = Preferences.shared
        guard preferences.captureSound else {
            logger.debug("Capture sound disabled in preferences")
            return
        }

        // Try the system screenshot sound first (available in macOS system sounds)
        if let screenshotSound = NSSound(named: "Tink") {
            screenshotSound.play()
            logger.debug("Played capture sound: Tink")
            return
        }

        // Fallback: try system shutter / camera sound
        if let shutterSound = NSSound(named: "Morse") {
            shutterSound.play()
            logger.debug("Played capture sound: Morse (fallback)")
            return
        }

        // Final fallback: try to play the system screen capture sound directly
        let screenCaptureSoundPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"
        let soundURL = URL(fileURLWithPath: screenCaptureSoundPath)

        if FileManager.default.fileExists(atPath: soundURL.path),
           let sound = NSSound(contentsOf: soundURL, byReference: true) {
            sound.play()
            logger.debug("Played capture sound from system path")
            return
        }

        // If all else fails, beep
        NSSound.beep()
        logger.debug("Played system beep as final fallback")
    }

    // MARK: - Recording Sounds

    /// Plays a sound when screen recording starts.
    static func playRecordingStart() {
        guard Preferences.shared.playRecordingSounds else { return }
        if let sound = NSSound(named: "Blow") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    /// Plays a sound when screen recording stops.
    static func playRecordingStop() {
        guard Preferences.shared.playRecordingSounds else { return }
        if let sound = NSSound(named: "Bottle") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    /// Plays a sound when screen recording is paused or resumed.
    static func playRecordingPause() {
        guard Preferences.shared.playRecordingSounds else { return }
        if let sound = NSSound(named: "Pop") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
