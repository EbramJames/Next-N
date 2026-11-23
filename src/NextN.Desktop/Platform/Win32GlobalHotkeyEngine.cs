using System.Collections.Concurrent;
using System.Runtime.InteropServices;

namespace NextN.Desktop.Platform;

/// <summary>
/// Self-contained Win32 global hotkey engine running on a dedicated Win32 message thread.
/// Works reliably even when the main Avalonia window is hidden to the system tray.
/// </summary>
[SupportedOSPlatform("windows")]
internal sealed partial class Win32GlobalHotkeyEngine : IDisposable
{
    private const uint WmHotkey = 0x0312;
    private const uint WmApp = 0x8000;
    private const uint WmRegisterHotkey = WmApp + 1;
    private const uint WmClearHotkeys = WmApp + 2;
    private const uint WmQuit = 0x0012;

    private readonly ConcurrentQueue<(int Id, uint Modifiers, uint VirtualKey, TaskCompletionSource<bool> Result)> _pendingRegistrations = new();
    private readonly List<int> _registeredIds = [];
    private readonly ManualResetEventSlim _threadReady = new(false);
    private Thread? _messageThread;
    private uint _threadId;
    private volatile bool _disposed;

    public event Action<int>? HotkeyPressed;

    public Win32GlobalHotkeyEngine()
    {
        _messageThread = new Thread(MessageLoop)
        {
            Name = "NextN.Win32HotkeyLoop",
            IsBackground = true
        };
        _messageThread.Start();
        _threadReady.Wait(TimeSpan.FromSeconds(2));
    }

    public bool Register(int id, uint modifiers, uint virtualKey)
    {
        if (_disposed || _threadId == 0)
        {
            return false;
        }

        var tcs = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        _pendingRegistrations.Enqueue((id, modifiers, virtualKey, tcs));
        PostThreadMessage(_threadId, WmRegisterHotkey, 0, 0);

        return tcs.Task.Wait(TimeSpan.FromSeconds(2)) && tcs.Task.Result;
    }

    public void ClearAll()
    {
        if (_disposed || _threadId == 0)
        {
            return;
        }

        PostThreadMessage(_threadId, WmClearHotkeys, 0, 0);
    }

    private void MessageLoop()
    {
        _threadId = GetCurrentThreadId();
        // Force creation of the thread's Win32 message queue before signaling ready.
        PeekMessage(out _, nint.Zero, 0, 0, 0);
        _threadReady.Set();

        while (GetMessage(out var msg, nint.Zero, 0, 0) > 0)
        {
            switch (msg.Message)
            {
                case WmRegisterHotkey:
                    ProcessPendingRegistrations();
                    break;

                case WmClearHotkeys:
                    UnregisterAllInternal();
                    break;

                case WmHotkey:
                    HotkeyPressed?.Invoke((int)msg.WParam);
                    break;
            }
        }

        UnregisterAllInternal();
    }

    private void ProcessPendingRegistrations()
    {
        while (_pendingRegistrations.TryDequeue(out var req))
        {
            var ok = RegisterHotKey(nint.Zero, req.Id, req.Modifiers, req.VirtualKey);
            if (ok)
            {
                _registeredIds.Add(req.Id);
            }
            req.Result.TrySetResult(ok);
        }
    }

    private void UnregisterAllInternal()
    {
        foreach (var id in _registeredIds)
        {
            UnregisterHotKey(nint.Zero, id);
        }
        _registeredIds.Clear();
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        _disposed = true;
        if (_threadId != 0)
        {
            PostThreadMessage(_threadId, WmQuit, 0, 0);
        }
        _messageThread?.Join(TimeSpan.FromSeconds(1));
        _threadReady.Dispose();
    }

    [Flags]
    internal enum Win32Modifiers : uint
    {
        None = 0x0000,
        Alt = 0x0001,
        Control = 0x0002,
        Shift = 0x0004,
        Win = 0x0008,
        NoRepeat = 0x4000
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSG
    {
        public nint Hwnd;
        public uint Message;
        public nuint WParam;
        public nint LParam;
        public uint Time;
        public POINT Pt;
        public uint Private;
    }

    [LibraryImport("kernel32.dll")]
    private static partial uint GetCurrentThreadId();

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool RegisterHotKey(nint hWnd, int id, uint fsModifiers, uint vk);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool UnregisterHotKey(nint hWnd, int id);

    [LibraryImport("user32.dll", EntryPoint = "GetMessageW")]
    private static partial int GetMessage(out MSG lpMsg, nint hWnd, uint wMsgFilterMin, uint wMsgFilterMax);

    [LibraryImport("user32.dll", EntryPoint = "PeekMessageW")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool PeekMessage(out MSG lpMsg, nint hWnd, uint wMsgFilterMin, uint wMsgFilterMax, uint wRemoveMsg);

    [LibraryImport("user32.dll", EntryPoint = "PostThreadMessageW", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool PostThreadMessage(uint idThread, uint msg, nuint wParam, nint lParam);
}
