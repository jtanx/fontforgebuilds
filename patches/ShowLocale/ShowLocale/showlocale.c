#include <windows.h>
#include <stdlib.h>
#include <locale.h>

int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE hPrev, LPWSTR cmd, int nCmdShow) {
	//char lang[MAX_PATH];
	setlocale(LC_ALL, "");
	//(void)localeconv();
	//GetLocaleInfoA(LOCALE_USER_DEFAULT, LOCALE_SNAME, lang, MAX_PATH);
	//MessageBoxA(NULL, lang, "LC_ALL1", MB_OK);
	MessageBox(NULL, _wsetlocale(LC_CTYPE, NULL), L"LC_ALL", MB_OK);
	return 0;
}