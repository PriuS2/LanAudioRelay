using System.Runtime.InteropServices;
using LanAudioRelay.Core.Audio;
using NAudio.Wave;

namespace LanAudioRelay.Audio;

public sealed class AudioPlaybackSink : IDisposable
{
    private readonly object _gate = new();
    private BufferedWaveProvider? _buffer;
    private WaveOutEvent? _output;
    private float _volume = 0.85f;

    public int BufferedMilliseconds
    {
        get
        {
            lock (_gate)
            {
                return (int)(_buffer?.BufferedDuration.TotalMilliseconds ?? 0);
            }
        }
    }

    public float Volume
    {
        get => _volume;
        set
        {
            _volume = Math.Clamp(value, 0f, 1f);
            lock (_gate)
            {
                if (_output is not null)
                {
                    _output.Volume = _volume;
                }
            }
        }
    }

    public void Start()
    {
        lock (_gate)
        {
            if (_output is not null)
            {
                return;
            }

            _buffer = new BufferedWaveProvider(new WaveFormat(
                AudioConstants.SampleRate,
                AudioConstants.BitsPerSample,
                AudioConstants.Channels))
            {
                BufferDuration = TimeSpan.FromMilliseconds(300),
                DiscardOnBufferOverflow = true,
                ReadFully = true
            };

            _output = new WaveOutEvent
            {
                DesiredLatency = 80,
                NumberOfBuffers = 2,
                Volume = _volume
            };
            _output.Init(_buffer);
            _output.Play();
        }
    }

    public void Write(short[] pcm)
    {
        lock (_gate)
        {
            if (_buffer is null)
            {
                return;
            }

            var bytes = MemoryMarshal.AsBytes(pcm.AsSpan()).ToArray();
            _buffer.AddSamples(bytes, 0, bytes.Length);
        }
    }

    public void Clear()
    {
        lock (_gate)
        {
            _buffer?.ClearBuffer();
        }
    }

    public void Dispose()
    {
        lock (_gate)
        {
            _output?.Stop();
            _output?.Dispose();
            _output = null;
            _buffer = null;
        }
    }
}
