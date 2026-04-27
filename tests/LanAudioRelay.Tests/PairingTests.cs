using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Tests;

public sealed class PairingTests
{
    [Fact]
    public void Proof_verifies_without_sending_plaintext_code()
    {
        const string code = "123456";
        var clientNonce = Pairing.CreateNonce();
        var serverNonce = Pairing.CreateNonce();

        var proof = Pairing.CreateProof(code, clientNonce, serverNonce);

        Assert.DoesNotContain(code, proof, StringComparison.Ordinal);
        Assert.True(Pairing.VerifyProof(code, clientNonce, serverNonce, proof));
        Assert.False(Pairing.VerifyProof("111111", clientNonce, serverNonce, proof));
    }

    [Fact]
    public void Generated_code_is_six_digits()
    {
        var code = Pairing.GenerateCode();

        Assert.Equal(6, code.Length);
        Assert.All(code, character => Assert.True(char.IsDigit(character)));
    }
}
