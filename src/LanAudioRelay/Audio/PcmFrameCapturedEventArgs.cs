namespace LanAudioRelay.Audio;

public sealed class PcmFrameCapturedEventArgs : EventArgs
{
    public PcmFrameCapturedEventArgs(short[] pcm, float level)
    {
        Pcm = pcm;
        Level = level;
    }

    public short[] Pcm { get; }
    public float Level { get; }
}
