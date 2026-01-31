@echo off
setlocal EnableDelayedExpansion
cd /d "%~dp0"

REM Auto-setup MSVC environment if not already configured
where cl.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Setting up MSVC environment...
    set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
    if not exist "!VSWHERE!" (
        echo ERROR: vswhere.exe not found.
        exit /b 1
    )
    for /f "usebackq tokens=*" %%i in (`"!VSWHERE!" -latest -property installationPath`) do set "VSINSTALL=%%i"
    if not defined VSINSTALL (
        echo ERROR: Could not find Visual Studio installation
        exit /b 1
    )
    call "!VSINSTALL!\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
    where cl.exe >nul 2>&1
    if !ERRORLEVEL! NEQ 0 (
        echo ERROR: Failed to initialize MSVC environment
        exit /b 1
    )
)

echo Compiling crashtest.c...
cl /W4 /Zi /Fe:crashtest.exe crashtest.c /link /DEBUG
