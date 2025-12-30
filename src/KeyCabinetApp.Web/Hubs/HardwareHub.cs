using Microsoft.AspNetCore.SignalR;
using KeyCabinetApp.Web.Services;

namespace KeyCabinetApp.Web.Hubs;

/// <summary>
/// SignalR Hub for communication between web server and hardware agent
/// </summary>
public class HardwareHub : Hub
{
    private readonly HardwareAgentManager _agentManager;
    private readonly ILogger<HardwareHub> _logger;

    public HardwareHub(HardwareAgentManager agentManager, ILogger<HardwareHub> logger)
    {
        _agentManager = agentManager;
        _logger = logger;
    }

    /// <summary>
    /// Called when hardware agent connects and registers itself
    /// </summary>
    public async Task RegisterAgent(string agentId)
    {
        _agentManager.RegisterAgent(Context.ConnectionId, agentId);
        _logger.LogInformation("Agent {AgentId} registered with connection {ConnectionId}", agentId, Context.ConnectionId);
        await Clients.Caller.SendAsync("Registered", true);
    }

    /// <summary>
    /// Called when hardware agent reports an RFID scan
    /// </summary>
    public Task ReportRfidScan(string rfidTag)
    {
        _logger.LogInformation("RFID scan reported from agent");
        _agentManager.OnRfidScanned(rfidTag);
        return Task.CompletedTask;
    }

    /// <summary>
    /// Called when hardware agent reports command result
    /// </summary>
    public Task ReportCommandResult(bool success)
    {
        _logger.LogInformation("Command result: {Success}", success);
        _agentManager.OnCommandResult(success);
        return Task.CompletedTask;
    }

    /// <summary>
    /// Called when hardware agent reports slot status
    /// </summary>
    public async Task ReportSlotStatus(string? status)
    {
        _logger.LogInformation("Slot status: {Status}", status);
        _agentManager.OnStatusResult(status);

        // Allow monitoring clients (e.g. diagnostic sniffers) to observe status reports.
        await Clients.All.SendAsync("SlotStatusReported", status);
    }

    public override Task OnConnectedAsync()
    {
        _logger.LogInformation("Client connected: {ConnectionId}", Context.ConnectionId);
        return base.OnConnectedAsync();
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        _agentManager.UnregisterAgent(Context.ConnectionId);
        _logger.LogInformation("Client disconnected: {ConnectionId}", Context.ConnectionId);
        return base.OnDisconnectedAsync(exception);
    }
}
