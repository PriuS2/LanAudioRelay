using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace LanAudioRelay.Services;

public static class NetworkAddressProvider
{
    public static string GetLocalIPv4Summary()
    {
        var addresses = NetworkInterface.GetAllNetworkInterfaces()
            .Where(nic => nic.OperationalStatus == OperationalStatus.Up)
            .SelectMany(nic => nic.GetIPProperties().UnicastAddresses)
            .Where(address => address.Address.AddressFamily == AddressFamily.InterNetwork)
            .Select(address => address.Address)
            .Where(address => !IPAddress.IsLoopback(address))
            .Select(address => address.ToString())
            .Distinct()
            .ToArray();

        return addresses.Length == 0 ? "No LAN IPv4 address found" : string.Join(", ", addresses);
    }
}
