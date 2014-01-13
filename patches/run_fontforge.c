#include <windows.h>

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE hPrev, LPSTR lpCmdLine, int nCmdShow) { 
  // Define Variables
  char szAppPath[MAX_PATH] = "";
  char szAppDirectory[MAX_PATH] = "";
  char szBatPath[MAX_PATH] = "";
  
  // Get path of executable
  GetModuleFileName(NULL, szAppPath, MAX_PATH);
  
  // Extract directory
  strncpy(szAppDirectory, szAppPath, (int)(strrchr(szAppPath, (int) '\\') - szAppPath));
  szAppDirectory[strlen(szAppDirectory)] = '\0';
  
  // Append batch file to directory
  strcpy(szBatPath, szAppDirectory);
  strcat(szBatPath, "\\fontforge.bat");
  
  // Run batch file without visible window
  ShellExecute(HWND_DESKTOP, "open", szBatPath, lpCmdLine, NULL, SW_HIDE);
  return 0;
} 
