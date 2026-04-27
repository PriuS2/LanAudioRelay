namespace LanAudioRelay.Core.Models;

public sealed record ReceiverAnnouncement(
    string Id,
    string Name,
    string HostName,
    string IpAddress,
    int ControlPort,
    int ProtocolVersion)
{
    public string DisplayName => $"{Name} ({IpAddress})";
}
