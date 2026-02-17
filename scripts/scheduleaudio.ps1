# scheduleaudio.ps1
# Made by @MihneaMoso
# Copyright © 2026 Mihnea Moso

param(
    [switch]$RunScheduled,             # Internal flag: used when run by Task Scheduler
    [string]$Url = "https://mososcripts.vercel.app/assets/ReelAudio-58870.wav/",
    [string]$OutPath = "$env:TEMP\alarm.wav",
    [int]$DelayMinutes = 10
)

# 0.  Self-elevate execution-policy for THIS process only
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force -ErrorAction SilentlyContinue
$ErrorActionPreference = "Stop"

# -------------------------------------------------------------------
# 1) If not running as scheduled task, register the task and exit
# -------------------------------------------------------------------
if (-not $RunScheduled) {
    # Get absolute path to this script
    $scriptPath = $MyInvocation.MyCommand.Path

    if (-not (Test-Path $scriptPath)) {
        throw "Cannot determine script path."
    }

    $taskName = "AlarmScript_AutoTask"

    # Start time a few seconds from now (Task Scheduler requires HH:mm)
    $startTime = (Get-Date).AddSeconds(10).ToString('HH:mm')

    # Build the command that Task Scheduler will run (hidden window)
    $taskCommand = 'powershell.exe'
    $taskArgs = @(
        '-NoProfile',
        '-WindowStyle', 'Hidden',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$scriptPath`"",
        '-RunScheduled',
        '-Url', "`"$Url`"",
        '-OutPath', "`"$OutPath`"",
        '-DelayMinutes', $DelayMinutes
    ) -join ' '

    # Create or overwrite the task
    schtasks /create `
        /tn $taskName `
        /tr $taskArgs `
        /sc once `
        /st $startTime `
        /f | Out-Null

    # Optionally, start it immediately (so you do not wait for the next minute boundary)
    schtasks /run /tn $taskName | Out-Null

    # Done: everything else happens in the background via Task Scheduler
    Write-Host "Task '$taskName' registered and started in the background."
    return
}

# -------------------------------------------------------------------
# 2) Actual alarm logic (only runs when called with -RunScheduled)
# -------------------------------------------------------------------

# 2.1 Download the audio file
Invoke-WebRequest -Uri $Url -OutFile $OutPath

# 2.2 Load .NET APIs for audio playback
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Media

# 2.3 Load Core Audio APIs for master volume control
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

namespace Audio {
    [Flags]
    public enum CLSCTX : uint {
        INPROC_SERVER = 0x1,
        INPROC_HANDLER = 0x2,
        LOCAL_SERVER = 0x4,
        INPROC_SERVER16 = 0x8,
        REMOTE_SERVER = 0x10,
        INPROC_HANDLER16 = 0x20,
        RESERVED1 = 0x40,
        RESERVED2 = 0x80,
        RESERVED3 = 0x100,
        RESERVED4 = 0x200,
        NO_CODE_DOWNLOAD = 0x400,
        RESERVED5 = 0x800,
        NO_CUSTOM_MARSHAL = 0x1000,
        ENABLE_CODE_DOWNLOAD = 0x2000,
        NO_FAILURE_LOG = 0x4000,
        DISABLE_AAA = 0x8000,
        ENABLE_AAA = 0x10000,
        FROM_DEFAULT_CONTEXT = 0x20000,
        ACTIVATE_32_BIT_SERVER = 0x40000,
        ACTIVATE_64_BIT_SERVER = 0x80000,
        ENABLE_CLOAKING = 0x100000,
        APPCONTAINER = 0x400000,
        ACTIVATE_AAA_AS_IU = 0x800000,
        PS_DLL = 0x80000000,
        ALL = INPROC_SERVER | INPROC_HANDLER | LOCAL_SERVER
    }

    [Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumeratorCom { }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator {
        int NotImpl1();

        [PreserveSig]
        int GetDefaultAudioEndpoint(
            EDataFlow dataFlow,
            ERole role,
            out IMMDevice ppDevice);
    }

    public enum EDataFlow {
        eRender,
        eCapture,
        eAll,
        EDataFlow_enum_count
    }

    public enum ERole {
        eConsole,
        eMultimedia,
        eCommunications,
        ERole_enum_count
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice {
        [PreserveSig]
        int Activate(
            ref Guid iid,
            CLSCTX dwClsCtx,
            IntPtr pActivationParams,
            [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
    }

    [Guid("5CDF2C82-841E-4546-9722-0CF74078229A"),
     InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAudioEndpointVolume {
        void RegisterControlChangeNotify(IntPtr pNotify);
        void UnregisterControlChangeNotify(IntPtr pNotify);
        void GetChannelCount(out uint pnChannelCount);
        void SetMasterVolumeLevel(float fLevelDB, Guid pguidEventContext);
        void SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
        void GetMasterVolumeLevel(out float pfLevelDB);
        void GetMasterVolumeLevelScalar(out float pfLevel);
        void SetChannelVolumeLevel(uint nChannel, float fLevelDB, Guid pguidEventContext);
        void SetChannelVolumeLevelScalar(uint nChannel, float fLevel, Guid pguidEventContext);
        void GetChannelVolumeLevel(uint nChannel, out float pfLevelDB);
        void GetChannelVolumeLevelScalar(uint nChannel, out float pfLevel);
        void SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
        void GetMute(out bool pbMute);
        void GetVolumeStepInfo(out uint pnStep, out uint pnStepCount);
        void VolumeStepUp(Guid pguidEventContext);
        void VolumeStepDown(Guid pguidEventContext);
        void QueryHardwareSupport(out uint pdwHardwareSupportMask);
        void GetVolumeRange(out float pflVolumeMindB, out float pflVolumeMaxdB, out float pflVolumeIncrementdB);
    }

    public static class AudioManager {
        public static void SetMasterVolumeScalar(float level) {
            IMMDeviceEnumerator enumerator = (IMMDeviceEnumerator)Activator.CreateInstance(typeof(MMDeviceEnumeratorCom));
            IMMDevice device;
            int hr = enumerator.GetDefaultAudioEndpoint(EDataFlow.eRender, ERole.eMultimedia, out device);
            if (hr != 0) {
                Marshal.ThrowExceptionForHR(hr);
            }

            object obj;
            Guid iid = typeof(IAudioEndpointVolume).GUID;
            hr = device.Activate(ref iid, CLSCTX.ALL, IntPtr.Zero, out obj);
            if (hr != 0) {
                Marshal.ThrowExceptionForHR(hr);
            }

            IAudioEndpointVolume volume = (IAudioEndpointVolume)obj;
            volume.SetMasterVolumeLevelScalar(level, Guid.Empty);
        }
    }
}
"@

# 2.4 Wait the requested delay
# Start-Sleep -Minutes $DelayMinutes

# 2.5 Set system volume to 100%
[Audio.AudioManager]::SetMasterVolumeScalar(1.0)

# 2.6 Play the audio (blocking inside this hidden process)
$player = New-Object System.Media.SoundPlayer $OutPath
$player.PlaySync()

