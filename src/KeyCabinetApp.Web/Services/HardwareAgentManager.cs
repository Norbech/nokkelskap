using System.Collections.Concurrent;
using Microsoft.AspNetCore.SignalR;
using KeyCabinetApp.Web.Hubs;

namespace KeyCabinetApp.Web.Services;

/// <summary>
/// Manages connections from hardware agents
/// </summary>
public class HardwareAgentManager
{
    private readonly ILogger<HardwareAgentManager> _logger;
    private readonly IHubContext<HardwareHub>? _hubContext;
    private readonly ConcurrentDictionary<string, AgentConnection> _agents = new();
    private readonly SemaphoreSlim _commandLock = new(1, 1);
    private TaskCompletionSource<bool>? _pendingCommand;
    private TaskCompletionSource<string?>? _pendingStatusQuery;

    public HardwareAgentManager(ILogger<HardwareAgentManager> logger, IServiceProvider serviceProvider)
    {
        _logger = logger;
        // Get hub context - may be null during startup
        _hubContext = serviceProvider.GetService<IHubContext<HardwareHub>>();
    }

    public event EventHandler<string>? RfidScanned;

    public bool IsAgentConnected => _agents.Any(a => a.Value.IsConnected);

    public void RegisterAgent(string connectionId, string agentId)
    {
        var connection = new AgentConnection
        {
            ConnectionId = connectionId,
            AgentId = agentId,
            ConnectedAt = DateTime.UtcNow,
            IsConnected = true
        };

        _agents[connectionId] = connection;
        _logger.LogInformation("Hardware agent registered: {AgentId}", agentId);
    }

    public void UnregisterAgent(string connectionId)
    {
        if (_agents.TryRemove(connectionId, out var connection))
        {
            _logger.LogInformation("Hardware agent disconnected: {AgentId}", connection.AgentId);
        }
    }

    public void OnRfidScanned(string rfidTag)
    {
        _logger.LogInformation("RFID scan received from agent: {RfidTag}", MaskRfid(rfidTag));
        RfidScanned?.Invoke(this, rfidTag);
    }

    private static string MaskRfid(string rfid)
    {
        if (string.IsNullOrEmpty(rfid) || rfid.Length < 4)
            return "****";
        return rfid[..2] + new string('*', rfid.Length - 4) + rfid[^2..];
    }

    public void OnCommandResult(bool success)
    {
        _pendingCommand?.TrySetResult(success);
    }

    public void OnStatusResult(string? status)
    {
        _pendingStatusQuery?.TrySetResult(status);
    }

    public async Task<bool> SendCommandAsync(string command)
    {
        if (_hubContext == null || !IsAgentConnected)
        {
            _logger.LogWarning("Cannot send command: No agent connected or hub not available");
            return false;
        }

        await _commandLock.WaitAsync();
        try
        {
            _pendingCommand = new TaskCompletionSource<bool>();

            var agent = _agents.Values.First(a => a.IsConnected);
            await _hubContext.Clients.Client(agent.ConnectionId).SendAsync("ExecuteCommand", command);

            // Wait for response with timeout
            var completed = await Task.WhenAny(_pendingCommand.Task, Task.Delay(5000));
            if (completed == _pendingCommand.Task)
            {
                return await _pendingCommand.Task;
            }

            _logger.LogWarning("Command timeout");
            return false;
        }
        finally
        {
            _pendingCommand = null;
            _commandLock.Release();
        }
    }

    public async Task<bool> OpenSlotAsync(int slotId)
    {
        if (_hubContext == null || !IsAgentConnected)
        {
            _logger.LogWarning("Cannot open slot: No agent connected");
            return false;
        }

        await _commandLock.WaitAsync();
        try
        {
            _pendingCommand = new TaskCompletionSource<bool>();

            var agent = _agents.Values.First(a => a.IsConnected);
            await _hubContext.Clients.Client(agent.ConnectionId).SendAsync("OpenSlot", slotId);

            var completed = await Task.WhenAny(_pendingCommand.Task, Task.Delay(5000));
            if (completed == _pendingCommand.Task)
            {
                return await _pendingCommand.Task;
            }

            _logger.LogWarning("Open slot timeout");
            return false;
        }
        finally
        {
            _pendingCommand = null;
            _commandLock.Release();
        }
    }

    public async Task<string?> GetSlotStatusAsync(int slotId)
    {
        if (_hubContext == null || !IsAgentConnected)
        {
            return null;
        }

        await _commandLock.WaitAsync();
        try
        {
            _pendingStatusQuery = new TaskCompletionSource<string?>();

            var agent = _agents.Values.First(a => a.IsConnected);
            await _hubContext.Clients.Client(agent.ConnectionId).SendAsync("GetSlotStatus", slotId);

            var completed = await Task.WhenAny(_pendingStatusQuery.Task, Task.Delay(5000));
            if (completed == _pendingStatusQuery.Task)
            {
                return await _pendingStatusQuery.Task;
            }

            return null;
        }
        finally
        {
            _pendingStatusQuery = null;
            _commandLock.Release();
        }
    }

    public IEnumerable<AgentConnection> GetConnectedAgents()
    {
        return _agents.Values.Where(a => a.IsConnected);
    }
}

public class AgentConnection
{
    public string ConnectionId { get; set; } = string.Empty;
    public string AgentId { get; set; } = string.Empty;
    public DateTime ConnectedAt { get; set; }
    public bool IsConnected { get; set; }
}
