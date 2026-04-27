using Concentus;
using Concentus.Enums;

namespace LanAudioRelay.Core.Audio;

public sealed class OpusFrameEncoder
{
    private readonly IOpusEncoder _encoder;
    private readonly byte[] _encodeBuffer = new byte[1275];

    public OpusFrameEncoder(int bitrate = AudioConstants.DefaultBitrate)
    {
        _encoder = OpusCodecFactory.CreateEncoder(
            AudioConstants.SampleRate,
            AudioConstants.Channels,
            OpusApplication.OPUS_APPLICATION_AUDIO,
            null);
        _encoder.Bitrate = bitrate;
    }

    public byte[] Encode(short[] pcm)
    {
        if (pcm.Length != AudioConstants.PcmSamplesPerFrame)
        {
            throw new ArgumentException(
                $"Expected {AudioConstants.PcmSamplesPerFrame} samples for a 20ms stereo frame.",
                nameof(pcm));
        }

        var encodedBytes = _encoder.Encode(
            pcm,
            AudioConstants.SamplesPerFrame,
            _encodeBuffer,
            _encodeBuffer.Length);

        var payload = new byte[encodedBytes];
        Buffer.BlockCopy(_encodeBuffer, 0, payload, 0, encodedBytes);
        return payload;
    }
}
