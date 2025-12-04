using System.Windows;
using WpfApp = System.Windows.Application;
using KeyCabinetApp.Application.Services;
using KeyCabinetApp.Core.Interfaces;
using KeyCabinetApp.Infrastructure.Api;
using KeyCabinetApp.Infrastructure.Data;
using KeyCabinetApp.Infrastructure.Data.Repositories;
using KeyCabinetApp.Infrastructure.Rfid;
using KeyCabinetApp.Infrastructure.Serial;
using KeyCabinetApp.UI.ViewModels;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using System.IO;

namespace KeyCabinetApp.UI;

public partial class App : WpfApp
{
    public IServiceProvider ServiceProvider { get; private set; } = null!;
    public IConfiguration Configuration { get; private set; } = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Load configuration
        var builder = new ConfigurationBuilder()
            .SetBasePath(Directory.GetCurrentDirectory())
            .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);

        Configuration = builder.Build();

        // Setup dependency injection
        var serviceCollection = new ServiceCollection();
        ConfigureServices(serviceCollection);
        ServiceProvider = serviceCollection.BuildServiceProvider();

        // Initialize database
        InitializeDatabase();

        // Start remote API if enabled
        StartRemoteApi();

        // Show main window
        var mainWindow = ServiceProvider.GetRequiredService<MainWindow>();
        mainWindow.Show();
    }

    private void ConfigureServices(IServiceCollection services)
    {
        // Configuration
        services.AddSingleton(Configuration);

        // Logging
        services.AddLogging(configure =>
        {
            configure.AddDebug();
            configure.AddConsole();
            configure.SetMinimumLevel(LogLevel.Information);
        });

        // Database
        var dbPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "KeyCabinetApp",
            "keycabinet.db");

        var dbDirectory = Path.GetDirectoryName(dbPath);
        if (!string.IsNullOrEmpty(dbDirectory) && !Directory.Exists(dbDirectory))
        {
            Directory.CreateDirectory(dbDirectory);
        }

        services.AddDbContext<ApplicationDbContext>(options =>
            options.UseSqlite($"Data Source={dbPath}"));

        // Repositories
        services.AddScoped<IUserRepository, UserRepository>();
        services.AddScoped<IKeyRepository, KeyRepository>();
        services.AddScoped<IEventRepository, EventRepository>();

        // Serial Configuration
        var serialConfig = new SerialConfig();
        Configuration.GetSection("SerialCommunication").Bind(serialConfig);
        services.AddSingleton(serialConfig);

        // Serial Communication
        services.AddSingleton<ISerialCommunication, Rs485Communication>();

        // RFID Reader
        services.AddSingleton<IRfidReader, KeyboardWedgeRfidReader>();

        // Application Services
        services.AddSingleton<AuthenticationService>();
        services.AddSingleton<KeyControlService>();
        services.AddSingleton<LoggingService>();

        // Remote API
        var apiConfig = new RemoteApiConfig();
        Configuration.GetSection("RemoteApi").Bind(apiConfig);
        services.AddSingleton(apiConfig);
        services.AddSingleton<RemoteApiServer>();

        // Database Seeder
        services.AddTransient<DatabaseSeeder>();

        // ViewModels
        services.AddTransient<MainViewModel>();
        services.AddTransient<LoginViewModel>();
        services.AddTransient<KeySelectionViewModel>();
        services.AddTransient<AdminViewModel>();
        services.AddTransient<LogViewerViewModel>();

        // Windows
        services.AddTransient<MainWindow>();
    }

    private void InitializeDatabase()
    {
        using var scope = ServiceProvider.CreateScope();
        var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
        seeder.SeedAsync().Wait();
    }

    private void StartRemoteApi()
    {
        var apiServer = ServiceProvider.GetRequiredService<RemoteApiServer>();
        var apiConfig = ServiceProvider.GetRequiredService<RemoteApiConfig>();
        
        if (apiConfig.Enabled)
        {
            Task.Run(async () => await apiServer.StartAsync());
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        // Cleanup
        var apiServer = ServiceProvider.GetService<RemoteApiServer>();
        apiServer?.StopAsync().Wait();

        var serialComm = ServiceProvider.GetService<ISerialCommunication>();
        serialComm?.Disconnect();

        base.OnExit(e);
    }
}
