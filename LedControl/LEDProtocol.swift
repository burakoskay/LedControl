import Foundation

enum LEDProtocolCodec {
    static let handshakeRequest = "HELLO"
    static let handshakeResponse = "LEDCTRL,1"

    static func colorCommand(
        brightness: Double,
        red: Double,
        green: Double,
        blue: Double
    ) -> String {
        let brightnessPercent = percentage(from: brightness)
        let redByte = colorByte(from: red)
        let greenByte = colorByte(from: green)
        let blueByte = colorByte(from: blue)
        return "\(brightnessPercent),\(redByte),\(greenByte),\(blueByte)"
    }

    static func brightnessCommand(_ brightness: Double) -> String {
        "BRIGHTNESS,\(percentage(from: brightness))"
    }

    static func speedCommand(_ speed: Double) -> String {
        "SPEED,\(percentage(from: speed))"
    }

    static func storedColorCommand(red: Double, green: Double, blue: Double) -> String {
        "COLOR,\(colorByte(from: red)),\(colorByte(from: green)),\(colorByte(from: blue))"
    }

    private static func percentage(from value: Double) -> Int {
        Int((min(max(value, 0), 1) * 100).rounded())
    }

    private static func colorByte(from value: Double) -> Int {
        Int((min(max(value, 0), 1) * 255).rounded())
    }
}
