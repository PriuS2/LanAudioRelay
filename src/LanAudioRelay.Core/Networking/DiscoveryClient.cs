using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Models;

namespace LanAudioRelay.Core.Networking;

public sealed class DiscoveryClient
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public async Task<IReadOnlyList<ReceiverAnnouncement>> DiscoverAsync(
        TimeSpan timeout,
        CancellationToken cancellationToken = default)
    {
        using var udp = new UdpClient(AddressFamily.InterNetwork)
        {
            EnableBroadcast = true
        };

        var request = Encoding.ASCII.GetBytes(DiscoveryProtocol.RequestText);
        await udp.SendAsync(
            request,
            new IPEndPoint(IPAddress.Broadcast, AudioConstants.DiscoveryPort),
            cancellationToken).ConfigureAwait(false);

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(timeout);

        var receivers = new Dictionary<string, ReceiverAnnouncement>(StringComparer.OrdinalIgnoreCase);

        while (!timeoutCts.IsCancellationRequested)
        {
            try
            {
                var result = await udp.ReceiveAsync(timeoutCts.Token).ConfigureAwait(false);
                var json = Encoding.UTF8.GetString(result.Buffer);
                var response = JsonSerializer.Deserialize<DiscoveryResponse>(json, SerializerOptions);
                if (response is null || response.ProtocolVersion != AudioConstants.ProtocolVersion)
                {
                    continue;
                }

                var announcement = new ReceiverAnnouncement(
                    response.ReceiverId,
                    response.Name,
                    response.HostName,
                    result.RemoteEndPoint.Address.ToString(),
                    response.ControlPort,
                    response.ProtocolVersion);

                receivers[announcement.Id] = announcement;
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (SocketException)
            {
                break;
            }
            catch (JsonException)
            {
            }
        }

        return receivers.Values.OrderBy(receiver => receiver.Name).ToArray();
    }
}
