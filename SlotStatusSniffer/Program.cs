using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR.Client;

class Program
{
    public static async Task Main(string[] args)
    {
        Console.WriteLine("Starter SlotStatusSniffer...");

        // Sett inn riktig URL til SignalR-huben her:
        var hubUrl = "http://localhost:5000/hardwarehub"; // Endre til riktig adresse om nødvendig

        var connection = new HubConnectionBuilder()
            .WithUrl(hubUrl)
            .WithAutomaticReconnect()
            .Build();

        connection.On<string>("SlotStatusReported", (status) =>
        {
            Console.WriteLine($"[SlotStatus] {DateTime.Now:HH:mm:ss} - Status: {status}");
        });

        connection.Closed += async (error) =>
        {
            Console.WriteLine($"Tilkoblingen ble brutt: {error?.Message}");
            await Task.Delay(2000);
            await connection.StartAsync();
        };

        try
        {
            await connection.StartAsync();
            Console.WriteLine("Tilkoblet SignalR-hub. Lytter på slot-status...");
            Console.WriteLine("Trykk Ctrl+C for å avslutte.");
            await Task.Delay(-1);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Klarte ikke å koble til SignalR-hub: {ex.Message}");
        }
    }
}
