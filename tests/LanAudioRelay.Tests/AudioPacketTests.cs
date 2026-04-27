using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Tests;

public sealed class AudioPacketTests
{
    [Fact]
    public void Packet_round_trips_through_binary_format()
    {
        var sessionId = Guid.NewGuid();
        var payload = new byte[] { 1, 2, 3, 4, 5 };
        var packet = new AudioPacket(sessionId, 42, 960, AudioConstants.CodecOpus, payload);

        var bytes = packet.ToArray();
        var parsed = AudioPacket.TryParse(bytes, out var result);

        Assert.True(parsed);
        Assert.NotNull(result);
        Assert.Equal(sessionId, result.SessionId);
        Assert.Equal(42U, result.Sequence);
        Assert.Equal(960UL, result.Timestamp);
        Assert.Equal(AudioConstants.CodecOpus, result.Codec);
        Assert.Equal(payload, result.Payload);
    }

    [Fact]
    public void Packet_rejects_invalid_magic()
    {
        var packet = new AudioPacket(Guid.NewGuid(), 1, 0, AudioConstants.CodecOpus, new byte[] { 9 });
        var bytes = packet.ToArray();
        bytes[0] = 0;

        Assert.False(AudioPacket.TryParse(bytes, out _));
    }
}
