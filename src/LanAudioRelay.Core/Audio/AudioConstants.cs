namespace LanAudioRelay.Core.Audio;

public static class AudioConstants
{
    public const int DiscoveryPort = 51359;
    public const int ControlPort = 51360;
    public const int MediaPort = 51361;

    public const int SampleRate = 48_000;
    public const int Channels = 2;
    public const int BitsPerSample = 16;
    public const int FrameDurationMs = 20;
    public const int SamplesPerFrame = SampleRate * FrameDurationMs / 1000;
    public const int PcmSamplesPerFrame = SamplesPerFrame * Channels;
    public const int PcmBytesPerFrame = PcmSamplesPerFrame * sizeof(short);
    public const int DefaultBitrate = 96_000;

    public const byte CodecOpus = 1;
    public const int ProtocolVersion = 1;
}
