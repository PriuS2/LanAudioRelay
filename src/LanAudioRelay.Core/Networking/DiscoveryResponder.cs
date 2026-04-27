using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using LanAudioRelay.Core.Audio;

namespace LanAudioRelay.Core.Networking;

public sealed class DiscoveryResponder : IAsyncDisposable
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly Func<DiscoveryResponderInfo> _infoProvider;
    private CancellationTokenSource? _cts;
    private UdpClient? _udp;

    public DiscoveryResponder(Func<DiscoveryResponderInfo> infoProvider)
    {
        _infoProvider = infoProvider;
    }

    public void Start()
    {
        if (_udp is not null)
        {
            throw new InvalidOperationException("The discovery responder is already running.");
        }

        _cts = new CancellationTokenSource();
        _udp = new UdpClient(AddressFamily.InterNetwork);
        _udp.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
        _udp.Client.Bind(new IPEndPoint(IPAddress.Any, AudioConstants.DiscoveryPort));
        _ = Task.Run(() => RunAsync(_cts.Token));
    }

    private async Task RunAsync(CancellationToken cancellationToken)
    {
        while (!cancellationToken.IsCancellationRequested && _udp is not null)
        {
            try
            {
                var result = await _udp.ReceiveAsync(cancellationToken).ConfigureAwait(false);
                var request = Encoding.ASCII.GetString(result.Buffer);
                if (!string.Equals(request, DiscoveryProtocol.RequestText, StringComparison.Ordinal))
                {
                    continue;
                }

                var info = _infoProvider();
                var response = new DiscoveryResponse(
                    AudioConstants.ProtocolVersion,
                    info.ReceiverId,
                    info.Name,
                    info.HostName,
                    AudioConstants.ControlPort);

                var payload = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(response, SerializerOptions));
                await _udp.SendAsync(payload, result.RemoteEndPoint, cancellationToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (ObjectDisposedException)
            {
                break;
            }
            catch (SocketException)
            {
            }
        }
    }

    public async ValueTask DisposeAsync()
    {
        _cts?.Cancel();
        _udp?.Dispose();
        _cts?.Dispose();
        await Task.CompletedTask.ConfigureAwait(false);
    }
}

public sealed record DiscoveryResponderInfo(string ReceiverId, string Name, string HostName);
