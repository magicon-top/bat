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

if not exist "%BIN_FOLDER%" (
    echo    %C_CYAN%[-] Skip: Binaries folder "%BIN_FOLDER%" %C_RED%not found.%C_RESET%
    goto :eof
)

dir /b /s /a-d "%BIN_FOLDER%\*" >nul 2>&1
if %errorlevel% neq 0 (
    echo    %C_CYAN%[-] Skip: No files found inside "%BIN_FOLDER%".%C_RESET%
    goto :eof
)

echo    %C_GRAY%[*] Found binaries in: %BIN_FOLDER%%C_RESET%

set "TEMP_WORK_DIR=%BAT_DIR%_temp_sync"
if exist "%TEMP_WORK_DIR%" rd /s /q "%TEMP_WORK_DIR%" >nul 2>&1
mkdir "%TEMP_WORK_DIR%" >nul 2>&1
mkdir "%TEMP_WORK_DIR%\remote_files" >nul 2>&1

set "NEEDS_UPDATE=0"
set "ZIP_NAME=%REPO_NAME%.zip"

:: 1. Download the OLD archive (if it exists) for comparison
gh release download v1.0.0 -R "magicon-top/%REPO_NAME%" -p "%ZIP_NAME%" -D "%TEMP_WORK_DIR%" --clobber >nul 2>&1
if %errorlevel% neq 0 (
    echo    %C_YELLOW%[*] Release or zip does not exist on GitHub yet.%C_RESET%
    set "NEEDS_UPDATE=1"
) else (
    :: 2. Extract the downloaded archive to compare files inside (progress bar hidden)
    powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; Expand-Archive -Path '%TEMP_WORK_DIR%\%ZIP_NAME%' -DestinationPath '%TEMP_WORK_DIR%\remote_files' -Force" >nul 2>&1
    
    :: 3. Reliable PowerShell file hash check (recursive, handles subfolders, avoids cmd.exe bugs)
    powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; $l=Get-ChildItem -Path '%BIN_FOLDER%' -File -Recurse; $r=Get-ChildItem -Path '%TEMP_WORK_DIR%\remote_files' -File -Recurse; if($l.Count -ne $r.Count){exit 1}; foreach($f in $l){ $rel=$f.FullName.Substring('%BIN_FOLDER%'.Length + 1); $rp=Join-Path '%TEMP_WORK_DIR%\remote_files' $rel; if(!(Test-Path $rp)){exit 1}; if((Get-FileHash $f.FullName).Hash -ne (Get-FileHash $rp).Hash){exit 1} }; exit 0"
    if errorlevel 1 set "NEEDS_UPDATE=1"
)

if "%NEEDS_UPDATE%"=="0" (
    echo    %C_CYAN%[-] Skip: Local files are identical to GitHub release.%C_RESET%
    rd /s /q "%TEMP_WORK_DIR%" >nul 2>&1
    goto :eof
)

echo    %C_YELLOW%[*] Files differ. Packing into %ZIP_NAME% and uploading...%C_RESET%

:: 4. Pack the new version into a fresh ZIP (progress bar hidden)
set "LOCAL_ZIP=%TEMP_WORK_DIR%\%ZIP_NAME%"
powershell -NoProfile -Command "$ProgressPreference = 'SilentlyContinue'; Compress-Archive -Path '%BIN_FOLDER%\*' -DestinationPath '%LOCAL_ZIP%' -Force" >nul 2>&1

:: 5. Delete the old release
gh release delete v1.0.0 -R "magicon-top/%REPO_NAME%" --yes > nul 2>&1

:: 6. Create a new release and attach ONLY ONE zip archive
gh release create v1.0.0 "%LOCAL_ZIP%" -R "magicon-top/%REPO_NAME%" --title "Release v1.0.0" --notes "Automated zipped build release" > nul 2>&1

if %errorlevel% equ 0 (
    echo    %C_GREEN%[SUCCESS] Release v1.0.0 successfully updated!%C_RESET%
) else (
    echo    %C_RED%[ERROR] Failed to update release for %REPO_NAME%.%C_RESET%
)

:: Cleanup
rd /s /q "%TEMP_WORK_DIR%" >nul 2>&1
goto :eof