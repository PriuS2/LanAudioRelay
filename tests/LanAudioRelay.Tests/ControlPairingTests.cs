using System.Net;
using System.Net.Sockets;
using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Networking;

namespace LanAudioRelay.Tests;

public sealed class ControlPairingTests
{
    [Fact]
    public async Task Control_pairing_accepts_valid_code()
    {
        const string code = "246810";
        var port = GetFreeTcpPort();
        var accepted = new TaskCompletionSource<PairingAcceptedEventArgs>(TaskCreationOptions.RunContinuationsAsynchronously);

        await using var server = new ControlServer(() => code);
        server.PairingAccepted += (_, args) => accepted.TrySetResult(args);
        server.Start(port);

        var client = new ControlClient();
        var session = await client.ConnectAndPairAsync("127.0.0.1", code, port);
        var acceptedArgs = await accepted.Task.WaitAsync(TimeSpan.FromSeconds(2));

        Assert.NotEqual(Guid.Empty, session.SessionId);
        Assert.Equal(AudioConstants.MediaPort, session.MediaPort);
        Assert.Equal(session.SessionId, acceptedArgs.SessionId);
    }

    [Fact]
    public async Task Control_pairing_rejects_invalid_code()
    {
        var port = GetFreeTcpPort();

        await using var server = new ControlServer(() => "246810");
        server.Start(port);

        var client = new ControlClient();

        await Assert.ThrowsAsync<UnauthorizedAccessException>(() =>
            client.ConnectAndPairAsync("127.0.0.1", "000000", port));
    }

    private static int GetFreeTcpPort()
    {
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        var port = ((IPEndPoint)listener.LocalEndpoint).Port;
        listener.Stop();
        return port;
    }
}
