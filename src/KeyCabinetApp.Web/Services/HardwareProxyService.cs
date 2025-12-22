using KeyCabinetApp.Core.Interfaces;
using KeyCabinetApp.Web.Hubs;

namespace KeyCabinetApp.Web.Services;

/// <summary>
/// Proxy service that forwards serial commands to the hardware agent via SignalR
/// </summary>
public class HardwareProxyService : ISerialCommunication
{
    private readonly HardwareAgentManager _agentManager;
    private readonly ILogger<HardwareProxyService> _logger;

    public HardwareProxyService(HardwareAgentManager agentManager, ILogger<HardwareProxyService> logger)
    {
        _agentManager = agentManager;
        _logger = logger;
    }

    public bool IsConnected => _agentManager.IsAgentConnected;

    public async Task<bool> ConnectAsync()
    {
        if (!_agentManager.IsAgentConnected)
        {
            _logger.LogWarning("No hardware agent connected");
            return false;
        }

        try
        {
            return await _agentManager.SendCommandAsync("connect");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect via hardware agent");
            return false;
        }
    }

    public void Disconnect()
    {
        if (_agentManager.IsAgentConnected)
        {
            _ = _agentManager.SendCommandAsync("disconnect");
        }
    }

    public async Task<bool> OpenSlotAsync(int slotId)
    {
        if (!_agentManager.IsAgentConnected)
        {
            _logger.LogWarning("No hardware agent connected, cannot open slot {SlotId}", slotId);
            return false;
        }

        try
        {
            _logger.LogInformation("Sending open slot command for slot {SlotId}", slotId);
            return await _agentManager.OpenSlotAsync(slotId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to open slot {SlotId}", slotId);
            return false;
        }
    }

    public async Task<string?> GetSlotStatusAsync(int slotId)
    {
        if (!_agentManager.IsAgentConnected)
        {
            return "Agent ikke tilkoblet";
        }

        try
        {
            return await _agentManager.GetSlotStatusAsync(slotId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to get status for slot {SlotId}", slotId);
            return null;
        }
    }

    public Task<byte[]?> SendCommandAsync(byte[] command)
    {
        // Raw commands are not supported through the proxy
        _logger.LogWarning("Raw command sending not supported through hardware proxy");
        return Task.FromResult<byte[]?>(null);
    }
}
