using KeyCabinetApp.Core.Entities;
using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace KeyCabinetApp.Application.Services;

public class LoggingService
{
    private readonly IEventRepository _eventRepository;
    private readonly IUserRepository _userRepository;
    private readonly IKeyRepository _keyRepository;
    private readonly ILogger<LoggingService> _logger;

    public LoggingService(
        IEventRepository eventRepository,
        IUserRepository userRepository,
        IKeyRepository keyRepository,
        ILogger<LoggingService> logger)
    {
        _eventRepository = eventRepository;
        _userRepository = userRepository;
        _keyRepository = keyRepository;
        _logger = logger;
    }

    /// <summary>
    /// Gets all events with optional filters
    /// </summary>
    public async Task<IEnumerable<Event>> GetEventsAsync(
        int? userId = null,
        int? keyId = null,
        string? actionType = null,
        DateTime? startDate = null,
        DateTime? endDate = null)
    {
        try
        {
            return await _eventRepository.GetByFilterAsync(userId, keyId, actionType, startDate, endDate);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving events");
            return Enumerable.Empty<Event>();
        }
    }

    /// <summary>
    /// Gets events for a specific date range
    /// </summary>
    public async Task<IEnumerable<Event>> GetEventsByDateRangeAsync(DateTime startDate, DateTime endDate)
    {
        try
        {
            return await _eventRepository.GetByDateRangeAsync(startDate, endDate);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving events by date range");
            return Enumerable.Empty<Event>();
        }
    }

    /// <summary>
    /// Gets events with date range and optional type filter
    /// </summary>
    public async Task<IEnumerable<Event>> GetEventsAsync(DateTime startDate, DateTime endDate, string? eventType = null)
    {
        try
        {
            var events = await _eventRepository.GetByDateRangeAsync(startDate, endDate);
            
            if (!string.IsNullOrEmpty(eventType))
            {
                events = events.Where(e => e.ActionType == eventType);
            }
            
            return events;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving events");
            return Enumerable.Empty<Event>();
        }
    }

    /// <summary>
    /// Gets recent events (last N events)
    /// </summary>
    public async Task<IEnumerable<Event>> GetRecentEventsAsync(int count = 100)
    {
        try
        {
            var allEvents = await _eventRepository.GetAllAsync();
            return allEvents.OrderByDescending(e => e.Timestamp).Take(count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error retrieving recent events");
            return Enumerable.Empty<Event>();
        }
    }

    /// <summary>
    /// Exports events to CSV format
    /// </summary>
    public async Task<string> ExportToCsvAsync(IEnumerable<Event> events)
    {
        try
        {
            var csv = new System.Text.StringBuilder();
            csv.AppendLine("Timestamp,User,Key,SlotId,ActionType,AuthMethod,Success,Details");

            foreach (var evt in events.OrderBy(e => e.Timestamp))
            {
                var user = evt.UserId.HasValue ? await _userRepository.GetByIdAsync(evt.UserId.Value) : null;
                var key = evt.KeyId.HasValue ? await _keyRepository.GetByIdAsync(evt.KeyId.Value) : null;

                csv.AppendLine($"\"{evt.Timestamp:yyyy-MM-dd HH:mm:ss}\"," +
                              $"\"{user?.Name ?? "N/A"}\"," +
                              $"\"{key?.Name ?? "N/A"}\"," +
                              $"\"{evt.SlotId?.ToString() ?? "N/A"}\"," +
                              $"\"{evt.ActionType}\"," +
                              $"\"{evt.AuthMethod}\"," +
                              $"\"{evt.Success}\"," +
                              $"\"{evt.Details?.Replace("\"", "\"\"") ?? ""}\"");
            }

            return csv.ToString();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error exporting events to CSV");
            throw;
        }
    }

    /// <summary>
    /// Logs a custom event
    /// </summary>
    public async Task LogEventAsync(string actionType, int? userId = null, int? keyId = null, 
        int? slotId = null, string authMethod = "NONE", string? details = null, bool success = true)
    {
        try
        {
            await _eventRepository.AddAsync(new Event
            {
                Timestamp = DateTime.UtcNow,
                UserId = userId,
                KeyId = keyId,
                SlotId = slotId,
                ActionType = actionType,
                AuthMethod = authMethod,
                Details = details,
                Success = success
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error logging custom event");
        }
    }
}
