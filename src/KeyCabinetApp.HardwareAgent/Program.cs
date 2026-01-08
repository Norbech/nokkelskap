using KeyCabinetApp.HardwareAgent;
using KeyCabinetApp.HardwareAgent.Services;
using KeyCabinetApp.Infrastructure.Rfid;
using KeyCabinetApp.Infrastructure.Serial;

var builder = Host.CreateApplicationBuilder(args);

// Load configuration
builder.Configuration
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);

// Add services
builder.Services.AddSingleton<SerialConfig>(sp =>
{
    var config = new SerialConfig();
    builder.Configuration.GetSection("SerialCommunication").Bind(config);
    return config;
});

builder.Services.AddSingleton<Rs485Communication>();
builder.Services.AddSingleton<GlobalKeyboardRfidReader>();
builder.Services.AddSingleton<SignalRClientService>();
builder.Services.AddHostedService<HardwareAgentWorker>();

// Support running as Windows Service
builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "KeyCabinet Hardware Agent";
});

var host = builder.Build();
host.Run();
