using LanAudioRelay.Core.Audio;

namespace LanAudioRelay.Tests;

public sealed class OpusCodecTests
{
    [Fact]
    public void Opus_encoder_decoder_round_trips_a_stereo_frame()
    {
        var encoder = new OpusFrameEncoder();
        var decoder = new OpusFrameDecoder();
        var pcm = new short[AudioConstants.PcmSamplesPerFrame];

        for (var index = 0; index < AudioConstants.SamplesPerFrame; index++)
        {
            var sample = (short)(Math.Sin(index / 12.0) * 12_000);
            pcm[index * 2] = sample;
            pcm[index * 2 + 1] = sample;
        }

        var payload = encoder.Encode(pcm);
        var decoded = decoder.Decode(payload);

        Assert.NotEmpty(payload);
        Assert.Equal(AudioConstants.PcmSamplesPerFrame, decoded.Length);
        Assert.Contains(decoded, sample => sample != 0);
    }
}
