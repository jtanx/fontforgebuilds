#include <Windows.h>
#include <stdio.h>
#include <Strsafe.h>

BOOL CALLBACK enumproc(HWND hwnd, LPARAM lp){
	DWORD* param = (DWORD*)lp;
	DWORD  pid =0;
	GetWindowThreadProcessId(hwnd, &pid);
	if(pid == param[0]){
		WCHAR name[16];
		if( GetClassName(hwnd, name, 12) > 0 ){
			if( wcscmp(name, L"vcxsrv/x X r1") == 0 ){
				++param[1];
			}
		}
	}
	return TRUE;
}

int wmain(int argc, WCHAR* argv[]){

	Sleep(500); //wait 0.5sec

	if(argc >= 2 && wcscmp(argv[1], L"-wait") == 0){
		//
	}
	else{
		// -close
		WCHAR buffer[BUFSIZ];
		WCHAR computername[BUFSIZ];
		DWORD computernamesize =  BUFSIZ;
		if (!GetComputerNameEx(ComputerNameDnsHostname, computername, &computernamesize)){
			computername[0] = L'\0'; //ignore
		}
		
		StringCchPrintf(buffer, BUFSIZ, L"VcXsrv Server - Display %s:9.0", computername);
		//fwprintf(stderr, L"Window name: %s\n", buffer);
		
		HWND hwnd = FindWindowEx(NULL, NULL, L"VcXsrv/x", buffer);
		if(hwnd){
			DWORD param[2] = {0,0};
			GetWindowThreadProcessId(hwnd, &param[0]);

			//fprintf(stderr, "[Xming] hwnd=%p, pid=%ld, ", hwnd, param[0]);

			EnumWindows(enumproc, (LPARAM)param);

			//fprintf(stderr, "num of window=%ld\n", param[1]);

			if(param[1] == 0){
				PostMessage(hwnd, WM_USER+1002, 0,0);

				Sleep(500);//wait 0.5sec
			}
		}
	}
	return 0;
}
//EOF
