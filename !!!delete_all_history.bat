@echo off
chcp 65001 > nul


set "BAT_DIR=%~dp0"
pushd "%~dp0.."
set "PARENT_DIR=%CD%"
popd

echo ===================================================
echo SAFE PURGE: This script will sync latest files
echo from GitHub, then PURGE HISTORY to 1 clean commit
echo for projects in: %PARENT_DIR%
echo ===================================================
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
    echo    [-] Skipped (Not a git repository)
    cd /d "%BAT_DIR%"
    goto :eof
)

:: 1. Safety step: Fetch and pull missing remote files first
echo    [*] Pulling latest changes from GitHub to prevent file loss...
git pull origin main > nul 2>&1
if %errorlevel% neq 0 (
    git pull origin master > nul 2>&1
)

:: 2. Create a temporary orphan branch (branch without history)
git checkout --orphan temp_clean_branch > nul 2>&1

:: 3. Stage all current files (local + pulled)
git add -A > nul 2>&1

:: 4. Create single clean commit
git commit -m "Initial commit" > nul 2>&1

:: 5. Delete old local branches
git branch -D main > nul 2>&1
git branch -D master > nul 2>&1

:: 6. Rename temporary branch to main
git branch -m main > nul 2>&1

:: 7. Force push clean history back to GitHub
echo    [*] Force pushing clean single history to GitHub...
git push -f origin main > nul 2>&1

if %errorlevel% equ 0 (
    echo    [SUCCESS] Safely synced and history purged!
) else (
    echo    [ERROR] Failed to push to GitHub! Check remote access.
)

cd /d "%BAT_DIR%"
goto :eof