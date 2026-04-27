using LanAudioRelay.Core.Audio;
using NAudio.Wave;
using NAudio.Wave.SampleProviders;

namespace LanAudioRelay.Audio;

public sealed class WasapiLoopbackAudioSource : IDisposable
{
    private readonly object _gate = new();
    private WasapiLoopbackCapture? _capture;
    private BufferedWaveProvider? _buffer;
    private CancellationTokenSource? _cts;
    private Task? _drainTask;
    private bool _disposed;

    public event EventHandler<PcmFrameCapturedEventArgs>? FrameCaptured;
    public event EventHandler<string>? Faulted;

    public void Start()
    {
        lock (_gate)
        {
            if (_capture is not null)
            {
                throw new InvalidOperationException("Audio capture is already running.");
            }

            _cts = new CancellationTokenSource();
            _capture = new WasapiLoopbackCapture();
            _buffer = new BufferedWaveProvider(_capture.WaveFormat)
            {
                BufferDuration = TimeSpan.FromMilliseconds(500),
                DiscardOnBufferOverflow = true,
                ReadFully = false
            };

            var sampleProvider = BuildSampleProvider(_buffer);

            _capture.DataAvailable += OnDataAvailable;
            _capture.RecordingStopped += OnRecordingStopped;
            _capture.StartRecording();
            _drainTask = Task.Run(() => DrainFramesAsync(sampleProvider, _cts.Token));
        }
    }

    public void Stop()
    {
        WasapiLoopbackCapture? capture;
        CancellationTokenSource? cts;

        lock (_gate)
        {
            capture = _capture;
            cts = _cts;
            _capture = null;
            _buffer = null;
            _cts = null;
        }

        cts?.Cancel();
        capture?.StopRecording();
        capture?.Dispose();
        cts?.Dispose();
    }

    private static ISampleProvider BuildSampleProvider(IWaveProvider waveProvider)
    {
        ISampleProvider provider = waveProvider.ToSampleProvider();
        provider = new StereoSampleProvider(provider);

        if (provider.WaveFormat.SampleRate != AudioConstants.SampleRate)
        {
            provider = new WdlResamplingSampleProvider(provider, AudioConstants.SampleRate);
        }

        return provider;
    }

    private void OnDataAvailable(object? sender, WaveInEventArgs e)
    {
        var buffer = _buffer;
        if (buffer is not null && e.BytesRecorded > 0)
        {
            buffer.AddSamples(e.Buffer, 0, e.BytesRecorded);
        }
    }

    private void OnRecordingStopped(object? sender, StoppedEventArgs e)
    {
        if (e.Exception is not null)
        {
            Faulted?.Invoke(this, e.Exception.Message);
        }
    }

    private async Task DrainFramesAsync(ISampleProvider sampleProvider, CancellationToken cancellationToken)
    {
        var readBuffer = new float[AudioConstants.PcmSamplesPerFrame * 4];
        var pending = new List<float>(AudioConstants.PcmSamplesPerFrame * 2);

        while (!cancellationToken.IsCancellationRequested)
        {
            var read = sampleProvider.Read(readBuffer, 0, readBuffer.Length);
            if (read == 0)
            {
                await Task.Delay(5, cancellationToken).ConfigureAwait(false);
                continue;
            }

            for (var index = 0; index < read; index++)
            {
                pending.Add(readBuffer[index]);
            }

            while (pending.Count >= AudioConstants.PcmSamplesPerFrame)
            {
                var pcm = new short[AudioConstants.PcmSamplesPerFrame];
                double squareSum = 0;

                for (var index = 0; index < pcm.Length; index++)
                {
                    var sample = Math.Clamp(pending[index], -1f, 1f);
                    pcm[index] = (short)Math.Round(sample * short.MaxValue);
                    squareSum += sample * sample;
                }

                pending.RemoveRange(0, AudioConstants.PcmSamplesPerFrame);
                var level = (float)Math.Sqrt(squareSum / pcm.Length);
                FrameCaptured?.Invoke(this, new PcmFrameCapturedEventArgs(pcm, level));
            }
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        Stop();
    }
}
