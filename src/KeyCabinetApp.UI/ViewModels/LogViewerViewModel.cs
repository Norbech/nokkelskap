using KeyCabinetApp.Application.Services;
using KeyCabinetApp.Core.Entities;
using Microsoft.Extensions.Logging;
using System.Collections.ObjectModel;
using System.IO;
using System.Windows.Input;

namespace KeyCabinetApp.UI.ViewModels;

public class LogViewerViewModel : ViewModelBase
{
    private readonly LoggingService _loggingService;
    private readonly ILogger<LogViewerViewModel> _logger;
    
    private DateTime _startDate = DateTime.Today.AddDays(-7);
    private DateTime _endDate = DateTime.Today.AddDays(1);
    private string _filterActionType = "All";
    private bool _isLoading;

    public LogViewerViewModel(
        LoggingService loggingService,
        ILogger<LogViewerViewModel> logger)
    {
        _loggingService = loggingService;
        _logger = logger;

        Events = new ObservableCollection<Event>();
        
        RefreshCommand = new AsyncRelayCommand(async _ => await LoadEventsAsync());
        ExportCommand = new AsyncRelayCommand(async _ => await ExportToCsvAsync());
        CloseCommand = new RelayCommand(_ => CloseRequested?.Invoke(this, EventArgs.Empty));
    }

    public ObservableCollection<Event> Events { get; }

    public DateTime StartDate
    {
        get => _startDate;
        set => SetProperty(ref _startDate, value);
    }

    public DateTime EndDate
    {
        get => _endDate;
        set => SetProperty(ref _endDate, value);
    }

    public string FilterActionType
    {
        get => _filterActionType;
        set => SetProperty(ref _filterActionType, value);
    }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public ICommand RefreshCommand { get; }
    public ICommand ExportCommand { get; }
    public ICommand CloseCommand { get; }

    public event EventHandler? CloseRequested;

    public async Task LoadEventsAsync()
    {
        IsLoading = true;

        try
        {
            string? actionType = FilterActionType == "All" ? null : FilterActionType;
            
            var events = await _loggingService.GetEventsAsync(
                actionType: actionType,
                startDate: StartDate,
                endDate: EndDate);

            Events.Clear();
            foreach (var evt in events)
            {
                Events.Add(evt);
            }

            _logger.LogInformation("Loaded {EventCount} events", Events.Count);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error loading events");
        }
        finally
        {
            IsLoading = false;
        }
    }

    private async Task ExportToCsvAsync()
    {
        try
        {
            var csv = await _loggingService.ExportToCsvAsync(Events);
            
            var fileName = $"KeyCabinetLog_{DateTime.Now:yyyyMMdd_HHmmss}.csv";
            var filePath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Desktop),
                fileName);

            await File.WriteAllTextAsync(filePath, csv);
            
            _logger.LogInformation("Exported {EventCount} events to {FilePath}", Events.Count, filePath);
            
            System.Windows.MessageBox.Show(
                $"Logg eksportert til:\n{filePath}",
                "Eksport fullført",
                System.Windows.MessageBoxButton.OK,
                System.Windows.MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error exporting events");
            System.Windows.MessageBox.Show(
                "Kunne ikke eksportere logg",
                "Feil",
                System.Windows.MessageBoxButton.OK,
                System.Windows.MessageBoxImage.Error);
        }
    }
}
