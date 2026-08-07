@echo off
chcp 65001 > nul
<<<<<<< HEAD


=======
::-------
>>>>>>> e95ea62 (refactor: simplify whitespace and add comment header in rename.bat)
if "%~1"=="" goto :usage
if "%~2"=="" goto :usage

set "OLD_NAME=%~1"
set "NEW_NAME=%~2"

:: Remember the path to the current script folder and the parent folder
set "BAT_DIR=%~dp0"
pushd "%~dp0.."
set "PARENT_DIR=%CD%"
popd

:: Check if the source folder exists
if not exist "%PARENT_DIR%\%OLD_NAME%" (
    echo [Error] Folder "%OLD_NAME%" not found in %PARENT_DIR%!
    exit /b 1
)

echo [1/3] Renaming repository on GitHub...
cd /d "%PARENT_DIR%\%OLD_NAME%"

:: Call gh repo rename
call gh repo rename "%NEW_NAME%" -y

:: Forcefully update git remote origin, ignoring gh warnings
call git remote set-url origin https://github.com/magicon-top/%NEW_NAME%.git
echo [Git] Remote repository URL updated.

echo [2/3] Exiting the directory and renaming on disk...
:: Make sure to return to the script folder to release the project folder lock
cd /d "%BAT_DIR%"
cd /d "%PARENT_DIR%"

ren "%OLD_NAME%" "%NEW_NAME%"

if %errorlevel% neq 0 (
    echo.
    echo [Error] Failed to rename the folder "%OLD_NAME%".
    echo Make sure it is not open in VS Code or another terminal!
    pause
    exit /b 1
)

echo.
echo [3/3] Success! Folder and repository renamed to "%NEW_NAME%".
goto :eof

:usage
echo Usage:
echo   rename.bat old_name new_name
echo Example:
echo   rename.bat go-test9 go-test10
pause