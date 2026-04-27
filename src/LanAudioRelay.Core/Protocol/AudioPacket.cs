using System.Buffers.Binary;
using LanAudioRelay.Core.Audio;

namespace LanAudioRelay.Core.Protocol;

public sealed record AudioPacket(
    Guid SessionId,
    uint Sequence,
    ulong Timestamp,
    byte Codec,
    byte[] Payload)
{
    public const int HeaderSize = 36;
    private static ReadOnlySpan<byte> Magic => "LAR1"u8;

    public byte[] ToArray()
    {
        if (Payload.Length > ushort.MaxValue)
        {
            throw new InvalidOperationException("Audio payload is too large for a LAN audio packet.");
        }

        var buffer = new byte[HeaderSize + Payload.Length];
        Magic.CopyTo(buffer);
        buffer[4] = AudioConstants.ProtocolVersion;
        buffer[5] = Codec;
        SessionId.TryWriteBytes(buffer.AsSpan(6, 16));
        BinaryPrimitives.WriteUInt32BigEndian(buffer.AsSpan(22, 4), Sequence);
        BinaryPrimitives.WriteUInt64BigEndian(buffer.AsSpan(26, 8), Timestamp);
        BinaryPrimitives.WriteUInt16BigEndian(buffer.AsSpan(34, 2), (ushort)Payload.Length);
        Payload.CopyTo(buffer.AsSpan(HeaderSize));
        return buffer;
    }

    public static bool TryParse(ReadOnlySpan<byte> data, out AudioPacket? packet)
    {
        packet = null;

        if (data.Length < HeaderSize || !data[..4].SequenceEqual(Magic))
        {
            return false;
        }

        if (data[4] != AudioConstants.ProtocolVersion)
        {
            return false;
        }

        var payloadLength = BinaryPrimitives.ReadUInt16BigEndian(data.Slice(34, 2));
        if (data.Length != HeaderSize + payloadLength)
        {
            return false;
        }

        var sessionId = new Guid(data.Slice(6, 16));
        var sequence = BinaryPrimitives.ReadUInt32BigEndian(data.Slice(22, 4));
        var timestamp = BinaryPrimitives.ReadUInt64BigEndian(data.Slice(26, 8));
        var payload = data.Slice(HeaderSize, payloadLength).ToArray();

        packet = new AudioPacket(sessionId, sequence, timestamp, data[5], payload);
        return true;
    }
}
