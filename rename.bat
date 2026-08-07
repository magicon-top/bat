@echo off
chcp 65001 > nul

if "%~1"=="" goto :usage
if "%~2"=="" goto :usage

set "OLD_NAME=%~1"
set "NEW_NAME=%~2"

:: Запоминаем путь к папке go-bat и к родительской папке
set "BAT_DIR=%~dp0"
pushd "%~dp0.."
set "PARENT_DIR=%CD%"
popd

:: Проверяем существование исходной папки
if not exist "%PARENT_DIR%\%OLD_NAME%" (
    echo [Ошибка] Папка "%OLD_NAME%" не найдена в %PARENT_DIR%!
    exit /b 1
)

echo [1/3] Переименование репозитория на GitHub...
cd /d "%PARENT_DIR%\%OLD_NAME%"

:: Вызываем gh repo rename
call gh repo rename "%NEW_NAME%" -y

:: Принудительно обновляем git remote origin, игнорируя ворнинги gh
call git remote set-url origin https://github.com/magicon-top/%NEW_NAME%.git
echo [Git] URL удаленного репозитория обновлен.

echo [2/3] Выход из папки и переименование на диске...
:: Обязательно возвращаемся в папку go-bat, чтобы освободить папку проекта
cd /d "%BAT_DIR%"
cd /d "%PARENT_DIR%"

ren "%OLD_NAME%" "%NEW_NAME%"

if %errorlevel% neq 0 (
    echo.
    echo [Ошибка] Не удалось переименовать папку "%OLD_NAME%".
    echo Убедитесь, что она не открыта в VS Code или другом терминале!
    pause
    exit /b 1
)

echo.
echo [3/3] Успешно! Папка и репозиторий переименованы в "%NEW_NAME%".
goto :eof

:usage
echo Использование:
echo   rename.bat старое_имя новое_имя
echo Пример:
echo   rename.bat go-test9 go-test10
pause