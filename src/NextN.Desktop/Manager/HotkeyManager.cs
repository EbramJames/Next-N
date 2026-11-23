using Avalonia.Win32.Input;
using NextN.Desktop.Platform;

namespace NextN.Desktop.Manager;

public sealed class HotkeyManager
{
    private static readonly Lazy<HotkeyManager> _instance = new(() => new());
    public static HotkeyManager Instance => _instance.Value;

    private readonly Dictionary<int, EGlobalHotkey> _hotkeyTriggerDic = new();

    [SupportedOSPlatform("windows")]
    private Win32GlobalHotkeyEngine? _engine;

    private Config? _config;
    private event Action<EGlobalHotkey>? _updateFunc;

    public bool IsPause { get; set; }

    [SupportedOSPlatform("windows")]
    public void Init(Config config, Action<EGlobalHotkey> updateFunc)
    {
        _config = config;
        _updateFunc = updateFunc;

        Register();
    }

    [SupportedOSPlatform("windows")]
    public void Reload()
    {
        if (!Utils.IsWindows() || _config is null)
        {
            return;
        }

        _engine?.ClearAll();
        Register();
    }

    public void Dispose()
    {
        if (!Utils.IsWindows())
        {
            return;
        }

        _engine?.Dispose();
        _engine = null;
    }

    [SupportedOSPlatform("windows")]
    private void Register()
    {
        if (_config?.GlobalHotkeys.Any(t => t.KeyCode > 0) != true)
        {
            return;
        }

        if (_engine is null)
        {
            _engine = new Win32GlobalHotkeyEngine();
            _engine.HotkeyPressed += OnHotkeyPressed;
        }

        _hotkeyTriggerDic.Clear();

        var nextId = 1;
        foreach (var item in _config.GlobalHotkeys)
        {
            if (item.KeyCode is null or 0)
            {
                continue;
            }

            var vKey = (uint)KeyInterop.VirtualKeyFromKey((Key)item.KeyCode);
            var modifiers = Win32GlobalHotkeyEngine.Win32Modifiers.None;
            if (item.Control)
            {
                modifiers |= Win32GlobalHotkeyEngine.Win32Modifiers.Control;
            }
            if (item.Shift)
            {
                modifiers |= Win32GlobalHotkeyEngine.Win32Modifiers.Shift;
            }
            if (item.Alt)
            {
                modifiers |= Win32GlobalHotkeyEngine.Win32Modifiers.Alt;
            }

            var id = nextId++;
            if (_engine.Register(id, (uint)modifiers, vKey))
            {
                _hotkeyTriggerDic[id] = item.EGlobalHotkey;
            }
        }
    }

    private void OnHotkeyPressed(int id)
    {
        if (_updateFunc is null || IsPause)
        {
            return;
        }

        if (_hotkeyTriggerDic.TryGetValue(id, out var value))
        {
            _updateFunc.Invoke(value);
        }
    }
}
