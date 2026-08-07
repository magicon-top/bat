@echo off
chcp 65001 > nul

set "BAT_DIR=%~dp0"
pushd "%~dp0.."
set "PARENT_DIR=%CD%"
popd

echo ===================================================
echo WARNING: This script will PURGE ALL GIT HISTORY
echo (without deleting .git folder) for projects in:
echo %PARENT_DIR%
echo ===================================================
echo.
set /p "CONFIRM=Are you sure you want to continue? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Aborted by user.
    exit /b 0
)

echo.
for /d %%D in ("%PARENT_DIR%\*") do (
    call :process_folder "%%D" "%%~nxD"
)

echo.
echo ===================================================
echo Process finished for all repositories!
echo ===================================================
pause
goto :eof

:process_folder
set "FOLDER_PATH=%~1"
set "FOLDER_NAME=%~2"

echo Processing: %FOLDER_NAME% ...

cd /d "%FOLDER_PATH%"

:: Check if folder is a git repo
if not exist ".git" (
    echo   [-] Skipped (Not a git repository)
    cd /d "%BAT_DIR%"
    goto :eof
)

:: 1. Create a temporary orphan branch (branch without history)
git checkout --orphan temp_clean_branch > nul 2>&1

:: 2. Stage all current files
git add -A > nul 2>&1

:: 3. Create single clean commit
git commit -m "Initial commit" > nul 2>&1

:: 4. Delete main branch (or master) locally
git branch -D main > nul 2>&1
git branch -D master > nul 2>&1

:: 5. Rename temporary branch to main
git branch -m main > nul 2>&1

:: 6. Force push new clean branch history to GitHub
echo   [*] Force pushing clean history to GitHub...
git push -f origin main > nul 2>&1

if %errorlevel% equ 0 (
    echo   [SUCCESS] History purged successfully!
) else (
    echo   [ERROR] Failed to push to GitHub! Check remote access.
)

cd /d "%BAT_DIR%"
goto :eof