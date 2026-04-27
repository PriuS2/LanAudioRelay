using System.Net;
using System.Net.Sockets;
using LanAudioRelay.Audio;
using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Networking;
using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Services;

public sealed class SenderSession : IAsyncDisposable
{
    private readonly object _gate = new();
    private readonly ControlClient _controlClient = new();
    private readonly WasapiLoopbackAudioSource _audioSource = new();
    private readonly OpusFrameEncoder _encoder = new();
    private UdpClient? _udp;
    private IPEndPoint? _mediaEndPoint;
    private Guid _sessionId;
    private uint _sequence;
    private ulong _timestamp;
    private bool _running;

    public SenderSession()
    {
        _audioSource.FrameCaptured += OnFrameCaptured;
        _audioSource.Faulted += (_, message) => StatusChanged?.Invoke(this, $"Capture error: {message}");
    }

    public event EventHandler<string>? StatusChanged;
    public event EventHandler<float>? InputLevelChanged;

    public async Task StartAsync(string receiverHost, string pairingCode, CancellationToken cancellationToken = default)
    {
        lock (_gate)
        {
            if (_running)
            {
                throw new InvalidOperationException("Sender is already running.");
            }

            _running = true;
        }

        try
        {
            StatusChanged?.Invoke(this, "Pairing with receiver...");
            var session = await _controlClient
                .ConnectAndPairAsync(receiverHost, pairingCode, cancellationToken: cancellationToken)
                .ConfigureAwait(false);

            _udp = new UdpClient(AddressFamily.InterNetwork);
            _mediaEndPoint = new IPEndPoint(IPAddress.Parse(session.ReceiverHost), session.MediaPort);
            _sessionId = session.SessionId;
            _sequence = 0;
            _timestamp = 0;

            _audioSource.Start();
            StatusChanged?.Invoke(this, $"Streaming to {receiverHost}:{session.MediaPort}");
        }
        catch
        {
            await StopAsync().ConfigureAwait(false);
            throw;
        }
    }

    private void OnFrameCaptured(object? sender, PcmFrameCapturedEventArgs e)
    {
        UdpClient? udp;
        IPEndPoint? endpoint;
        Guid sessionId;
        uint sequence;
        ulong timestamp;

        lock (_gate)
        {
            if (!_running || _udp is null || _mediaEndPoint is null)
            {
                return;
            }

            udp = _udp;
            endpoint = _mediaEndPoint;
            sessionId = _sessionId;
            sequence = _sequence++;
            timestamp = _timestamp;
            _timestamp += AudioConstants.SamplesPerFrame;
        }

        try
        {
            var payload = _encoder.Encode(e.Pcm);
            var packet = new AudioPacket(sessionId, sequence, timestamp, AudioConstants.CodecOpus, payload);
            var bytes = packet.ToArray();
            udp.Send(bytes, bytes.Length, endpoint);
            InputLevelChanged?.Invoke(this, e.Level);
        }
        catch (ObjectDisposedException)
        {
        }
        catch (SocketException ex)
        {
            StatusChanged?.Invoke(this, $"UDP send error: {ex.Message}");
        }
    }

    public async Task StopAsync()
    {
        lock (_gate)
        {
            _running = false;
        }

        _audioSource.Stop();
        _udp?.Dispose();
        _udp = null;
        _mediaEndPoint = null;
        StatusChanged?.Invoke(this, "Sender stopped.");
        await Task.CompletedTask.ConfigureAwait(false);
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync().ConfigureAwait(false);
        _audioSource.Dispose();
    }
}
