using Microsoft.AspNetCore.SignalR.Client;

namespace KeyCabinetApp.HardwareAgent.Services;

/// <summary>
/// SignalR client that connects to the web server
/// </summary>
public class SignalRClientService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SignalRClientService> _logger;
    private HubConnection? _hubConnection;
    private bool _isConnected;

    public SignalRClientService(IConfiguration configuration, ILogger<SignalRClientService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public bool IsConnected => _isConnected;

    public event EventHandler<int>? OpenSlotRequested;
    public event EventHandler<int>? GetSlotStatusRequested;
    public event EventHandler<string>? CommandReceived;

    public async Task ConnectAsync(CancellationToken cancellationToken)
    {
        var serverUrl = _configuration["ServerUrl"] ?? "https://localhost:5001";
        var agentId = _configuration["AgentId"] ?? Environment.MachineName;

        _hubConnection = new HubConnectionBuilder()
            .WithUrl($"{serverUrl}/hardwarehub")
            .WithAutomaticReconnect(new[] { TimeSpan.Zero, TimeSpan.FromSeconds(2), TimeSpan.FromSeconds(5), TimeSpan.FromSeconds(10) })
            .Build();

        // Handle server commands
        _hubConnection.On<int>("OpenSlot", slotId =>
        {
            _logger.LogInformation("Received OpenSlot command for slot {SlotId}", slotId);
            OpenSlotRequested?.Invoke(this, slotId);
        });

        _hubConnection.On<int>("GetSlotStatus", slotId =>
        {
            _logger.LogInformation("Received GetSlotStatus command for slot {SlotId}", slotId);
            GetSlotStatusRequested?.Invoke(this, slotId);
        });

        _hubConnection.On<string>("ExecuteCommand", command =>
        {
            _logger.LogInformation("Received command: {Command}", command);
            CommandReceived?.Invoke(this, command);
        });

        _hubConnection.Closed += async error =>
        {
            _isConnected = false;
            _logger.LogWarning("Connection closed: {Error}", error?.Message);
            await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
        };

        _hubConnection.Reconnected += async connectionId =>
        {
            _isConnected = true;
            _logger.LogInformation("Reconnected with connection ID: {ConnectionId}", connectionId);
            await RegisterAsync(agentId);
        };

        await ConnectWithRetryAsync(agentId, cancellationToken);
    }

    private async Task ConnectWithRetryAsync(string agentId, CancellationToken cancellationToken)
    {
        var reconnectDelay = _configuration.GetValue<int>("ReconnectDelaySeconds", 5);

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                _logger.LogInformation("Attempting to connect to server...");
                await _hubConnection!.StartAsync(cancellationToken);
                _isConnected = true;
                _logger.LogInformation("Connected to server successfully");
                await RegisterAsync(agentId);
                break;
            }
            catch (Exception ex)
            {
                _isConnected = false;
                _logger.LogWarning("Failed to connect: {Message}. Retrying in {Delay} seconds...", 
                    ex.Message, reconnectDelay);
                await Task.Delay(TimeSpan.FromSeconds(reconnectDelay), cancellationToken);
            }
        }
    }

    private async Task RegisterAsync(string agentId)
    {
        try
        {
            await _hubConnection!.InvokeAsync("RegisterAgent", agentId);
            _logger.LogInformation("Registered with server as {AgentId}", agentId);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to register with server");
        }
    }

    public async Task ReportRfidScanAsync(string rfidTag)
    {
        if (!_isConnected || _hubConnection == null) return;

        try
        {
            await _hubConnection.InvokeAsync("ReportRfidScan", rfidTag);
            _logger.LogInformation("Reported RFID scan to server");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to report RFID scan");
        }
    }

    public async Task ReportCommandResultAsync(bool success)
    {
        if (!_isConnected || _hubConnection == null) return;

        try
        {
            await _hubConnection.InvokeAsync("ReportCommandResult", success);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to report command result");
        }
    }

    public async Task ReportSlotStatusAsync(string? status)
    {
        if (!_isConnected || _hubConnection == null) return;

        try
        {
            await _hubConnection.InvokeAsync("ReportSlotStatus", status);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to report slot status");
        }
    }

    public async Task DisconnectAsync()
    {
        if (_hubConnection != null)
        {
            await _hubConnection.StopAsync();
            await _hubConnection.DisposeAsync();
        }
    }
}
