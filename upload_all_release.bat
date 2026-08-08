@echo off

:: Enable VT100/ANSI color support in Windows Console
for /f "tokens=3" %%a in ('reg query "HKCU\Console" /v VirtualTerminalLevel 2^>nul') do set "VT_LEVEL=%%a"
if not "%VT_LEVEL%"=="0x1" (
    reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul 2>&1
)

for /f %%a in ('echo prompt $E^|cmd') do set "ESC=%%a"
set "C_RESET=%ESC%[0m"
set "C_GREEN=%ESC%[92m"
set "C_CYAN=%ESC%[96m"
set "C_RED=%ESC%[91m"
set "C_YELLOW=%ESC%[93m"
set "C_GRAY=%ESC%[90m"

set "BAT_DIR=%~dp0"
pushd "%~dp0.."
set "ROOT_DIR=%CD%"
popd

:: 100% Reliable date parsing without PowerShell or WMIC
for /f "tokens=3" %%a in ('reg query "HKCU\Control Panel\International" /v sShortDate 2^>nul') do set "S_FMT=%%a"
for /f "tokens=1-3 delims=/.- " %%a in ("%date%") do (
    set "p1=%%a"
    set "p2=%%b"
    set "p3=%%c"
)

:: Detect Year (4 digits) and pad Month/Day safely
if "%p1:~3,1%" neq "" (
    set "YYYY=%p1%"
    set "MM=0%p2%"
    set "DD=0%p3%"
) else if "%p3:~3,1%" neq "" (
    set "YYYY=%p3%"
    if /i "%S_FMT:~0,1%"=="d" (
        set "DD=0%p1%"
        set "MM=0%p2%"
    ) else (
        set "MM=0%p1%"
        set "DD=0%p2%"
    )
)

:: Trim to last 2 digits ensuring proper zero padding (08 remains 08)
set "MM=%MM:~-2%"
set "DD=%DD:~-2%"

set "TODAY=%YYYY%.%MM%.%DD%"
set "TAG_NAME=v%TODAY%"

:: Initialize counter for successful releases
set "SUCCESS_COUNT=0"

echo %C_CYAN%===================================================%C_RESET%
echo %C_GREEN%SMART ZIP RELEASE SYNC%C_RESET%
echo %C_GRAY%Root directory:%C_RESET% %ROOT_DIR%
echo %C_GRAY%Binaries directory:%C_RESET% %ROOT_DIR%\_bin
echo %C_GRAY%Target Release Tag:%C_RESET% %C_YELLOW%%TAG_NAME%%C_RESET%
echo %C_CYAN%===================================================%C_RESET%
echo.

if not exist "%ROOT_DIR%\_bin" (
    echo %C_RED%[ERROR] Folder "%ROOT_DIR%\_bin" does not exist!%C_RESET%
    pause
    exit /b 1
)

for /d %%D in ("%ROOT_DIR%\*") do (
    call :process_repo "%%D" "%%~nxD"
)

echo.
echo %C_CYAN%===================================================%C_RESET%
echo %C_GREEN%ALL RELEASES PROCESSED!%C_RESET%
echo %C_GRAY%Successfully uploaded/updated: %C_GREEN%%SUCCESS_COUNT%%C_RESET%
echo %C_CYAN%===================================================%C_RESET%
pause
goto :eof


:process_repo
set "REPO_PATH=%~1"
set "REPO_NAME=%~2"

if /i "%REPO_NAME%"=="_bin" goto :eof
if not exist "%REPO_PATH%\.git" goto :eof

echo %C_GRAY%---------------------------------------------------%C_RESET%
echo %C_YELLOW% %REPO_NAME% %C_RESET%... 

set "BIN_FOLDER=%ROOT_DIR%\_bin\%REPO_NAME%"
set "LOCAL_ZIP=%ROOT_DIR%\_bin\%REPO_NAME%.zip"
set "ZIP_NAME=%REPO_NAME%.zip"

:: 1. Check for local archive
if exist "%LOCAL_ZIP%" goto :check_existing_zip

:: 2. If no archive exists, check for folder
goto :check_folder


:check_existing_zip
echo    %C_GRAY%[*] Found existing archive: %ZIP_NAME%%C_RESET%
:: Get local file size
for %%I in ("%LOCAL_ZIP%") do set "LOCAL_SIZE=%%~zI"

:: Get GitHub asset size from latest release without downloading
set "REMOTE_SIZE="
for /f "usebackq delims=" %%S in (`gh release view --repo "magicon-top/%REPO_NAME%" --json assets -q ".assets[0].size" 2^>nul`) do set "REMOTE_SIZE=%%S"

if "%REMOTE_SIZE%"=="" set "REMOTE_SIZE=null"

if "%REMOTE_SIZE%"=="null" (
    echo    %C_YELLOW%[*] Archive not found on GitHub. Needs upload.%C_RESET%
    goto :upload_release
)

:: Compare file sizes (If identical, skip completely without touching remote releases)
if "%LOCAL_SIZE%"=="%REMOTE_SIZE%" (
    echo    %C_CYAN%[-] Skip: Archive size matches GitHub ^(%LOCAL_SIZE% bytes^).%C_RESET%
    goto :eof
)

echo    %C_YELLOW%[*] Sizes differ ^(Local: %LOCAL_SIZE%, Remote: %REMOTE_SIZE%^). Needs update.%C_RESET%
goto :upload_release


:check_folder
if exist "%BIN_FOLDER%\" (
    :: Check if directory is not empty
    dir /b /s /a-d "%BIN_FOLDER%\*" >nul 2>&1
    if errorlevel 1 (
        echo    %C_CYAN%[-] Skip: No files found inside "%BIN_FOLDER%".%C_RESET%
        goto :eof
    )
    
    echo    %C_GRAY%[*] Folder "%REPO_NAME%" found. Packing into archive...%C_RESET%
    tar -a -c -f "%LOCAL_ZIP%" -C "%BIN_FOLDER%" . >nul 2>&1
    
    if not exist "%LOCAL_ZIP%" (
        echo    %C_RED%[ERROR] Failed to create zip archive.%C_RESET%
        goto :eof
    )
    goto :upload_release
)

echo    %C_CYAN%[-] Skip: %C_RED%"%REPO_NAME%"%C_CYAN% not found in _bin.%C_RESET%
goto :eof


:upload_release
echo    %C_GRAY%[*] Cleaning up old releases and uploading %ZIP_NAME% as %TAG_NAME%...%C_RESET%

:: Delete previous releases and tags before creating the new one
for /f "usebackq delims=" %%R in (`gh release list -R "magicon-top/%REPO_NAME%" --limit 100 --json tagName -q ".[].tagName" 2^>nul`) do (
    gh release delete "%%R" -R "magicon-top/%REPO_NAME%" --yes > nul 2>&1
    git -C "%REPO_PATH%" push --delete origin "%%R" > nul 2>&1
)

:: Create fresh release and upload zip
gh release create "%TAG_NAME%" "%LOCAL_ZIP%" -R "magicon-top/%REPO_NAME%" --title "Release %TAG_NAME%" --notes "Automated zipped build release (%TAG_NAME%)" 
::> nul 2>&1

if %errorlevel% equ 0 (
    echo    %C_GREEN%[SUCCESS]%C_RESET% Release %C_GREEN%%REPO_NAME%%C_RESET% %TAG_NAME% successfully updated.
    set /a "SUCCESS_COUNT+=1"
) else (
    echo    %C_RED%[ERROR] Failed to update release for %REPO_NAME%.%C_RESET%
)
goto :eof