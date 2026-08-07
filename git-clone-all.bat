@echo off
chcp 65001 > nul

:: Запоминаем путь к папке скрипта
set "BAT_DIR=%~dp0"

:: Переходим в родительскую папку на уровень выше
cd /d "%~dp0.."

for /f "tokens=*" %%i in ('gh repo list magicon-top --limit 1000 --json name --jq ".[].name"') do (
    :: Проверяем, существует ли уже папка с таким репозиторием
    if exist "%%i" (
        echo [Синхронизация] Восстановление файлов и подтягивание %%i...
        cd /d "%%i"
        
        :: 1. Отменяем локальные удаления/изменения и возвращаем файлы из последнего коммита
        git reset --hard > nul 2>&1
        
        :: 2. Забираем свежие изменения с GitHub
        git pull origin main > nul 2>&1
        if %errorlevel% neq 0 (
            git pull origin master > nul 2>&1
        )
        
        cd /d "%~dp0.."
    ) else (
        echo [Клонирование] Клонируем репозиторий: %%i...
        gh repo clone magicon-top/%%i %%i
    )
)

echo.
echo --- ALL REPOSITORIES UPDATED ^& RESTORED ---
pause