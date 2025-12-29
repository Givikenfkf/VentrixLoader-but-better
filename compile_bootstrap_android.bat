@echo off
setlocal enabledelayedexpansion

REM ================================================================
REM compile_bootstrap_android.bat
REM Fixed for CI:
REM  - dotnet publish uses -f net6 for multi-target projects (NETSDK1129 fix)
REM  - no interactive PAUSE in CI (GITHUB_ACTIONS guard)
REM ================================================================

REM Defaults (override by setting env vars before calling)
if "%CONFIG%"=="" set CONFIG=Release
if "%RUNTIME%"=="" set RUNTIME=linux-bionic-arm64
if "%SOLUTION%"=="" set SOLUTION=MelonLoader.sln

echo ================================================================
echo Compile bootstrap (Android oriented) - %DATE% %TIME%
echo Solution: %SOLUTION%
echo Configuration: %CONFIG%
echo Runtime: %RUNTIME%
echo ================================================================

REM Exit on error helper
:checkError
if errorlevel 1 (
  echo.
  echo ERROR: Previous command failed with exit code %ERRORLEVEL%.
  echo Aborting.
  exit /b %ERRORLEVEL%
)
goto :eof

REM 1) Restore solution
echo.
echo Restoring solution...
dotnet restore "%SOLUTION%"
call :checkError

REM 2) Build solution
echo.
echo Building solution (no publish)...
dotnet build "%SOLUTION%" -c %CONFIG% -v minimal
call :checkError

REM 3) Publish projects that require publish for Android bootstrap outputs.
REM Note: specify -f net6 for projects that multi-target (fix NETSDK1129).
REM Adjust or add projects here if your fork requires different ones.

echo.
echo Publishing MelonLoader.Bootstrap (native bootstrap lib for x86)
if exist "MelonLoader.Bootstrap\MelonLoader.Bootstrap.csproj" (
  dotnet publish "MelonLoader.Bootstrap\MelonLoader.Bootstrap.csproj" -c %CONFIG% -r win-x86 -f net48 --self-contained false
  REM If your MelonLoader.Bootstrap project targets a different TF, adjust -f accordingly.
  call :checkError
) else (
  echo Skipping MelonLoader.Bootstrap publish: project not found.
)

echo.
echo Publishing MelonLoader.NativeHost (if exists) for runtime publishing
if exist "MelonLoader.NativeHost\MelonLoader.NativeHost.csproj" (
  dotnet publish "MelonLoader.NativeHost\MelonLoader.NativeHost.csproj" -c %CONFIG% -r %RUNTIME% -f net6 --self-contained false
  call :checkError
) else (
  echo Skipping MelonLoader.NativeHost publish: project not found.
)

echo.
echo Publishing MelonLoader (main managed assembly) for target runtime
if exist "MelonLoader\MelonLoader.csproj" (
  REM MelonLoader.csproj targets multiple frameworks (net35, net6). Publish net6 for linux-bionic-arm64.
  dotnet publish "MelonLoader\MelonLoader.csproj" -c %CONFIG% -r %RUNTIME% -f net6 --self-contained false
  call :checkError
) else (
  echo Skipping MelonLoader publish: project not found.
)

echo.
echo Publishing UnityUtilities / dependencies that the build expects (net6)
for %%P in (
  "UnityUtilities\UnityEngine.Il2CppImageConversionManager\UnityEngine.Il2CppImageConversionManager.csproj"
  "UnityUtilities\UnityEngine.Il2CppAssetBundleManager\UnityEngine.Il2CppAssetBundleManager.csproj"
) do (
  if exist %%~P (
    echo Publishing %%~P ...
    dotnet publish "%%~P" -c %CONFIG% -r %RUNTIME% -f net6 --self-contained false
    call :checkError
  ) else (
    echo Skipping %%~P (not found).
  )
)

echo.
echo Publishing PortablePdbToMdb (tool)
if exist "PortablePdbToMdb\PortablePdbToMdb.csproj" (
  dotnet publish "PortablePdbToMdb\PortablePdbToMdb.csproj" -c %CONFIG% -r win-x64 -f net6 --self-contained false
  call :checkError
) else (
  echo Skipping PortablePdbToMdb (not found).
)

REM Add or modify publishes above to match your repo's actual needs.
REM If you need net35 outputs for specific components, add additional publish lines:
REM dotnet publish "SomeProject\SomeProject.csproj" -c %CONFIG% -r %RUNTIME% -f net35 --self-contained false

echo.
echo Running any custom packaging steps (existing project scripts)
REM If you have custom native build steps, call them here.
REM Example: call a helper script that creates libmain.dll, or runs makedll steps.
if exist ".\build_native.bat" (
  echo Running build_native.bat...
  call .\build_native.bat
  call :checkError
) else (
  echo No build_native.bat found - skipping.
)

REM Additional warnings around NDK access: CI images may not include all Android NDK files.
REM If your script uses grep or reads /sysroot/etc/os-release in the NDK, it may fail; handle that in project-specific scripts.

echo.
echo All publish steps completed. Check Output/ or published folders for artifacts.
echo.

REM -------------- avoid interactive pause in CI ---------------------
if defined GITHUB_ACTIONS (
  echo Running in CI environment (GITHUB_ACTIONS defined) - skipping interactive pause.
) else (
  echo Waiting for keypress (local run)...
  pause
)

endlocal
exit /b 0
