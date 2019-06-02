#include <windows.h>
#include <stdio.h>
#include <strsafe.h>
#include <stdlib.h>
#include <locale.h>

/*
 * Retrieves a list of locale names as returned by setlocale(LC_ALL, "")
 * In the form <language>_<country>.<codepage>
 */
BOOL CALLBACK LocaleProc(LPWSTR name, DWORD dwFlags, LPARAM lParam) {
	if (*name) {
		wchar_t lang[MAX_PATH], region[MAX_PATH], together[MAX_PATH];
		DWORD cp;
		GetLocaleInfoEx(name, LOCALE_SENGLISHLANGUAGENAME, lang, MAX_PATH);
		GetLocaleInfoEx(name, LOCALE_SENGLISHCOUNTRYNAME, region, MAX_PATH);
		GetLocaleInfoEx(name, LOCALE_RETURN_NUMBER | LOCALE_IDEFAULTANSICODEPAGE, (void*)&cp, sizeof(cp));
		StringCchPrintf(together, MAX_PATH, L"%s_%s.%d", lang, region, cp);
		_wsetlocale(LC_ALL, together);
		wchar_t *ptr = _wsetlocale(LC_CTYPE, NULL);
		if (wcscmp(L"C", ptr)) {
			fputws(ptr, (FILE*)lParam);
			fputws(L" ", (FILE*)lParam);
			fputws(name, (FILE*)lParam);
			fputws(L"\n", (FILE*)lParam);
		}
		_wsetlocale(LC_ALL, L"C");
		return TRUE;
	}
	return TRUE;
}

int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE hPrev, LPWSTR cmd, int nCmdShow) {
	FILE *fp;

	if (*cmd == L'\0') {
		cmd = L"localelist.txt";
	}

	if (_wfopen_s(&fp, cmd, L"w")) {
		MessageBox(NULL, L"Could not open specified file", NULL, MB_OK);
		return 1;
	}
	EnumSystemLocalesEx(LocaleProc, LOCALE_ALL, (LPARAM)fp, 0);
	fclose(fp);

	//Displays the current locale
	setlocale(LC_ALL, "");
	MessageBox(NULL, _wsetlocale(LC_CTYPE, NULL), L"LC_ALL", MB_OK);
	return 0;
}