using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace LanAudioRelay.Core.Protocol;

public sealed class JsonLineConnection : IDisposable
{
    private static readonly JsonSerializerOptions SerializerOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    private readonly StreamReader _reader;
    private readonly StreamWriter _writer;

    public JsonLineConnection(Stream stream)
    {
        _reader = new StreamReader(stream, Encoding.UTF8, detectEncodingFromByteOrderMarks: false, leaveOpen: true);
        _writer = new StreamWriter(stream, new UTF8Encoding(false), leaveOpen: true)
        {
            AutoFlush = true,
            NewLine = "\n"
        };
    }

    public async Task<T> ReceiveAsync<T>(CancellationToken cancellationToken)
    {
        var line = await _reader.ReadLineAsync(cancellationToken).ConfigureAwait(false);
        if (line is null)
        {
            throw new EndOfStreamException("The control connection closed before a complete message arrived.");
        }

        return JsonSerializer.Deserialize<T>(line, SerializerOptions)
               ?? throw new InvalidDataException("The control message could not be parsed.");
    }

    public async Task SendAsync<T>(T message, CancellationToken cancellationToken)
    {
        var line = JsonSerializer.Serialize(message, SerializerOptions);
        await _writer.WriteLineAsync(line.AsMemory(), cancellationToken).ConfigureAwait(false);
    }

    public void Dispose()
    {
        _reader.Dispose();
        _writer.Dispose();
    }
}
