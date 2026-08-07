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

:: Initialize counter for successful releases
set "SUCCESS_COUNT=0"

echo %C_CYAN%===================================================%C_RESET%
echo %C_GREEN%SMART ZIP RELEASE SYNC%C_RESET%
echo %C_GRAY%Root directory:%C_RESET% %ROOT_DIR%
echo %C_GRAY%Binaries directory:%C_RESET% %ROOT_DIR%\_bin
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

:: Get GitHub asset size without downloading
set "REMOTE_SIZE="
for /f "usebackq delims=" %%S in (`gh release view v1.0.0 -R "magicon-top/%REPO_NAME%" --json assets -q ".assets[0].size" 2^>nul`) do set "REMOTE_SIZE=%%S"

if "%REMOTE_SIZE%"=="" set "REMOTE_SIZE=null"

if "%REMOTE_SIZE%"=="null" (
    echo    %C_YELLOW%[*] Archive not found on GitHub. Needs upload.%C_RESET%
    goto :upload_release
)

:: Compare file sizes
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
    powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; Compress-Archive -Path '%BIN_FOLDER%\*' -DestinationPath '%LOCAL_ZIP%' -Force" >nul 2>&1
    
    if not exist "%LOCAL_ZIP%" (
        echo    %C_RED%[ERROR] Failed to create zip archive.%C_RESET%
        goto :eof
    )
    goto :upload_release
)

echo    %C_CYAN%[-] Skip: %C_RED%"%REPO_NAME%"%C_CYAN% not found in _bin.%C_RESET%
goto :eof


:upload_release
echo    %C_GRAY%[*] Uploading %ZIP_NAME% to GitHub...%C_RESET%

:: Delete previous release (errors suppressed if it didn't exist)
gh release delete v1.0.0 -R "magicon-top/%REPO_NAME%" --yes > nul 2>&1

:: Create new release and attach the archive
gh release create v1.0.0 "%LOCAL_ZIP%" -R "magicon-top/%REPO_NAME%" --title "Release v1.0.0" --notes "Automated zipped build release" > nul 2>&1

if %errorlevel% equ 0 (
    echo    %C_GREEN%[SUCCESS]%C_RESET% Release %C_GREEN%%REPO_NAME%%C_RESET% successfully updated!
    set /a "SUCCESS_COUNT+=1"
) else (
    echo    %C_RED%[ERROR] Failed to update release for %REPO_NAME%.%C_RESET%
)
goto :eof