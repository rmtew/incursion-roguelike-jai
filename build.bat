@echo off
setlocal enabledelayedexpansion

set JAI=C:\Data\R\jai\bin\jai.exe
set FAILED=0
set BUILT=0

if "%~1"=="" goto build_all

:parse_args
if "%~1"=="" goto done
call :build_%~1 2>nul
if errorlevel 1 (
    echo Unknown target: %~1
    echo.
    echo Usage: build.bat [target ...]
    echo Targets: game test headless dungeon_test dungeon_screenshot dungeon_verify inspect replay
    echo Default: builds all targets
    set FAILED=1
)
shift
goto parse_args

:build_all
call :build_game
call :build_test
call :build_headless
call :build_dungeon_test
call :build_dungeon_screenshot
call :build_dungeon_verify
call :build_inspect
call :build_replay
goto done

:build_game
echo [game] src/main.jai
%JAI% src/main.jai
if errorlevel 1 (
    echo [game] FAILED
    set FAILED=1
) else (
    echo [game] OK
    set /a BUILT+=1
)
exit /b 0

:build_test
echo [test] src/tests/test.jai
%JAI% src/tests/test.jai
if errorlevel 1 (
    echo [test] FAILED
    set FAILED=1
) else (
    echo [test] OK
    set /a BUILT+=1
)
exit /b 0

:build_headless
echo [headless] tools/headless.jai
%JAI% tools/headless.jai
if errorlevel 1 (
    echo [headless] FAILED
    set FAILED=1
) else (
    echo [headless] OK
    set /a BUILT+=1
)
exit /b 0

:build_dungeon_test
echo [dungeon_test] tools/dungeon_test.jai
%JAI% tools/dungeon_test.jai
if errorlevel 1 (
    echo [dungeon_test] FAILED
    set FAILED=1
) else (
    echo [dungeon_test] OK
    set /a BUILT+=1
)
exit /b 0

:build_dungeon_screenshot
echo [dungeon_screenshot] tools/dungeon_screenshot.jai
%JAI% tools/dungeon_screenshot.jai
if errorlevel 1 (
    echo [dungeon_screenshot] FAILED
    set FAILED=1
) else (
    echo [dungeon_screenshot] OK
    set /a BUILT+=1
)
exit /b 0

:build_dungeon_verify
echo [dungeon_verify] tools/dungeon_verify.jai
%JAI% tools/dungeon_verify.jai
if errorlevel 1 (
    echo [dungeon_verify] FAILED
    set FAILED=1
) else (
    echo [dungeon_verify] OK
    set /a BUILT+=1
)
exit /b 0

:build_inspect
echo [inspect] tools/inspect.jai
%JAI% tools/inspect.jai
if errorlevel 1 (
    echo [inspect] FAILED
    set FAILED=1
) else (
    echo [inspect] OK
    set /a BUILT+=1
)
exit /b 0

:build_replay
echo [replay] tools/replay.jai
%JAI% tools/replay.jai
if errorlevel 1 (
    echo [replay] FAILED
    set FAILED=1
) else (
    echo [replay] OK
    set /a BUILT+=1
)
exit /b 0

:done
echo.
if "!FAILED!"=="1" (
    echo Build completed with errors.
    exit /b 1
) else (
    echo Build completed: !BUILT! target(s^) OK.
    exit /b 0
)
