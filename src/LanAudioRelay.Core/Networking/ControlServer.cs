using System.Net;
using System.Net.Sockets;
using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Core.Networking;

public sealed class ControlServer : IAsyncDisposable
{
    private readonly Func<string> _pairingCodeProvider;
    private readonly object _gate = new();
    private CancellationTokenSource? _cts;
    private TcpListener? _listener;

    public ControlServer(Func<string> pairingCodeProvider)
    {
        _pairingCodeProvider = pairingCodeProvider;
    }

    public event EventHandler<PairingAcceptedEventArgs>? PairingAccepted;

    public Guid CurrentSessionId { get; private set; } = Guid.Empty;

    public void Start(int controlPort = AudioConstants.ControlPort)
    {
        if (_listener is not null)
        {
            throw new InvalidOperationException("The control server is already running.");
        }

        _cts = new CancellationTokenSource();
        _listener = new TcpListener(IPAddress.Any, controlPort);
        _listener.Start();
        _ = Task.Run(() => AcceptLoopAsync(_cts.Token));
    }

    private async Task AcceptLoopAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested && _listener is not null)
        {
            try
            {
                var client = await _listener.AcceptTcpClientAsync(cancellationToken).ConfigureAwait(false);
                _ = Task.Run(() => HandleClientAsync(client, cancellationToken), cancellationToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (ObjectDisposedException)
            {
                break;
            }
        }
    }

    private async Task HandleClientAsync(TcpClient client, CancellationToken cancellationToken)
    {
        using var _ = client;

        try
        {
            using var stream = client.GetStream();
            using var connection = new JsonLineConnection(stream);

            var hello = await connection.ReceiveAsync<HelloRequest>(cancellationToken).ConfigureAwait(false);
            if (hello.Type != "hello" || hello.ProtocolVersion != AudioConstants.ProtocolVersion)
            {
                await SendRejectedAsync(connection, "Unsupported protocol version.", cancellationToken).ConfigureAwait(false);
                return;
            }

            var serverNonce = Pairing.CreateNonce();
            await connection.SendAsync(
                new ChallengeResponse(
                    "challenge",
                    AudioConstants.ProtocolVersion,
                    Environment.MachineName,
                    serverNonce,
                    AudioSettings.Default),
                cancellationToken).ConfigureAwait(false);

            var pair = await connection.ReceiveAsync<PairRequest>(cancellationToken).ConfigureAwait(false);
            if (pair.Type != "pair" ||
                !Pairing.VerifyProof(_pairingCodeProvider(), hello.ClientNonce, serverNonce, pair.Proof))
            {
                await SendRejectedAsync(connection, "Invalid pairing code.", cancellationToken).ConfigureAwait(false);
                return;
            }

            var sessionId = Guid.NewGuid();
            lock (_gate)
            {
                CurrentSessionId = sessionId;
            }

            await connection.SendAsync(
                new PairResult(
                    "pairResult",
                    true,
                    null,
                    sessionId,
                    AudioConstants.MediaPort,
                    AudioSettings.Default),
                cancellationToken).ConfigureAwait(false);

            PairingAccepted?.Invoke(this, new PairingAcceptedEventArgs(sessionId, hello.ClientName));
        }
        catch
        {
            // A failed pairing attempt must not stop the receiver.
        }
    }

    private static Task SendRejectedAsync(
        JsonLineConnection connection,
        string reason,
        CancellationToken cancellationToken)
    {
        return connection.SendAsync(
            new PairResult(
                "pairResult",
                false,
                reason,
                Guid.Empty,
                AudioConstants.MediaPort,
                AudioSettings.Default),
            cancellationToken);
    }

    public async ValueTask DisposeAsync()
    {
        _cts?.Cancel();
        _listener?.Stop();
        _cts?.Dispose();
        await Task.CompletedTask.ConfigureAwait(false);
    }
}

public sealed class PairingAcceptedEventArgs : EventArgs
{
    public PairingAcceptedEventArgs(Guid sessionId, string clientName)
    {
        SessionId = sessionId;
        ClientName = clientName;
    }

    public Guid SessionId { get; }
    public string ClientName { get; }
}
