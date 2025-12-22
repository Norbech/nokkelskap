using KeyCabinetApp.Core.Interfaces;

namespace KeyCabinetApp.Web.Services;

/// <summary>
/// Proxy service that receives RFID events from the hardware agent via SignalR
/// </summary>
public class RfidProxyService : IRfidReader
{
    private readonly HardwareAgentManager _agentManager;
    private readonly ILogger<RfidProxyService> _logger;

    public RfidProxyService(HardwareAgentManager agentManager, ILogger<RfidProxyService> logger)
    {
        _agentManager = agentManager;
        _logger = logger;

        // Subscribe to RFID events from agent manager
        _agentManager.RfidScanned += OnAgentRfidScanned;
    }

    public event EventHandler<string>? CardScanned;

    public bool IsListening { get; private set; }

    private void OnAgentRfidScanned(object? sender, string rfidTag)
    {
        _logger.LogInformation("RFID tag received from agent: {RfidTag}", MaskRfid(rfidTag));
        CardScanned?.Invoke(this, rfidTag);
    }

    public void StartListening()
    {
        IsListening = true;
        _logger.LogInformation("RFID proxy listening started");
    }

    public void StopListening()
    {
        IsListening = false;
        _logger.LogInformation("RFID proxy listening stopped");
    }

    public void Dispose()
    {
        _agentManager.RfidScanned -= OnAgentRfidScanned;
    }

    private static string MaskRfid(string rfid)
    {
        if (string.IsNullOrEmpty(rfid) || rfid.Length < 4)
            return "****";
        return rfid[..2] + new string('*', rfid.Length - 4) + rfid[^2..];
    }
}
