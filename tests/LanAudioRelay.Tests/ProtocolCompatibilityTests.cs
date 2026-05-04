using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Tests;

public sealed class ProtocolCompatibilityTests
{
    [Fact]
    public void Audio_packet_matches_cross_platform_binary_vector()
    {
        var packet = new AudioPacket(
            Guid.Parse("00112233-4455-6677-8899-aabbccddeeff"),
            0x01020304,
            0x0102030405060708,
            AudioConstants.CodecOpus,
            new byte[] { 0x01, 0x02 });

        Assert.Equal(
            "4c415231010133221100554477668899aabbccddeeff01020304010203040506070800020102",
            Convert.ToHexString(packet.ToArray()).ToLowerInvariant());
    }

    [Fact]
    public void Pairing_proof_matches_cross_platform_vector()
    {
        Assert.Equal(
            "Jv6vP5lhEhhPM3ecu6k/kJs+V6I4MR/yG1BT2KNnlOk=",
            Pairing.CreateProof("123456", "client", "server"));
    }
}
