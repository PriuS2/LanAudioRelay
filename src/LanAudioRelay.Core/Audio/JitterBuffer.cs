using LanAudioRelay.Core.Protocol;

namespace LanAudioRelay.Core.Audio;

public sealed class JitterBuffer
{
    private readonly object _gate = new();
    private readonly SortedDictionary<uint, AudioPacket> _frames = new();
    private readonly int _targetDepth;
    private readonly int _maxFrames;
    private bool _started;
    private uint _expectedSequence;

    public JitterBuffer(int targetDepth = 3, int maxFrames = 128)
    {
        if (targetDepth < 1)
        {
            throw new ArgumentOutOfRangeException(nameof(targetDepth));
        }

        if (maxFrames <= targetDepth)
        {
            throw new ArgumentOutOfRangeException(nameof(maxFrames));
        }

        _targetDepth = targetDepth;
        _maxFrames = maxFrames;
    }

    public int BufferedFrameCount
    {
        get
        {
            lock (_gate)
            {
                return _frames.Count;
            }
        }
    }

    public long MissingFrames { get; private set; }

    public void Reset()
    {
        lock (_gate)
        {
            _frames.Clear();
            _started = false;
            _expectedSequence = 0;
            MissingFrames = 0;
        }
    }

    public void Push(AudioPacket packet)
    {
        lock (_gate)
        {
            if (_started && packet.Sequence < _expectedSequence)
            {
                return;
            }

            _frames[packet.Sequence] = packet;

            while (_frames.Count > _maxFrames)
            {
                _frames.Remove(_frames.Keys.First());
            }
        }
    }

    public bool TryPop(out AudioPacket? packet)
    {
        lock (_gate)
        {
            packet = null;

            if (!_started)
            {
                if (_frames.Count < _targetDepth)
                {
                    return false;
                }

                _expectedSequence = _frames.Keys.First();
                _started = true;
            }

            if (_frames.Remove(_expectedSequence, out packet))
            {
                _expectedSequence++;
                return true;
            }

            if (_frames.Count == 0)
            {
                _started = false;
                return false;
            }

            MissingFrames++;
            _expectedSequence++;
            return false;
        }
    }
}
