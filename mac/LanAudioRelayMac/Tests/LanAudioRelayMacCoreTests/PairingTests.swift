import XCTest
@testable import LanAudioRelayMacCore

final class PairingTests: XCTestCase {
    func testProofMatchesWindowsImplementationVector() {
        let proof = Pairing.createProof(code: "123456", clientNonce: "client", serverNonce: "server")

        XCTAssertEqual(proof, "Jv6vP5lhEhhPM3ecu6k/kJs+V6I4MR/yG1BT2KNnlOk=")
        XCTAssertTrue(Pairing.verifyProof(expectedCode: "123456", clientNonce: "client", serverNonce: "server", proof: proof))
        XCTAssertFalse(Pairing.verifyProof(expectedCode: "000000", clientNonce: "client", serverNonce: "server", proof: proof))
    }

    func testGeneratedCodeIsSixDigits() {
        let code = Pairing.generateCode()

        XCTAssertEqual(code.count, 6)
        XCTAssertTrue(code.allSatisfy(\.isNumber))
    }
}
