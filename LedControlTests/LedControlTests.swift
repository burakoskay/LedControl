//
//  LedControlTests.swift
//  LedControlTests
//
//  Created by Burak Oskay on 26/05/2025.
//

import Testing
@testable import LedControl

struct LedControlTests {
    @Test func handshakeIsVersioned() {
        #expect(LEDProtocolCodec.handshakeRequest == "HELLO")
        #expect(LEDProtocolCodec.handshakeResponse == "LEDCTRL,1")
    }

    @Test func colorCommandRoundsValues() {
        #expect(
            LEDProtocolCodec.colorCommand(brightness: 0.755, red: 1, green: 0.5, blue: 0) ==
                "76,255,128,0"
        )
    }

    @Test func commandsClampOutOfRangeInput() {
        #expect(
            LEDProtocolCodec.colorCommand(brightness: 2, red: -1, green: 0, blue: 4) ==
                "100,0,0,255"
        )
        #expect(LEDProtocolCodec.speedCommand(-0.5) == "SPEED,0")
        #expect(LEDProtocolCodec.brightnessCommand(1.5) == "BRIGHTNESS,100")
    }

    @Test func storedColorCommandUsesByteRange() {
        #expect(LEDProtocolCodec.storedColorCommand(red: 0.25, green: 0.5, blue: 0.75) == "COLOR,64,128,191")
    }
}
