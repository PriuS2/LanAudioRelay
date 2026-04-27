using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Net;
using System.Runtime.CompilerServices;
using System.Windows;
using LanAudioRelay.Core.Models;
using LanAudioRelay.Core.Networking;
using LanAudioRelay.Services;

namespace LanAudioRelay.ViewModels;

public sealed class MainViewModel : INotifyPropertyChanged, IAsyncDisposable
{
    private readonly DiscoveryClient _discoveryClient = new();
    private SenderSession? _senderSession;
    private ReceiverSession? _receiverSession;
    private ReceiverAnnouncement? _selectedReceiver;
    private string _manualReceiverIp = "";
    private string _senderPairingCode = "";
    private string _senderStatus = "Choose a receiver, enter its pairing code, then start streaming.";
    private string _receiverStatus = "Start the receiver on the PC that should play the audio.";
    private string _receiverLocalAddress = NetworkAddressProvider.GetLocalIPv4Summary();
    private string _receiverPairingCode = "";
    private float _inputLevel;
    private int _receiverBufferFrames;
    private double _receiverVolume = 0.85;
    private bool _isSenderRunning;
    private bool _isReceiverRunning;

    public MainViewModel()
    {
        DiscoverReceiversCommand = new AsyncRelayCommand(DiscoverReceiversAsync, () => !IsSenderRunning);
        StartSenderCommand = new AsyncRelayCommand(StartSenderAsync, () => !IsSenderRunning);
        StopSenderCommand = new AsyncRelayCommand(StopSenderAsync, () => IsSenderRunning);
        StartReceiverCommand = new AsyncRelayCommand(StartReceiverAsync, () => !IsReceiverRunning);
        StopReceiverCommand = new AsyncRelayCommand(StopReceiverAsync, () => IsReceiverRunning);
    }

    public event PropertyChangedEventHandler? PropertyChanged;

    public ObservableCollection<ReceiverAnnouncement> Receivers { get; } = new();

    public AsyncRelayCommand DiscoverReceiversCommand { get; }
    public AsyncRelayCommand StartSenderCommand { get; }
    public AsyncRelayCommand StopSenderCommand { get; }
    public AsyncRelayCommand StartReceiverCommand { get; }
    public AsyncRelayCommand StopReceiverCommand { get; }

    public ReceiverAnnouncement? SelectedReceiver
    {
        get => _selectedReceiver;
        set => SetField(ref _selectedReceiver, value);
    }

    public string ManualReceiverIp
    {
        get => _manualReceiverIp;
        set => SetField(ref _manualReceiverIp, value);
    }

    public string SenderPairingCode
    {
        get => _senderPairingCode;
        set => SetField(ref _senderPairingCode, value);
    }

    public string SenderStatus
    {
        get => _senderStatus;
        set => SetField(ref _senderStatus, value);
    }

    public string ReceiverStatus
    {
        get => _receiverStatus;
        set => SetField(ref _receiverStatus, value);
    }

    public string ReceiverLocalAddress
    {
        get => _receiverLocalAddress;
        set => SetField(ref _receiverLocalAddress, value);
    }

    public string ReceiverPairingCode
    {
        get => _receiverPairingCode;
        set => SetField(ref _receiverPairingCode, value);
    }

    public float InputLevel
    {
        get => _inputLevel;
        set => SetField(ref _inputLevel, value);
    }

    public int ReceiverBufferFrames
    {
        get => _receiverBufferFrames;
        set => SetField(ref _receiverBufferFrames, value);
    }

    public double ReceiverVolume
    {
        get => _receiverVolume;
        set
        {
            if (SetField(ref _receiverVolume, value))
            {
                if (_receiverSession is not null)
                {
                    _receiverSession.Volume = (float)value;
                }
            }
        }
    }

    public bool IsSenderRunning
    {
        get => _isSenderRunning;
        set
        {
            if (SetField(ref _isSenderRunning, value))
            {
                RaiseCommandStates();
            }
        }
    }

    public bool IsReceiverRunning
    {
        get => _isReceiverRunning;
        set
        {
            if (SetField(ref _isReceiverRunning, value))
            {
                RaiseCommandStates();
            }
        }
    }

    private async Task DiscoverReceiversAsync()
    {
        SenderStatus = "Searching receivers on the LAN...";
        var receivers = await _discoveryClient.DiscoverAsync(TimeSpan.FromSeconds(2)).ConfigureAwait(true);
        Receivers.Clear();
        foreach (var receiver in receivers)
        {
            Receivers.Add(receiver);
        }

        SelectedReceiver = Receivers.FirstOrDefault();
        SenderStatus = receivers.Count == 0
            ? "No receiver found. Start Receiver on the other PC or enter its IP manually."
            : $"Found {receivers.Count} receiver(s).";
    }

    private async Task StartSenderAsync()
    {
        var host = !string.IsNullOrWhiteSpace(ManualReceiverIp)
            ? ManualReceiverIp.Trim()
            : SelectedReceiver?.IpAddress;

        if (string.IsNullOrWhiteSpace(host) || !IPAddress.TryParse(host, out _))
        {
            SenderStatus = "Enter a valid receiver IPv4 address or select a discovered receiver.";
            return;
        }

        var code = new string(SenderPairingCode.Where(char.IsDigit).ToArray());
        if (code.Length != 6)
        {
            SenderStatus = "Enter the 6-digit pairing code shown on the receiver.";
            return;
        }

        _senderSession = new SenderSession();
        _senderSession.StatusChanged += (_, message) => RunOnUi(() => SenderStatus = message);
        _senderSession.InputLevelChanged += (_, level) => RunOnUi(() => InputLevel = level);

        try
        {
            await _senderSession.StartAsync(host, code).ConfigureAwait(true);
            IsSenderRunning = true;
        }
        catch (Exception ex)
        {
            SenderStatus = $"Failed to start sender: {ex.Message}";
            await _senderSession.DisposeAsync().ConfigureAwait(true);
            _senderSession = null;
            IsSenderRunning = false;
        }
    }

    private async Task StopSenderAsync()
    {
        if (_senderSession is not null)
        {
            await _senderSession.DisposeAsync().ConfigureAwait(true);
            _senderSession = null;
        }

        InputLevel = 0;
        IsSenderRunning = false;
    }

    private async Task StartReceiverAsync()
    {
        _receiverSession = new ReceiverSession
        {
            Volume = (float)ReceiverVolume
        };
        _receiverSession.StatusChanged += (_, message) => RunOnUi(() => ReceiverStatus = message);
        _receiverSession.BufferFramesChanged += (_, frames) => RunOnUi(() => ReceiverBufferFrames = frames);
        _receiverSession.PairingCodeChanged += (_, code) => RunOnUi(() => ReceiverPairingCode = code);

        try
        {
            ReceiverLocalAddress = NetworkAddressProvider.GetLocalIPv4Summary();
            await _receiverSession.StartAsync().ConfigureAwait(true);
            IsReceiverRunning = true;
        }
        catch (Exception ex)
        {
            ReceiverStatus = $"Failed to start receiver: {ex.Message}";
            await _receiverSession.DisposeAsync().ConfigureAwait(true);
            _receiverSession = null;
            IsReceiverRunning = false;
        }
    }

    private async Task StopReceiverAsync()
    {
        if (_receiverSession is not null)
        {
            await _receiverSession.DisposeAsync().ConfigureAwait(true);
            _receiverSession = null;
        }

        IsReceiverRunning = false;
    }

    private static void RunOnUi(Action action)
    {
        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
        {
            action();
            return;
        }

        dispatcher.BeginInvoke(action);
    }

    private void RaiseCommandStates()
    {
        DiscoverReceiversCommand.RaiseCanExecuteChanged();
        StartSenderCommand.RaiseCanExecuteChanged();
        StopSenderCommand.RaiseCanExecuteChanged();
        StartReceiverCommand.RaiseCanExecuteChanged();
        StopReceiverCommand.RaiseCanExecuteChanged();
    }

    private bool SetField<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
        {
            return false;
        }

        field = value;
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
        return true;
    }

    public async ValueTask DisposeAsync()
    {
        await StopSenderAsync().ConfigureAwait(true);
        await StopReceiverAsync().ConfigureAwait(true);
    }
}
