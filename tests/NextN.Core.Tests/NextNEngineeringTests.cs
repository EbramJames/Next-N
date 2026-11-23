using NextN.Core.Tests.CoreConfig;

namespace NextN.Core.Tests;

public class NextNEngineeringTests
{
    [Test]
    public async Task BrandingConstants_ShouldPointToNextNAndCustomRepository()
    {
        await Global.AppName.Should().BeEqualTo("Next N");
        await Global.AppSlug.Should().BeEqualTo("NextN");
        await Global.InnerUriProtocol.Should().BeEqualTo("nextn://");
        await Global.LegacyInnerUriProtocol.Should().BeEqualTo("v2rayn://");
        await Global.ProjectUrl.Should().BeEqualTo("https://github.com/EbramJames/Next-N");
        await Global.CoreUrls[ECoreType.NextN].Should().BeEqualTo("EbramJames/Next-N");

        var nextNCoreInfo = CoreInfoManager.Instance.GetCoreInfo(ECoreType.NextN);
        await nextNCoreInfo.Should().NotBeNull();
        await nextNCoreInfo!.Url!.Should().BeEqualTo("https://github.com/EbramJames/Next-N/releases");
        await nextNCoreInfo.DownloadUrlWin64!.Should().Contain("NextN-windows-x64-portable.zip");
    }

    [Test]
    public async Task InnerFmt_ShouldExportNextNUriAndAcceptLegacyV2rayNUri()
    {
        var node = CoreConfigTestFactory.CreateVmessNode(ECoreType.Xray, "nextn-test-node", "nextn-test-node");
        var exported = InnerFmt.ToUri([node]);

        await exported.Should().NotBeNull();
        await exported!.Trim().StartsWith("nextn://", StringComparison.OrdinalIgnoreCase).Should().BeTrue();

        // Round-trip modern nextn:// URI
        var resolvedModern = InnerFmt.Resolve(exported, "sub-modern");
        await resolvedModern.Should().NotBeNull();
        await resolvedModern!.Should().HaveCount(1);
        await resolvedModern[0].Remarks.Should().BeEqualTo("nextn-test-node");

        // Backward-compatibility: accept legacy v2rayn:// URI seamlessly
        var legacyUri = "v2rayn://" + exported.Trim()["nextn://".Length..];
        var resolvedLegacy = InnerFmt.Resolve(legacyUri, "sub-legacy");
        await resolvedLegacy.Should().NotBeNull();
        await resolvedLegacy!.Should().HaveCount(1);
        await resolvedLegacy[0].Remarks.Should().BeEqualTo("nextn-test-node");
    }

    [Test]
    public async Task TryParseMaxSplit_ShouldMatchTryParseRangeSemantics()
    {
        var okSingle = Utils.TryParseMaxSplit("5", 0, 100, out var from1, out var to1);
        await okSingle.Should().BeTrue();
        await from1.Should().BeEqualTo(5);
        await to1.Should().BeEqualTo(5);

        var okRange = Utils.TryParseMaxSplit("10-25", 0, 100, out var from2, out var to2);
        await okRange.Should().BeTrue();
        await from2.Should().BeEqualTo(10);
        await to2.Should().BeEqualTo(25);

        var badRange = Utils.TryParseMaxSplit("50-10", 0, 100, out _, out _);
        await badRange.Should().BeFalse();
    }

    [Test]
    public async Task StartupPath_ShouldUseNextNLocalAppDataWhenEnabled()
    {
        var previous = Environment.GetEnvironmentVariable(Global.LocalAppData);
        try
        {
            Environment.SetEnvironmentVariable(Global.LocalAppData, "1", EnvironmentVariableTarget.Process);
            var path = Utils.StartupPath();
            await path.EndsWith(Path.DirectorySeparatorChar + Global.AppSlug, StringComparison.OrdinalIgnoreCase).Should().BeTrue();
        }
        finally
        {
            Environment.SetEnvironmentVariable(Global.LocalAppData, previous, EnvironmentVariableTarget.Process);
        }
    }
}
