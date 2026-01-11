using KeyCabinetApp.Application.Services;
using KeyCabinetApp.Core.Interfaces;
using KeyCabinetApp.Infrastructure.Data;
using KeyCabinetApp.Infrastructure.Data.Repositories;
using KeyCabinetApp.Web.Hubs;
using KeyCabinetApp.Web.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);

// Default to listening on all interfaces on port 5000 (HTTP only),
// but allow overrides via --urls / ASPNETCORE_URLS / configuration.
var urlsFromConfig = builder.Configuration["urls"];
var urlsFromEnv = Environment.GetEnvironmentVariable("ASPNETCORE_URLS");
var urlsProvidedInArgs = args.Any(a =>
    a.Equals("--urls", StringComparison.OrdinalIgnoreCase) ||
    a.StartsWith("--urls=", StringComparison.OrdinalIgnoreCase));

if (string.IsNullOrWhiteSpace(urlsFromConfig) &&
    string.IsNullOrWhiteSpace(urlsFromEnv) &&
    !urlsProvidedInArgs)
{
    builder.WebHost.UseUrls("http://0.0.0.0:5000");
}

// Add services to the container.
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddSignalR();

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

builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlite($"Data Source={dbPath}"), ServiceLifetime.Scoped);

// Repositories
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IKeyRepository, KeyRepository>();
builder.Services.AddScoped<IEventRepository, EventRepository>();
builder.Services.AddScoped<ISystemSettingsRepository, SystemSettingsRepository>();

// Application Services (scoped for Blazor Server)
builder.Services.AddScoped<AuthenticationService>();
builder.Services.AddScoped<LoggingService>();
builder.Services.AddScoped<SystemSettingsService>();

// Hardware proxy service (communicates with local agent via SignalR)
builder.Services.AddScoped<ISerialCommunication, HardwareProxyService>();
builder.Services.AddScoped<IRfidReader, RfidProxyService>();
builder.Services.AddScoped<KeyControlService>();

// Session state service
builder.Services.AddScoped<SessionStateService>();

// Hardware Agent connection manager
builder.Services.AddSingleton<HardwareAgentManager>();

// Key images (stored on disk under %APPDATA%\KeyCabinetApp\key-images and served via /key-images)
builder.Services.AddSingleton<KeyImageService>();

var app = builder.Build();

// Initialize database
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    await db.Database.EnsureCreatedAsync();
    
    // Seed database
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<DatabaseSeeder>>();
    var seeder = new DatabaseSeeder(db, logger);
    await seeder.SeedAsync();
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // app.UseHsts(); // Disabled for HTTP-only setup
}

// app.UseHttpsRedirection(); // Disabled - we're running HTTP only on port 5000
app.UseStaticFiles();

var keyImagesDir = Path.Combine(
    Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
    "KeyCabinetApp",
    "key-images");
Directory.CreateDirectory(keyImagesDir);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(keyImagesDir),
    RequestPath = "/key-images"
});

app.UseRouting();

app.MapGet("/health", () => Results.Ok("OK"));

app.MapBlazorHub();
app.MapHub<HardwareHub>("/hardwarehub");
app.MapFallbackToPage("/_Host");

app.Run();
