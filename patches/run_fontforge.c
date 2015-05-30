#include <windows.h>
#include <Strsafe.h>

int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE hPrev, PWSTR lpCmdLine, int nCmdShow) { 
	// Define Variables
	wchar_t wszAppPath[MAX_PATH];
	wchar_t wszBatPath[MAX_PATH];
	wchar_t *pwszTail;
	DWORD dwRet;
  
	// Get path of executable
	dwRet = GetModuleFileName(NULL, wszAppPath, MAX_PATH);
	if (dwRet == 0 || dwRet >= MAX_PATH) {
		MessageBox(NULL, L"Path too long - place FontForge in another directory.",
			NULL, MB_OK | MB_ICONEXCLAMATION);
		return 1;
	} else if ((pwszTail = wcsrchr(wszAppPath, L'\\')) == NULL) {
		MessageBox(NULL, L"Could not determine executable location.",
			NULL, MB_OK | MB_ICONEXCLAMATION);
		return 1;
	}
	
	//Construct the file location
	*pwszTail = L'\0';
	dwRet = StringCchPrintf(wszBatPath, MAX_PATH, L"%s\\fontforge.bat", wszAppPath);
	if (FAILED(dwRet)) {
		MessageBox(NULL, L"Could not determine executable location.",
			NULL, MB_OK | MB_ICONEXCLAMATION);
		return 1;
	}
  
	// Run batch file without visible window
	dwRet = (int)ShellExecute(HWND_DESKTOP, L"open", wszBatPath, lpCmdLine, NULL, SW_HIDE);
	if (dwRet < 32) {
		MessageBox(NULL, L"Could not launch FontForge.", NULL, MB_OK | MB_ICONEXCLAMATION);
		return 1;
	}
	return 0;
}
