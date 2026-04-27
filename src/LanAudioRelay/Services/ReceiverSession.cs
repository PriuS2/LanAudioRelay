using System.Net.Sockets;
using LanAudioRelay.Audio;
using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Networking;
using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Services;

public sealed class ReceiverSession : IAsyncDisposable
{
    private readonly object _gate = new();
    private readonly string _receiverId = Guid.NewGuid().ToString("N");
    private readonly AudioPlaybackSink _playback = new();
    private readonly JitterBuffer _jitterBuffer = new(targetDepth: 3, maxFrames: 128);
    private readonly short[] _silence = new short[AudioConstants.PcmSamplesPerFrame];
    private CancellationTokenSource? _cts;
    private ControlServer? _controlServer;
    private DiscoveryResponder? _discoveryResponder;
    private OpusFrameDecoder _decoder = new();
    private UdpClient? _udp;
    private Guid _activeSessionId;
    private bool _running;
    private volatile bool _hasReceivedAudio;
    private volatile bool _playoutStarted;
    private DateTimeOffset _lastDecodeErrorStatus = DateTimeOffset.MinValue;

    public event EventHandler<string>? StatusChanged;
    public event EventHandler<int>? BufferFramesChanged;
    public event EventHandler<string>? PairingCodeChanged;

    public string PairingCode { get; private set; } = "";

    public float Volume
    {
        get => _playback.Volume;
        set => _playback.Volume = value;
    }

    public Task StartAsync(CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            if (_running)
            {
                throw new InvalidOperationException("Receiver is already running.");
            }

            _running = true;
            _activeSessionId = Guid.Empty;
            _hasReceivedAudio = false;
            _playoutStarted = false;
            _decoder = new OpusFrameDecoder();
            _jitterBuffer.Reset();
            PairingCode = Pairing.GenerateCode();
            _cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        }

        PairingCodeChanged?.Invoke(this, PairingCode);
        _playback.Start();

        _controlServer = new ControlServer(() => PairingCode);
        _controlServer.PairingAccepted += OnPairingAccepted;
        _controlServer.Start();

        _discoveryResponder = new DiscoveryResponder(() => new DiscoveryResponderInfo(
            _receiverId,
            Environment.MachineName,
            Environment.MachineName));
        _discoveryResponder.Start();

        _udp = new UdpClient(AudioConstants.MediaPort);
        _ = Task.Run(() => ReceiveLoopAsync(_cts!.Token), _cts.Token);
        _ = Task.Run(() => PlaybackLoopAsync(_cts!.Token), _cts.Token);

        StatusChanged?.Invoke(this, "Receiver is listening.");
        return Task.CompletedTask;
    }

    private void OnPairingAccepted(object? sender, PairingAcceptedEventArgs e)
    {
        lock (_gate)
        {
            _activeSessionId = e.SessionId;
            _hasReceivedAudio = false;
            _playoutStarted = false;
            _decoder = new OpusFrameDecoder();
            _jitterBuffer.Reset();
        }

        _playback.Clear();
        StatusChanged?.Invoke(this, $"Paired with {e.ClientName}. Waiting for audio...");
    }

    private async Task ReceiveLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested && _udp is not null)
        {
            try
            {
                var result = await _udp.ReceiveAsync(cancellationToken).ConfigureAwait(false);
                if (!AudioPacket.TryParse(result.Buffer, out var packet) || packet is null)
                {
                    continue;
                }

                Guid activeSession;
                lock (_gate)
                {
                    activeSession = _activeSessionId;
                }

                if (packet.SessionId != activeSession || packet.Codec != AudioConstants.CodecOpus)
                {
                    continue;
                }

                _jitterBuffer.Push(packet);
                BufferFramesChanged?.Invoke(this, _jitterBuffer.BufferedFrameCount);

                if (!_hasReceivedAudio)
                {
                    _hasReceivedAudio = true;
                    StatusChanged?.Invoke(this, "Receiving audio packets. Playing...");
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (ObjectDisposedException)
            {
                break;
            }
            catch (SocketException ex)
            {
                StatusChanged?.Invoke(this, $"UDP receive error: {ex.Message}");
            }
        }
    }

    private async Task PlaybackLoopAsync(CancellationToken cancellationToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMilliseconds(AudioConstants.FrameDurationMs));

        try
        {
            while (await timer.WaitForNextTickAsync(cancellationToken).ConfigureAwait(false))
            {
                if (!HasActiveSession() || !_hasReceivedAudio)
                {
                    continue;
                }

                if (!_playoutStarted && _jitterBuffer.BufferedFrameCount < 3)
                {
                    continue;
                }

                if (_jitterBuffer.TryPop(out var packet) && packet is not null)
                {
                    try
                    {
                        short[] pcm;
                        lock (_gate)
                        {
                            pcm = _decoder.Decode(packet.Payload);
                        }

                        _playback.Write(pcm);
                        _playoutStarted = true;
                    }
                    catch (Exception ex)
                    {
                        ReportDecodeError(ex);
                        _playback.Write(_silence);
                    }
                }
                else
                {
                    _playback.Write(_silence);
                }

                BufferFramesChanged?.Invoke(this, _jitterBuffer.BufferedFrameCount);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private bool HasActiveSession()
    {
        lock (_gate)
        {
            return _activeSessionId != Guid.Empty;
        }
    }

    private void ReportDecodeError(Exception ex)
    {
        var now = DateTimeOffset.UtcNow;
        if (now - _lastDecodeErrorStatus < TimeSpan.FromSeconds(2))
        {
            return;
        }

        _lastDecodeErrorStatus = now;
        StatusChanged?.Invoke(this, $"Audio decode error: {ex.Message}");
    }

    public async Task StopAsync()
    {
        lock (_gate)
        {
            _running = false;
            _activeSessionId = Guid.Empty;
        }

        _cts?.Cancel();
        _udp?.Dispose();
        _udp = null;

        if (_controlServer is not null)
        {
            await _controlServer.DisposeAsync().ConfigureAwait(false);
            _controlServer = null;
        }

        if (_discoveryResponder is not null)
        {
            await _discoveryResponder.DisposeAsync().ConfigureAwait(false);
            _discoveryResponder = null;
        }

        _playback.Dispose();
        _cts?.Dispose();
        _cts = null;
        PairingCode = "";
        PairingCodeChanged?.Invoke(this, PairingCode);
        BufferFramesChanged?.Invoke(this, 0);
        StatusChanged?.Invoke(this, "Receiver stopped.");
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync().ConfigureAwait(false);
    }
}
