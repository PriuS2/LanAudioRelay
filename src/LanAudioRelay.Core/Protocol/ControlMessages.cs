using LanAudioRelay.Core.Audio;

namespace LanAudioRelay.Core.Protocol;

public sealed record HelloRequest(
    string Type,
    int ProtocolVersion,
    string ClientName,
    string ClientNonce);

public sealed record ChallengeResponse(
    string Type,
    int ProtocolVersion,
    string ServerName,
    string ServerNonce,
    AudioSettings AudioSettings);

public sealed record PairRequest(
    string Type,
    string Proof);

public sealed record PairResult(
    string Type,
    bool Accepted,
    string? ErrorMessage,
    Guid SessionId,
    int MediaPort,
    AudioSettings AudioSettings);

public sealed record PairingSession(
    Guid SessionId,
    string ReceiverHost,
    int MediaPort,
    AudioSettings AudioSettings);
