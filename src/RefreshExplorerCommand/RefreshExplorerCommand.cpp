#include "RefreshExplorerCommand.h"

#include <pathcch.h>
#include <strsafe.h>

#include <atomic>
#include <string>
#include <vector>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "pathcch.lib")
#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "shlwapi.lib")

namespace
{
    constexpr wchar_t kCommandTitle[] = L"Refresh";
    constexpr wchar_t kCommandToolTip[] = L"Refresh the current Explorer folder";
    constexpr wchar_t kHostFileName[] = L"RefreshExplorerHost.exe";
}

const CLSID CLSID_RefreshExplorerCommand =
{ 0x85a6b89c, 0x5e78, 0x4d14, { 0x8a, 0x4f, 0x4b, 0x87, 0xe1, 0xf4, 0x06, 0x31 } };

namespace
{
    HRESULT DuplicateCoTaskMemString(PCWSTR source, PWSTR* destination)
    {
        if (!destination)
        {
            return E_POINTER;
        }

        *destination = nullptr;

        const size_t length = wcslen(source) + 1;
        const size_t bytes = length * sizeof(wchar_t);
        auto* buffer = static_cast<PWSTR>(CoTaskMemAlloc(bytes));
        if (!buffer)
        {
            return E_OUTOFMEMORY;
        }

        HRESULT hr = StringCchCopyW(buffer, length, source);
        if (FAILED(hr))
        {
            CoTaskMemFree(buffer);
            return hr;
        }

        *destination = buffer;
        return S_OK;
    }

    HRESULT GetModuleDirectory(std::wstring& directory)
    {
        wchar_t modulePath[MAX_PATH];
        DWORD written = GetModuleFileNameW(g_moduleHandle, modulePath, ARRAYSIZE(modulePath));
        if (written == 0 || written == ARRAYSIZE(modulePath))
        {
            return HRESULT_FROM_WIN32(GetLastError());
        }

        HRESULT hr = PathCchRemoveFileSpec(modulePath, ARRAYSIZE(modulePath));
        if (FAILED(hr))
        {
            return hr;
        }

        directory.assign(modulePath);
        return S_OK;
    }

    HRESULT LaunchRefreshHost()
    {
        std::wstring directory;
        HRESULT hr = GetModuleDirectory(directory);
        if (FAILED(hr))
        {
            return hr;
        }

        wchar_t hostPath[MAX_PATH];
        hr = PathCchCombine(hostPath, ARRAYSIZE(hostPath), directory.c_str(), kHostFileName);
        if (FAILED(hr))
        {
            return hr;
        }

        std::wstring commandLine = L"\"";
        commandLine += hostPath;
        commandLine += L"\" --refresh-active-explorer";
        std::vector<wchar_t> commandLineBuffer(commandLine.begin(), commandLine.end());
        commandLineBuffer.push_back(L'\0');

        STARTUPINFOW startupInfo{};
        startupInfo.cb = sizeof(startupInfo);
        startupInfo.dwFlags = STARTF_USESHOWWINDOW;
        startupInfo.wShowWindow = SW_HIDE;

        PROCESS_INFORMATION processInformation{};
        if (!CreateProcessW(
                hostPath,
                commandLineBuffer.data(),
                nullptr,
                nullptr,
                FALSE,
                0,
                nullptr,
                directory.c_str(),
                &startupInfo,
                &processInformation))
        {
            return HRESULT_FROM_WIN32(GetLastError());
        }

        CloseHandle(processInformation.hThread);
        CloseHandle(processInformation.hProcess);
        return S_OK;
    }

    class RefreshExplorerCommand final : public IExplorerCommand
    {
    public:
        RefreshExplorerCommand() noexcept : referenceCount_(1) {}

        IFACEMETHODIMP QueryInterface(REFIID riid, void** object) override
        {
            if (!object)
            {
                return E_POINTER;
            }

            *object = nullptr;

            if (riid == IID_IUnknown || riid == IID_IExplorerCommand)
            {
                *object = static_cast<IExplorerCommand*>(this);
                AddRef();
                return S_OK;
            }

            return E_NOINTERFACE;
        }

        IFACEMETHODIMP_(ULONG) AddRef() override
        {
            return static_cast<ULONG>(++referenceCount_);
        }

        IFACEMETHODIMP_(ULONG) Release() override
        {
            ULONG count = static_cast<ULONG>(--referenceCount_);
            if (count == 0)
            {
                delete this;
            }

            return count;
        }

        IFACEMETHODIMP GetTitle(IShellItemArray*, PWSTR* name) override
        {
            return DuplicateCoTaskMemString(kCommandTitle, name);
        }

        IFACEMETHODIMP GetIcon(IShellItemArray*, PWSTR* iconPath) override
        {
            if (iconPath)
            {
                *iconPath = nullptr;
            }

            return E_NOTIMPL;
        }

        IFACEMETHODIMP GetToolTip(IShellItemArray*, PWSTR* infoTip) override
        {
            return DuplicateCoTaskMemString(kCommandToolTip, infoTip);
        }

        IFACEMETHODIMP GetCanonicalName(GUID* commandName) override
        {
            if (!commandName)
            {
                return E_POINTER;
            }

            *commandName = CLSID_RefreshExplorerCommand;
            return S_OK;
        }

        IFACEMETHODIMP GetState(IShellItemArray*, BOOL, EXPCMDSTATE* commandState) override
        {
            if (!commandState)
            {
                return E_POINTER;
            }

            *commandState = ECS_ENABLED;
            return S_OK;
        }

        IFACEMETHODIMP Invoke(IShellItemArray*, IBindCtx*) override
        {
            return LaunchRefreshHost();
        }

        IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override
        {
            if (!flags)
            {
                return E_POINTER;
            }

            *flags = ECF_DEFAULT;
            return S_OK;
        }

        IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** enumerator) override
        {
            if (enumerator)
            {
                *enumerator = nullptr;
            }

            return E_NOTIMPL;
        }

    private:
        std::atomic<ULONG> referenceCount_;
    };

    class RefreshExplorerCommandClassFactory final : public IClassFactory
    {
    public:
        RefreshExplorerCommandClassFactory() noexcept : referenceCount_(1) {}

        IFACEMETHODIMP QueryInterface(REFIID riid, void** object) override
        {
            if (!object)
            {
                return E_POINTER;
            }

            *object = nullptr;

            if (riid == IID_IUnknown || riid == IID_IClassFactory)
            {
                *object = static_cast<IClassFactory*>(this);
                AddRef();
                return S_OK;
            }

            return E_NOINTERFACE;
        }

        IFACEMETHODIMP_(ULONG) AddRef() override
        {
            return static_cast<ULONG>(++referenceCount_);
        }

        IFACEMETHODIMP_(ULONG) Release() override
        {
            ULONG count = static_cast<ULONG>(--referenceCount_);
            if (count == 0)
            {
                delete this;
            }

            return count;
        }

        IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** object) override
        {
            if (outer)
            {
                return CLASS_E_NOAGGREGATION;
            }

            auto* command = new (std::nothrow) RefreshExplorerCommand();
            if (!command)
            {
                return E_OUTOFMEMORY;
            }

            HRESULT hr = command->QueryInterface(riid, object);
            command->Release();
            return hr;
        }

        IFACEMETHODIMP LockServer(BOOL) override
        {
            return S_OK;
        }

    private:
        std::atomic<ULONG> referenceCount_;
    };
}

extern "C" HRESULT __stdcall DllCanUnloadNow()
{
    return S_FALSE;
}

extern "C" HRESULT __stdcall DllGetClassObject(REFCLSID clsid, REFIID riid, LPVOID* object)
{
    if (clsid != CLSID_RefreshExplorerCommand)
    {
        return CLASS_E_CLASSNOTAVAILABLE;
    }

    auto* classFactory = new (std::nothrow) RefreshExplorerCommandClassFactory();
    if (!classFactory)
    {
        return E_OUTOFMEMORY;
    }

    HRESULT hr = classFactory->QueryInterface(riid, object);
    classFactory->Release();
    return hr;
}

