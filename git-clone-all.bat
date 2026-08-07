@echo off
chcp 65001 > nul

:: Переходим в родительскую папку на уровень выше
cd /d "%~dp0.."

for /f "tokens=*" %%i in ('gh repo list magicon-top --limit 1000 --json name --jq ".[].name"') do (
    :: Проверяем, существует ли уже папка с таким репозиторием
    if exist "%%i" (
        echo [Пропущено] Папка "%%i" уже существует.
    ) else (
        echo Клонируем репозиторий: %%i...
        gh repo clone magicon-top/%%i %%i
    )
)
echo --- DONE ---
pause