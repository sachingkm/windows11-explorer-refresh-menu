#include <windows.h>

#include <shellapi.h>

#pragma comment(lib, "user32.lib")

namespace
{
    constexpr wchar_t kRefreshArgument[] = L"--refresh-active-explorer";

    bool IsExplorerWindow(HWND windowHandle)
    {
        if (!windowHandle)
        {
            return false;
        }

        wchar_t className[64];
        if (GetClassNameW(windowHandle, className, ARRAYSIZE(className)) == 0)
        {
            return false;
        }

        return wcscmp(className, L"CabinetWClass") == 0 ||
               wcscmp(className, L"ExploreWClass") == 0;
    }

    HWND WaitForExplorerForegroundWindow()
    {
        for (int attempt = 0; attempt < 30; ++attempt)
        {
            HWND foreground = GetForegroundWindow();
            HWND topLevel = foreground ? GetAncestor(foreground, GA_ROOT) : nullptr;
            if (IsExplorerWindow(topLevel))
            {
                return topLevel;
            }

            Sleep(100);
        }

        return nullptr;
    }

    DWORD SendExplorerRefresh()
    {
        HWND explorerWindow = WaitForExplorerForegroundWindow();
        if (!explorerWindow)
        {
            return ERROR_NOT_FOUND;
        }

        SetForegroundWindow(explorerWindow);
        Sleep(50);

        INPUT inputs[2]{};
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].ki.wVk = VK_F5;
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].ki.wVk = VK_F5;
        inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;

        UINT sent = SendInput(ARRAYSIZE(inputs), inputs, sizeof(INPUT));
        return sent == ARRAYSIZE(inputs) ? ERROR_SUCCESS : GetLastError();
    }
}

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    int argumentCount = 0;
    LPWSTR* arguments = CommandLineToArgvW(GetCommandLineW(), &argumentCount);
    if (!arguments)
    {
        return static_cast<int>(GetLastError());
    }

    bool shouldRefresh = false;
    for (int index = 1; index < argumentCount; ++index)
    {
        if (wcscmp(arguments[index], kRefreshArgument) == 0)
        {
            shouldRefresh = true;
            break;
        }
    }

    LocalFree(arguments);

    if (!shouldRefresh)
    {
        return 0;
    }

    return static_cast<int>(SendExplorerRefresh());
}

