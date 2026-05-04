import CryptoKit
import Foundation
import Security

public enum Pairing {
    public static func generateCode() -> String {
        String(format: "%06d", Int.random(in: 0..<1_000_000))
    }

    public static func createNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    public static func createProof(code: String, clientNonce: String, serverNonce: String) -> String {
        let material = "\(normalizeCode(code)):\(clientNonce):\(serverNonce)"
        let digest = SHA256.hash(data: Data(material.utf8))
        return Data(digest).base64EncodedString()
    }

    public static func verifyProof(
        expectedCode: String,
        clientNonce: String,
        serverNonce: String,
        proof: String
    ) -> Bool {
        createProof(code: expectedCode, clientNonce: clientNonce, serverNonce: serverNonce) == proof
    }

    private static func normalizeCode(_ code: String) -> String {
        let digits = code.filter(\.isNumber)
        if digits.count >= 6 {
            return String(digits.suffix(6))
        }
        return String(repeating: "0", count: 6 - digits.count) + digits
    }
}
