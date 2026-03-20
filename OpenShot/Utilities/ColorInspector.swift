// ColorInspector.swift
// OpenShot
//
// Color analysis utility that provides HEX, RGB, OKLCH values
// and WCAG / APCA contrast checking.

import AppKit
import os

struct ColorInspector {

    // MARK: - Color Formats

    /// Get hex string from NSColor
    static func hex(from color: NSColor) -> String {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(rgb.redComponent * 255)
        let g = Int(rgb.greenComponent * 255)
        let b = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Get RGB tuple from NSColor
    static func rgb(from color: NSColor) -> (r: Int, g: Int, b: Int) {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        return (Int(rgb.redComponent * 255), Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255))
    }

    /// Get OKLCH values from NSColor (modern perceptual color space)
    /// Returns (L: lightness 0-1, C: chroma 0-0.4, H: hue 0-360)
    static func oklch(from color: NSColor) -> (l: Double, c: Double, h: Double) {
        let rgb = color.usingColorSpace(.sRGB) ?? color
        let r = Double(rgb.redComponent)
        let g = Double(rgb.greenComponent)
        let b = Double(rgb.blueComponent)

        // sRGB to linear
        let lr = r <= 0.04045 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let lg = g <= 0.04045 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let lb = b <= 0.04045 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)

        // Linear RGB to OKLab
        let l_ = 0.4122214708 * lr + 0.5363325363 * lg + 0.0514459929 * lb
        let m_ = 0.2119034982 * lr + 0.6806995451 * lg + 0.1073969566 * lb
        let s_ = 0.0883024619 * lr + 0.2220049174 * lg + 0.6896926207 * lb

        let l3 = cbrt(l_)
        let m3 = cbrt(m_)
        let s3 = cbrt(s_)

        let okL = 0.2104542553 * l3 + 0.7936177850 * m3 - 0.0040720468 * s3
        let okA = 1.9779984951 * l3 - 2.4285922050 * m3 + 0.4505937099 * s3
        let okB = 0.0259040371 * l3 + 0.7827717662 * m3 - 0.8086757660 * s3

        // OKLab to OKLCH
        let c = sqrt(okA * okA + okB * okB)
        var h = atan2(okB, okA) * 180 / .pi
        if h < 0 { h += 360 }

        return (l: okL, c: c, h: h)
    }

    // MARK: - WCAG Contrast

    /// Calculate WCAG 2.0 contrast ratio between two colors
    /// Returns ratio from 1:1 to 21:1
    static func wcagContrastRatio(foreground: NSColor, background: NSColor) -> Double {
        let fgLum = relativeLuminance(foreground)
        let bgLum = relativeLuminance(background)
        let lighter = max(fgLum, bgLum)
        let darker = min(fgLum, bgLum)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Check WCAG 2.0 compliance levels
    static func wcagCompliance(ratio: Double) -> (normalAA: Bool, normalAAA: Bool, largeAA: Bool, largeAAA: Bool) {
        return (
            normalAA: ratio >= 4.5,
            normalAAA: ratio >= 7.0,
            largeAA: ratio >= 3.0,
            largeAAA: ratio >= 4.5
        )
    }

    /// Calculate APCA contrast (Accessible Perceptual Contrast Algorithm)
    /// More modern than WCAG 2.0, used in WCAG 3.0 draft
    static func apcaContrast(text: NSColor, background: NSColor) -> Double {
        let txtY = apcaLuminance(text)
        let bgY = apcaLuminance(background)

        // SAPC/APCA contrast calculation
        let normBG: Double = 0.56
        let normTXT: Double = 0.57
        let revTXT: Double = 0.62
        let revBG: Double = 0.65

        var contrast: Double
        if bgY >= txtY {
            contrast = (pow(bgY, normBG) - pow(txtY, normTXT)) * 1.14
        } else {
            contrast = (pow(bgY, revBG) - pow(txtY, revTXT)) * 1.14
        }

        if abs(contrast) < 0.1 { return 0 }
        return contrast * 100 // Lc value
    }

    // MARK: - Private

    private static func relativeLuminance(_ color: NSColor) -> Double {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = linearize(Double(c.redComponent))
        let g = linearize(Double(c.greenComponent))
        let b = linearize(Double(c.blueComponent))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func linearize(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func apcaLuminance(_ color: NSColor) -> Double {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = pow(Double(c.redComponent), 2.4) * 0.2126729
        let g = pow(Double(c.greenComponent), 2.4) * 0.7151522
        let b = pow(Double(c.blueComponent), 2.4) * 0.0721750
        return r + g + b
    }

    // MARK: - Formatted Output

    /// Get all color info as a formatted string
    static func describe(_ color: NSColor) -> String {
        let h = hex(from: color)
        let (r, g, b) = rgb(from: color)
        let (l, c, hue) = oklch(from: color)
        return """
        HEX: \(h)
        RGB: \(r), \(g), \(b)
        OKLCH: \(String(format: "%.2f", l)) \(String(format: "%.3f", c)) \(String(format: "%.1f", hue))
        """
    }

    /// Copy color in specified format to clipboard
    static func copyToClipboard(_ color: NSColor, format: ColorFormat = .hex) {
        let text: String
        switch format {
        case .hex: text = hex(from: color)
        case .rgb:
            let (r, g, b) = rgb(from: color)
            text = "rgb(\(r), \(g), \(b))"
        case .oklch:
            let (l, c, h) = oklch(from: color)
            text = "oklch(\(String(format: "%.2f", l)) \(String(format: "%.3f", c)) \(String(format: "%.1f", h)))"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    enum ColorFormat: String, CaseIterable {
        case hex, rgb, oklch
    }
}
