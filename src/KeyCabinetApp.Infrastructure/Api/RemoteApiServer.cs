using KeyCabinetApp.Application.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using System.Text.Json;

namespace KeyCabinetApp.Infrastructure.Api;

public class RemoteApiConfig
{
    public bool Enabled { get; set; } = false;
    public int Port { get; set; } = 5000;
    public string[] AllowedIpAddresses { get; set; } = Array.Empty<string>();
}

public class RemoteOpenRequest
{
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public int SlotId { get; set; }
}

public class RemoteOpenResponse
{
    public bool Success { get; set; }
    public string Message { get; set; } = string.Empty;
}

/// <summary>
/// Self-hosted HTTP API server for remote key opening
/// </summary>
public class RemoteApiServer : IDisposable
{
    private readonly RemoteApiConfig _config;
    private readonly AuthenticationService _authService;
    private readonly KeyControlService _keyControlService;
    private readonly ILogger<RemoteApiServer> _logger;
    private WebApplication? _app;
    private bool _isRunning;

    public RemoteApiServer(
        RemoteApiConfig config,
        AuthenticationService authService,
        KeyControlService keyControlService,
        ILogger<RemoteApiServer> logger)
    {
        _config = config;
        _authService = authService;
        _keyControlService = keyControlService;
        _logger = logger;
    }

    public bool IsRunning => _isRunning;

    public async Task StartAsync()
    {
        if (!_config.Enabled)
        {
            _logger.LogInformation("Remote API is disabled in configuration");
            return;
        }

        if (_isRunning)
        {
            _logger.LogWarning("Remote API is already running");
            return;
        }

        try
        {
            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                Args = new[] { $"--urls=http://localhost:{_config.Port}" }
            });
            
            _app = builder.Build();

            // IP filtering middleware
            _app.Use(async (context, next) =>
            {
                var remoteIp = context.Connection.RemoteIpAddress?.ToString() ?? "";
                
                if (_config.AllowedIpAddresses.Length > 0 && 
                    !_config.AllowedIpAddresses.Contains(remoteIp) &&
                    remoteIp != "::1" && // localhost IPv6
                    remoteIp != "127.0.0.1") // localhost IPv4
                {
                    _logger.LogWarning("Blocked request from unauthorized IP: {RemoteIp}", remoteIp);
                    context.Response.StatusCode = 403;
                    await context.Response.WriteAsync("Forbidden");
                    return;
                }

                await next();
            });

            // Health check endpoint
            _app.MapGet("/api/health", () => 
            {
                return Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow });
            });

            // Remote open endpoint
            _app.MapPost("/api/open", async (HttpContext context) =>
            {
                try
                {
                    var request = await JsonSerializer.DeserializeAsync<RemoteOpenRequest>(
                        context.Request.Body,
                        new JsonSerializerOptions { PropertyNameCaseInsensitive = true });

                    if (request == null)
                    {
                        return Results.BadRequest(new RemoteOpenResponse 
                        { 
                            Success = false, 
                            Message = "Invalid request" 
                        });
                    }

                    _logger.LogInformation("Remote open request for slot {SlotId} from user {Username}", 
                        request.SlotId, request.Username);

                    // Authenticate
                    var (authSuccess, user) = await _authService.AuthenticateForRemoteAccessAsync(
                        request.Username, request.Password);

                    if (!authSuccess || user == null)
                    {
                        _logger.LogWarning("Remote authentication failed for user {Username}", request.Username);
                        return Results.Unauthorized();
                    }

                    // Check if user has access to this key
                    var hasAccess = await _keyControlService.UserHasAccessToKeyAsync(user.Id, request.SlotId);
                    if (!hasAccess)
                    {
                        // Try to get key by slot ID
                        var (openSuccess, message) = await _keyControlService.OpenKeyBySlotIdAsync(
                            request.SlotId, user.Id, "REMOTE");

                        return Results.Ok(new RemoteOpenResponse
                        {
                            Success = openSuccess,
                            Message = message
                        });
                    }

                    // Open the key
                    var (success, msg) = await _keyControlService.OpenKeyBySlotIdAsync(
                        request.SlotId, user.Id, "REMOTE");

                    return Results.Ok(new RemoteOpenResponse
                    {
                        Success = success,
                        Message = msg
                    });
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error processing remote open request");
                    return Results.Ok(new RemoteOpenResponse
                    {
                        Success = false,
                        Message = "Internal server error"
                    });
                }
            });

            await _app.StartAsync();
            _isRunning = true;
            _logger.LogInformation("Remote API server started on port {Port}", _config.Port);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to start Remote API server");
            throw;
        }
    }

    public async Task StopAsync()
    {
        if (_app != null && _isRunning)
        {
            await _app.StopAsync();
            _isRunning = false;
            _logger.LogInformation("Remote API server stopped");
        }
    }

    public void Dispose()
    {
        _app?.DisposeAsync().AsTask().Wait();
    }
}
