using System.Net;
using System.Net.Sockets;
using LanAudioRelay.Core.Audio;
using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Core.Networking;

public sealed class ControlClient
{
    public async Task<PairingSession> ConnectAndPairAsync(
        string host,
        string pairingCode,
        int controlPort = AudioConstants.ControlPort,
        CancellationToken cancellationToken = default)
    {
        using var tcpClient = new TcpClient();
        await tcpClient.ConnectAsync(host, controlPort, cancellationToken).ConfigureAwait(false);

        await using var stream = tcpClient.GetStream();
        using var connection = new JsonLineConnection(stream);

        var clientNonce = Pairing.CreateNonce();
        await connection.SendAsync(
            new HelloRequest(
                "hello",
                AudioConstants.ProtocolVersion,
                Environment.MachineName,
                clientNonce),
            cancellationToken).ConfigureAwait(false);

        var challenge = await connection.ReceiveAsync<ChallengeResponse>(cancellationToken).ConfigureAwait(false);
        if (challenge.Type != "challenge" || challenge.ProtocolVersion != AudioConstants.ProtocolVersion)
        {
            throw new InvalidDataException("The receiver returned an unsupported control challenge.");
        }

        var proof = Pairing.CreateProof(pairingCode, clientNonce, challenge.ServerNonce);
        await connection.SendAsync(new PairRequest("pair", proof), cancellationToken).ConfigureAwait(false);

        var result = await connection.ReceiveAsync<PairResult>(cancellationToken).ConfigureAwait(false);
        if (!result.Accepted)
        {
            throw new UnauthorizedAccessException(result.ErrorMessage ?? "The receiver rejected the pairing code.");
        }

        return new PairingSession(result.SessionId, host, result.MediaPort, result.AudioSettings);
    }
}
