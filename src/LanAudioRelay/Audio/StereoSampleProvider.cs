using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace LanAudioRelay.Audio;

public sealed class StereoSampleProvider : ISampleProvider
{
    private readonly ISampleProvider _source;
    private readonly int _sourceChannels;
    private float[] _sourceBuffer = Array.Empty<float>();

    public StereoSampleProvider(ISampleProvider source)
    {
        _source = source;
        _sourceChannels = source.WaveFormat.Channels;
        WaveFormat = WaveFormat.CreateIeeeFloatWaveFormat(source.WaveFormat.SampleRate, 2);
    }

    public WaveFormat WaveFormat { get; }

    public int Read(float[] buffer, int offset, int count)
    {
        var requestedFrames = count / 2;
        var sourceSamplesNeeded = requestedFrames * _sourceChannels;
        if (_sourceBuffer.Length < sourceSamplesNeeded)
        {
            _sourceBuffer = new float[sourceSamplesNeeded];
        }

        var sourceRead = _source.Read(_sourceBuffer, 0, sourceSamplesNeeded);
        var framesRead = sourceRead / _sourceChannels;

        for (var frame = 0; frame < framesRead; frame++)
        {
            var sourceIndex = frame * _sourceChannels;
            var targetIndex = offset + frame * 2;
            var left = _sourceBuffer[sourceIndex];
            var right = _sourceChannels > 1 ? _sourceBuffer[sourceIndex + 1] : left;

            buffer[targetIndex] = left;
            buffer[targetIndex + 1] = right;
        }

        return framesRead * 2;
    }
}
