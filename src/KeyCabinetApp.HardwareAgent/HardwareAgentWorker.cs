using KeyCabinetApp.HardwareAgent.Services;
using KeyCabinetApp.Infrastructure.Rfid;
using KeyCabinetApp.Infrastructure.Serial;

namespace KeyCabinetApp.HardwareAgent;

/// <summary>
/// Background worker that manages hardware communication
/// </summary>
public class HardwareAgentWorker : BackgroundService
{
    private readonly SignalRClientService _signalRClient;
    private readonly Rs485Communication _serialComm;
    private readonly GlobalKeyboardRfidReader _rfidReader;
    private readonly ILogger<HardwareAgentWorker> _logger;

    public HardwareAgentWorker(
        SignalRClientService signalRClient,
        Rs485Communication serialComm,
        GlobalKeyboardRfidReader rfidReader,
        ILogger<HardwareAgentWorker> logger)
    {
        _signalRClient = signalRClient;
        _serialComm = serialComm;
        _rfidReader = rfidReader;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Hardware Agent starting...");

        // Subscribe to events
        _rfidReader.CardScanned += OnRfidCardScanned;
        _signalRClient.OpenSlotRequested += OnOpenSlotRequested;
        _signalRClient.GetSlotStatusRequested += OnGetSlotStatusRequested;
        _signalRClient.CommandReceived += OnCommandReceived;

        // Start RFID reader
        _rfidReader.StartListening();
        _logger.LogInformation("RFID reader started");

        // Connect to serial port
        try
        {
            await _serialComm.ConnectAsync();
            _logger.LogInformation("Serial communication connected");
        }
        catch (Exception ex)
        {
            _logger.LogWarning("Failed to connect serial port: {Message}", ex.Message);
        }

        // Connect to server
        await _signalRClient.ConnectAsync(stoppingToken);

        // Keep running
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(1000, stoppingToken);
        }

        // Cleanup
        _rfidReader.StopListening();
        _serialComm.Disconnect();
        await _signalRClient.DisconnectAsync();

        _logger.LogInformation("Hardware Agent stopped");
    }

    private async void OnRfidCardScanned(object? sender, string rfidTag)
    {
        _logger.LogInformation("RFID card scanned: {Tag}", MaskRfid(rfidTag));
        await _signalRClient.ReportRfidScanAsync(rfidTag);
    }

    private async void OnOpenSlotRequested(object? sender, int slotId)
    {
        _logger.LogInformation("Opening slot {SlotId}", slotId);

        try
        {
            if (!_serialComm.IsConnected)
            {
                await _serialComm.ConnectAsync();
            }

            var success = await _serialComm.OpenSlotAsync(slotId);
            _logger.LogInformation("Slot {SlotId} open result: {Success}", slotId, success);
            await _signalRClient.ReportCommandResultAsync(success);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to open slot {SlotId}", slotId);
            await _signalRClient.ReportCommandResultAsync(false);
        }
    }

    private async void OnGetSlotStatusRequested(object? sender, int slotId)
    {
        _logger.LogInformation("Getting status for slot {SlotId}", slotId);

        try
        {
            var status = await _serialComm.GetSlotStatusAsync(slotId);
            await _signalRClient.ReportSlotStatusAsync(status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get status for slot {SlotId}", slotId);
            await _signalRClient.ReportSlotStatusAsync(null);
        }
    }

    private async void OnCommandReceived(object? sender, string command)
    {
        _logger.LogInformation("Command received: {Command}", command);

        try
        {
            switch (command.ToLower())
            {
                case "connect":
                    var connected = await _serialComm.ConnectAsync();
                    await _signalRClient.ReportCommandResultAsync(connected);
                    break;

                case "disconnect":
                    _serialComm.Disconnect();
                    await _signalRClient.ReportCommandResultAsync(true);
                    break;

                default:
                    _logger.LogWarning("Unknown command: {Command}", command);
                    await _signalRClient.ReportCommandResultAsync(false);
                    break;
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to execute command: {Command}", command);
            await _signalRClient.ReportCommandResultAsync(false);
        }
    }

    private static string MaskRfid(string rfid)
    {
        if (string.IsNullOrEmpty(rfid) || rfid.Length < 4)
            return "****";
        return rfid[..2] + new string('*', rfid.Length - 4) + rfid[^2..];
    }
}
