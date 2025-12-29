@echo off
setlocal enabledelayedexpansion

REM ================================================================
REM compile_bootstrap_android.bat  (CI-friendly)
REM - Forces predictable publish output under %CD%\Output\%CONFIG%\%RUNTIME%\
REM - Adds -f net6 for multi-target projects (resolves NETSDK1129)
REM - No interactive pause in CI
REM ================================================================

REM Defaults (override via environment variables if desired)
if "%CONFIG%"=="" set CONFIG=Release
if "%RUNTIME%"=="" set RUNTIME=linux-bionic-arm64
if "%SOLUTION%"=="" set SOLUTION=MelonLoader.sln

echo ================================================================
echo Compile bootstrap (Android oriented) - %DATE% %TIME%
echo Solution: %SOLUTION%
echo Configuration: %CONFIG%
echo Runtime: %RUNTIME%
echo Working dir: %CD%
echo ================================================================

REM Helper to stop on errors
:checkError
if errorlevel 1 (
  echo.
  echo ERROR: Previous command failed with exit code %ERRORLEVEL%.
  echo Aborting.
  exit /b %ERRORLEVEL%
)
goto :eof

REM Ensure output base folder
set OUTPUT_BASE=%CD%\Output\%CONFIG%\%RUNTIME%
if not exist "%OUTPUT_BASE%" (
  mkdir "%OUTPUT_BASE%"
)

echo.
echo Restoring solution...
dotnet restore "%SOLUTION%"
call :checkError

echo.
echo Building solution...
dotnet build "%SOLUTION%" -c %CONFIG% -v minimal
call :checkError

REM Publish individual projects to deterministic locations under Output\%CONFIG%\%RUNTIME%\{ProjectName}
REM Adjust -f or -r for specific projects as needed.

REM 1) MelonLoader (main managed assembly) -> publish net6 for linux-bionic-arm64
if exist "MelonLoader\MelonLoader.csproj" (
  echo Publishing MelonLoader -> %OUTPUT_BASE%\MelonLoader
  dotnet publish "MelonLoader\MelonLoader.csproj" -c %CONFIG% -r %RUNTIME% -f net6 --self-contained false -o "%OUTPUT_BASE%\MelonLoader"
  call :checkError
) else (
  echo Skipping MelonLoader publish: not found
)

REM 2) MelonLoader.NativeHost -> native host (net6)
if exist "MelonLoader.NativeHost\MelonLoader.NativeHost.csproj" (
  echo Publishing MelonLoader.NativeHost -> %OUTPUT_BASE%\MelonLoader.NativeHost
  dotnet publish "MelonLoader.NativeHost\MelonLoader.NativeHost.csproj" -c %CONFIG% -r %RUNTIME% -f net6 --self-contained false -o "%OUTPUT_BASE%\MelonLoader.NativeHost"
  call :checkError
) else (
  echo Skipping MelonLoader.NativeHost publish: not found
)

REM 3) UnityUtilities projects (if present)
if exist "UnityUtilities\UnityEngine.Il2CppImageConversionManager\UnityEngine.Il2CppImageConversionManager.csproj" (
  echo Publishing UnityEngine.Il2CppImageConversionManager -> %OUTPUT_BASE%\Il2CppImageConversionManager
  dotnet publish "UnityUtilities\UnityEngine.Il2CppImageConversionManager\UnityEngine.Il2CppImageConversionManager.csproj" -c %CONFIG% -r %RUNTIME% -f net6 --self-contained false -o "%OUTPUT_BASE%\Il2CppImageConversionManager"
  call :checkError
) else (
  echo Skipping Il2CppImageConversionManager: not found
)

if exist "UnityUtilities\UnityEngine.Il2CppAssetBundleManager\UnityEngine.Il2CppAssetBundleManager.csproj" (
  echo Publishing UnityEngine.Il2CppAssetBundleManager -> %OUTPUT_BASE%\Il2CppAssetBundleManager
  dotnet publish "UnityUtilities\UnityEngine.Il2CppAssetBundleManager\UnityEngine.Il2CppAssetBundleManager.csproj" -c %CONFIG% -r %RUNTIME% -f net6 --self-contained false -o "%OUTPUT_BASE%\Il2CppAssetBundleManager"
  call :checkError
) else (
  echo Skipping Il2CppAssetBundleManager: not found
)

REM 4) MelonLoader.Bootstrap native lib (example publish target: produce libmain.dll in a known place)
if exist "MelonLoader.Bootstrap\MelonLoader.Bootstrap.csproj" (
  echo Publishing MelonLoader.Bootstrap (NOTE: targeting native/lib outputs)...
  REM Publish to a bootstrap-specific folder. Use win-x86 target for libmain (adjust if needed).
  dotnet publish "MelonLoader.Bootstrap\MelonLoader.Bootstrap.csproj" -c %CONFIG% -r win-x86 -f net48 --self-contained false -o "%CD%\Output\%CONFIG%\bootstrap\win-x86"
  call :checkError
) else (
  echo Skipping MelonLoader.Bootstrap publish: not found
)

REM 5) PortablePdbToMdb tool (if present) - produce a Windows tool output so you can download
if exist "PortablePdbToMdb\PortablePdbToMdb.csproj" (
  echo Publishing PortablePdbToMdb -> %CD%\Output\%CONFIG%\tools\PortablePdbToMdb
  dotnet publish "PortablePdbToMdb\PortablePdbToMdb.csproj" -c %CONFIG% -r win-x64 -f net6 --self-contained false -o "%CD%\Output\%CONFIG%\tools\PortablePdbToMdb"
  call :checkError
) else (
  echo Skipping PortablePdbToMdb: not found
)

REM Any other publishes you need: add here with -o path to the Output tree.

echo.
echo Listing Output tree for verification:
if exist "%CD%\Output" (
  dir /s /b "%CD%\Output"
) else (
  echo "No Output folder produced"
)

REM Create a small manifest file with a snapshot (helpful to download from Actions)
echo Build snapshot created at %DATE% %TIME% > "%CD%\Output\build_snapshot.txt"
for /f "delims=" %%A in ('dir /s /b "%CD%\Output" 2^>nul') do echo %%~fA >> "%CD%\Output\build_snapshot.txt" 2>nul

REM Skip interactive pause in CI
if defined GITHUB_ACTIONS (
  echo Running in CI - skipping pause.
) else (
  echo Local run finished. Press any key to continue...
  pause
)

endlocal
exit /b 0
