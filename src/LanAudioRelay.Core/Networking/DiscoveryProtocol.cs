namespace LanAudioRelay.Core.Networking;

internal static class DiscoveryProtocol
{
    public const string RequestText = "LAR_DISCOVER_V1";
}

internal sealed record DiscoveryResponse(
    int ProtocolVersion,
    string ReceiverId,
    string Name,
    string HostName,
    int ControlPort);
