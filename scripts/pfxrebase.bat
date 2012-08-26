C:

REM "Note: The following variables must be customized for your system"
set CYGBINDIR_WIN=C:\cygwin\bin
set CYGBINDIR=/bin
set PFXDIR=/g2pfx
set OVERLAYDIR=/g2pfx/overlay

set DEBUG_REBASEALL_PFX=1

cd %CYGBINDIR_WIN%

REM "%CYGBINDIR_WIN%\ash.exe" -c "PATH=%CYGBINDIR% %CYGBINDIR%/rebaseall"
"%CYGBINDIR_WIN%\ash.exe" -c "PATH=%CYGBINDIR% %OVERLAYDIR%/scripts/rebaseall_pfx -P %PFXDIR%"
"%CYGBINDIR_WIN%\ash.exe" -c "PATH=%CYGBINDIR% %OVERLAYDIR%/scripts/peflagsall_pfx -P %PFXDIR%"

pause
