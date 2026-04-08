#include "RefreshExplorerCommand.h"

HMODULE g_moduleHandle = nullptr;

BOOL APIENTRY DllMain(HMODULE moduleHandle, DWORD reason, LPVOID)
{
    if (reason == DLL_PROCESS_ATTACH)
    {
        g_moduleHandle = moduleHandle;
        DisableThreadLibraryCalls(moduleHandle);
    }

    return TRUE;
}

