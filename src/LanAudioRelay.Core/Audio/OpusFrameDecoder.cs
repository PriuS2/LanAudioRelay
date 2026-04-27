using Concentus;

namespace LanAudioRelay.Core.Audio;

public sealed class OpusFrameDecoder
{
    private readonly IOpusDecoder _decoder;

    public OpusFrameDecoder()
    {
        _decoder = OpusCodecFactory.CreateDecoder(AudioConstants.SampleRate, AudioConstants.Channels, null);
    }

    public short[] Decode(byte[] payload)
    {
        var pcm = new short[AudioConstants.PcmSamplesPerFrame];
        _decoder.Decode(payload, pcm, AudioConstants.SamplesPerFrame, false);
        return pcm;
    }
}
