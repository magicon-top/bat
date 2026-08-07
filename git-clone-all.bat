@echo off
:: gh clone-org magicon-top
chcp 65001 > nul
for /f "tokens=*" %%i in ('gh repo list magicon-top --limit 1000 --json name --jq ".[].name"') do (
    echo Клонируем репозиторий: %%i...
    gh repo clone magicon-top/%%i %%i
)
pause