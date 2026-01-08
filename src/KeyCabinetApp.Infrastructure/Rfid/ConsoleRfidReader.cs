using KeyCabinetApp.Core.Interfaces;
using Microsoft.Extensions.Logging;
using System.Text;

namespace KeyCabinetApp.Infrastructure.Rfid;

/// <summary>
/// RFID reader implementation for console applications using keyboard wedge devices.
/// Reads from Console.In to capture RFID scans.
/// </summary>
public class ConsoleRfidReader : IRfidReader, IDisposable
{
    private readonly ILogger<ConsoleRfidReader> _logger;
    private bool _isListening;
    private CancellationTokenSource? _cancellationTokenSource;
    private Task? _readTask;

    public event EventHandler<string>? CardScanned;

    public ConsoleRfidReader(ILogger<ConsoleRfidReader> logger)
    {
        _logger = logger;
    }

    public bool IsListening => _isListening;

    public void StartListening()
    {
        if (_isListening)
            return;

        _isListening = true;
        _cancellationTokenSource = new CancellationTokenSource();
        _readTask = Task.Run(() => ReadConsoleInputAsync(_cancellationTokenSource.Token));
        _logger.LogInformation("Console RFID reader started listening");
    }

    public void StopListening()
    {
        if (!_isListening)
            return;

        _isListening = false;
        _cancellationTokenSource?.Cancel();
        _logger.LogInformation("Console RFID reader stopped listening");
    }

    private async Task ReadConsoleInputAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Waiting for RFID scans on console input...");

        while (!cancellationToken.IsCancellationRequested)
        {
            try
            {
                // Read a line from console (RFID reader sends card ID followed by Enter)
                var line = await Task.Run(() => Console.ReadLine(), cancellationToken);

                if (!string.IsNullOrWhiteSpace(line))
                {
                    var cardData = line.Trim();

                    // Validate that this looks like an RFID card
                    if (IsValidRfidFormat(cardData))
                    {
                        _logger.LogInformation("RFID card scanned: {CardId}", MaskCardData(cardData));
                        CardScanned?.Invoke(this, cardData);
                    }
                    else
                    {
                        _logger.LogDebug("Ignored non-RFID input: {Input}", cardData);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                // Normal shutdown
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error reading console input");
                await Task.Delay(1000, cancellationToken);
            }
        }
    }

    private bool IsValidRfidFormat(string data)
    {
        // Accept if it's at least 4 characters and contains only alphanumeric
        return data.Length >= 4 && data.All(c => char.IsLetterOrDigit(c));
    }

    private string MaskCardData(string cardData)
    {
        if (cardData.Length <= 4)
            return "****";
        return cardData.Substring(0, 2) + new string('*', cardData.Length - 4) + cardData.Substring(cardData.Length - 2);
    }

    public void Dispose()
    {
        StopListening();
        _cancellationTokenSource?.Dispose();
    }
}
