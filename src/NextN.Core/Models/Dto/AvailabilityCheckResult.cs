namespace NextN.Core.Models.Dto;

public sealed record AvailabilityCheckResult(int Time, string Ip)
{
    public string? GetValidIp() => Ip == Global.None ? null : Ip;
}