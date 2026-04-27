using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Tests;

public sealed class JitterBufferTests
{
    [Fact]
    public void Buffer_waits_for_target_depth_before_playout()
    {
        var buffer = new JitterBuffer(targetDepth: 3, maxFrames: 8);
        buffer.Push(CreatePacket(10));
        buffer.Push(CreatePacket(11));

        Assert.False(buffer.TryPop(out _));

        buffer.Push(CreatePacket(12));

        Assert.True(buffer.TryPop(out var packet));
        Assert.Equal(10U, packet!.Sequence);
    }

    [Fact]
    public void Buffer_reorders_out_of_order_packets()
    {
        var buffer = new JitterBuffer(targetDepth: 3, maxFrames: 8);
        buffer.Push(CreatePacket(3));
        buffer.Push(CreatePacket(1));
        buffer.Push(CreatePacket(2));

        Assert.True(buffer.TryPop(out var first));
        Assert.True(buffer.TryPop(out var second));
        Assert.True(buffer.TryPop(out var third));

        Assert.Equal(1U, first!.Sequence);
        Assert.Equal(2U, second!.Sequence);
        Assert.Equal(3U, third!.Sequence);
    }

    [Fact]
    public void Buffer_reports_missing_frames_when_expected_sequence_is_absent()
    {
        var buffer = new JitterBuffer(targetDepth: 2, maxFrames: 8);
        buffer.Push(CreatePacket(1));
        buffer.Push(CreatePacket(3));

        Assert.True(buffer.TryPop(out var first));
        Assert.Equal(1U, first!.Sequence);
        Assert.False(buffer.TryPop(out _));
        Assert.Equal(1, buffer.MissingFrames);
        Assert.True(buffer.TryPop(out var third));
        Assert.Equal(3U, third!.Sequence);
    }

    [Fact]
    public void Buffer_recovers_after_sender_stops_and_resumes()
    {
        var buffer = new JitterBuffer(targetDepth: 2, maxFrames: 8);
        buffer.Push(CreatePacket(10));
        buffer.Push(CreatePacket(11));

        Assert.True(buffer.TryPop(out var first));
        Assert.Equal(10U, first!.Sequence);
        Assert.True(buffer.TryPop(out var second));
        Assert.Equal(11U, second!.Sequence);

        for (var index = 0; index < 100; index++)
        {
            Assert.False(buffer.TryPop(out _));
        }

        buffer.Push(CreatePacket(12));
        buffer.Push(CreatePacket(13));

        Assert.True(buffer.TryPop(out var resumedFirst));
        Assert.Equal(12U, resumedFirst!.Sequence);
        Assert.True(buffer.TryPop(out var resumedSecond));
        Assert.Equal(13U, resumedSecond!.Sequence);
    }

    private static AudioPacket CreatePacket(uint sequence)
    {
        return new AudioPacket(Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"), sequence, sequence * 960, AudioConstants.CodecOpus, new byte[] { 1, 2, 3 });
    }
}
