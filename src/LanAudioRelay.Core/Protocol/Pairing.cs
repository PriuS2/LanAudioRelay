using System.Security.Cryptography;
using System.Text;

namespace LanAudioRelay.Core.Protocol;

public static class Pairing
{
    public static string GenerateCode()
    {
        return RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
    }

    public static string CreateNonce()
    {
        Span<byte> bytes = stackalloc byte[16];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes);
    }

    public static string CreateProof(string code, string clientNonce, string serverNonce)
    {
        var material = $"{NormalizeCode(code)}:{clientNonce}:{serverNonce}";
        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(material));
        return Convert.ToBase64String(hash);
    }

    public static bool VerifyProof(string expectedCode, string clientNonce, string serverNonce, string proof)
    {
        var expected = Encoding.ASCII.GetBytes(CreateProof(expectedCode, clientNonce, serverNonce));
        var actual = Encoding.ASCII.GetBytes(proof);
        return expected.Length == actual.Length && CryptographicOperations.FixedTimeEquals(expected, actual);
    }

    private static string NormalizeCode(string code)
    {
        var digits = new string(code.Where(char.IsDigit).ToArray());
        return digits.PadLeft(6, '0')[^6..];
    }
}
