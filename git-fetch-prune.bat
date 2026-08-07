@echo off
cd /d "%~dp0"

echo Fixing git remote references across all repositories...
echo ========================================

for /d %%i in (*) do (
    if exist "%%i\.git" (
        echo [OK] Processing: %%i
        cd "%%i"
        
        REM Удаляем битые ссылки на удаленные ветки принудительно
        git remote prune origin >nul 2>&1
        if exist ".git\refs\remotes\origin" (
            del /s /q .git\refs\remotes\origin\* >nul 2>&1
        )
        
        REM Обновляем состояние заново
        git fetch --prune
        
        cd ..
    )
)

echo Done! All repositories fixed.
pause