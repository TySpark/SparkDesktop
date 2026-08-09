@echo off
setlocal
cd /d "%~dp0.."

REM Build an optimized Release of SnowDesktop, stage a clean distributable
REM payload into a temporary folder, and pack it into a portable zip archive.
REM Only the zip (+ .sha256) is kept under release\v<version>\ as a local
REM archive; each version gets its own folder and older ones are untouched.
REM The release\ folder is git-ignored.

REM -- Preflight: do not build while SnowDesktop is running --
tasklist /fi "IMAGENAME eq SparkDesktop.exe" /nh 2>nul | find /i "SparkDesktop.exe" >nul
if not errorlevel 1 (
    echo Build preflight stopped: SparkDesktop.exe is running.
    echo Exit SnowDesktop normally before building.
    exit /b 3
)

REM -- Locate the Visual Studio toolchain --
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
set "VSROOT="
if exist "%VSWHERE%" (
    for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VSROOT=%%i"
)
if not defined VSROOT (
    echo Visual Studio Build Tools with VC x64 tools was not found.
    exit /b 1
)
call "%VSROOT%\VC\Auxiliary\Build\vcvars64.bat" >nul
if %ERRORLEVEL% NEQ 0 (
    echo Failed to initialize the MSVC x64 environment.
    exit /b 1
)

REM -- Configure an optimized Release build in .build --
cmake -B .build -DCMAKE_BUILD_TYPE=Release
if %ERRORLEVEL% NEQ 0 (
    echo CMake configure FAILED
    exit /b 1
)

echo.
echo === Building SparkDesktop.exe and SnowDesktopTaskbarHook.dll (Release) ===
cmake --build .build --target SnowDesktop SnowDesktopTaskbarHook SparkDesktopUpdater --parallel 2
if %ERRORLEVEL% NEQ 0 (
    echo SparkDesktop build FAILED
    exit /b 1
)

REM -- Stage the distributable payload into a temporary folder --
for /f "usebackq tokens=2 delims=,: " %%v in ("version.json") do set "VERSION=%%~v"
if not defined VERSION (
    echo Cannot read the version from version.json.
    exit /b 1
)
set "STAGE=.build\release-stage"
if exist "%STAGE%" rmdir /s /q "%STAGE%"
mkdir "%STAGE%\licenses" >nul

copy /y ".build\SparkDesktop.exe" "%STAGE%\" >nul
if %ERRORLEVEL% NEQ 0 ( echo Missing SparkDesktop.exe & exit /b 1 )
copy /y ".build\SnowDesktopTaskbarHook.dll" "%STAGE%\" >nul
if %ERRORLEVEL% NEQ 0 ( echo Missing SnowDesktopTaskbarHook.dll & exit /b 1 )
copy /y ".build\SparkDesktopUpdater.exe" "%STAGE%\" >nul
if %ERRORLEVEL% NEQ 0 ( echo Missing SparkDesktopUpdater.exe & exit /b 1 )

copy /y "LICENSE" "%STAGE%\" >nul
copy /y "THIRD_PARTY_NOTICES.md" "%STAGE%\" >nul
copy /y "README.md" "%STAGE%\" >nul
copy /y "README.en.md" "%STAGE%\" >nul
copy /y "third_party\fluentui-system-icons\LICENSE" "%STAGE%\licenses\FluentSystemIcons-LICENSE.txt" >nul
xcopy /e /i /y "widgets" "%STAGE%\widgets" >nul
xcopy /e /i /y "lang" "%STAGE%\lang" >nul
xcopy /e /i /y "skill" "%STAGE%\skill" >nul

REM -- Package the portable zip into release\v<version>; payload is dropped --
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0package_portable.ps1" -StageDir "%STAGE%"
if %ERRORLEVEL% NEQ 0 (
    echo Package zip creation FAILED
    exit /b 1
)

echo.
echo === Release build complete ===
echo Archive:  release\v%VERSION%\SparkDesktop-portable-x64.zip (+ .sha256)
echo The zip contains SparkDesktop.exe, SnowDesktopTaskbarHook.dll, SparkDesktopUpdater.exe, widgets\, lang\, skill\.
echo The release\ folder (versioned zip archives) is git-ignored.
exit /b 0
