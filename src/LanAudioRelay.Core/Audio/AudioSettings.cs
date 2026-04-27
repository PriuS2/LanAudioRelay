namespace LanAudioRelay.Core.Audio;

public sealed record AudioSettings(
    int SampleRate,
    int Channels,
    int FrameDurationMs,
    int Bitrate,
    byte Codec)
{
    public static AudioSettings Default { get; } = new(
        AudioConstants.SampleRate,
        AudioConstants.Channels,
        AudioConstants.FrameDurationMs,
        AudioConstants.DefaultBitrate,
        AudioConstants.CodecOpus);
}
