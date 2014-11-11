#include <Windows.h>
#include <stdio.h>
#include <Strsafe.h>
#define DEFAULT_XPORT 11

BOOL CALLBACK enumproc(HWND hwnd, LPARAM lp){
    DWORD* param = (DWORD*)lp;
    DWORD  pid =0;
    GetWindowThreadProcessId(hwnd, &pid);
    if(pid == param[0]){
        WCHAR name[16];
        if( GetClassName(hwnd, name, 16) > 0 ){
            //wprintf(L"E:'%s'\n",name); 
            if( wcscmp(name, L"vcxsrv/x X rl") == 0 ){
                //wprintf(L"F:%s\n", name);
                ++param[1];
            }
        }
    }
    return TRUE;
}

int wmain(int argc, WCHAR* argv[]){
    WCHAR buffer[BUFSIZ];
    WCHAR computername[BUFSIZ];
    WCHAR *xport = _wgetenv(L"FF_XPORT"), *ptr;
    DWORD computernamesize =  BUFSIZ;
    LONG port = DEFAULT_XPORT;
    
    if (!GetComputerNameEx(ComputerNameDnsHostname, computername, &computernamesize)){
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
    //fwprintf(stderr, L"Window name: %s\n", buffer);
    
    
    if(argc >= 2) {
        if (wcscmp(argv[1], L"-exists") == 0){
            //0 is OK (exists) for exit code; opposite of the 'boolean' true of 1.
            return FindWindowEx(NULL, NULL, L"VcXsrv/x", buffer) == NULL;
        } else if (wcscmp(argv[1], L"-close") == 0){
            // -close
            Sleep(500); //wait 0.5sec
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
        } else {
            Sleep(500);//wait 0.5sec
        }
    } else {
        Sleep(500);//wait 0.5sec
    }
    return 0;
}
//EOF
