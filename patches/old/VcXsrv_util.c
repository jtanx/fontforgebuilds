/**
 * Helper utility to determine the presence of a running VcXsrv server and to close it if
 * it is no longer in use.
 */
#include <stdio.h>
#include <Windows.h>
#include <Strsafe.h>
#define DEFAULT_XPORT 11

static BOOL CALLBACK enumproc(HWND hwnd, LPARAM lp) {
	DWORD* param = (DWORD*)lp;
	DWORD  pid = 0;

	GetWindowThreadProcessId(hwnd, &pid);
	if (pid == param[0]) {
		WCHAR name[16];
		if (GetClassName(hwnd, name, 16) > 0) {
			if (wcscmp(name, L"vcxsrv/x X rl") == 0) {
				param[1]++;
			}
		}
	}
	return TRUE;
}

int wmain(int argc, WCHAR* argv[]) {
	WCHAR buffer[BUFSIZ];
	WCHAR computername[BUFSIZ];
	WCHAR *xport = _wgetenv(L"FF_XPORT"), *ptr;
	DWORD computernamesize = BUFSIZ;
	LONG port = DEFAULT_XPORT;

	if (!GetComputerNameEx(ComputerNameDnsHostname, computername, &computernamesize)) {
		computername[0] = L'\0'; //ignore
	}

	//Check if environment variable for the X server port is set or not
	if (xport) {
		port = wcstol(xport, &ptr, 10);
		if (*ptr != L'\0' || port < 1 || port > 65535) {
			port = DEFAULT_XPORT;
		}
	}

	StringCchPrintf(buffer, BUFSIZ, L"VcXsrv Server - Display %s:%d.0",
		computername, port);

	if (argc >= 2) {
		if (wcscmp(argv[1], L"-exists") == 0) {
			//0 is OK (exists) for exit code; opposite of the 'boolean' true of 1.
			return FindWindowEx(NULL, NULL, L"VcXsrv/x", buffer) == NULL;
		} else if (wcscmp(argv[1], L"-close") == 0) {
			HWND hwnd = FindWindowEx(NULL, NULL, L"VcXsrv/x", buffer);
			if (hwnd){
				DWORD param[2] = { 0, 0 }; // param = {PID, numOfWindowsOpen}
				GetWindowThreadProcessId(hwnd, &param[0]);

				EnumWindows(enumproc, (LPARAM)param);
				if (param[1] == 0) {
					//No open windows; can close VcXsrv
					PostMessage(hwnd, WM_USER + 1002, 0, 0);
				}
			}
		}
	}
	Sleep(500); //Wait a while
	return 0;
}