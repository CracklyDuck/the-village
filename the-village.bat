@echo off
setlocal enabledelayedexpansion

set "REPO_URL=https://CracklyDuck.github.io/the-village"
set "MC_DIR=%APPDATA%\.minecraft"
set "GAME_DIR=%APPDATA%\.the-village"

echo ===== The Village Modpack Installer =====
echo.

REM --- Check Java ---
where java >nul 2>nul
if !errorlevel! neq 0 (
    echo Java is not installed! Download it from https://www.java.com/en/download/
    pause
    exit /b
)

REM --- Pick a pack. An argument skips the menu:  the-village.bat full ---
set "PACK_VARIANT=%~1"
if not "!PACK_VARIANT!"=="" goto :chosen

REM Look up what each pack currently targets so the menu shows real
REM versions instead of numbers baked into this file.
echo Checking available versions...
call :lookup latest
call :lookup full
echo.

echo Which version of The Village do you want?
echo.
if defined MCV_latest (echo    [1] latest  -  Minecraft !MCV_latest!) else (echo    [1] latest)
if defined MCV_full   (echo    [2] full    -  Minecraft !MCV_full!) else (echo    [2] full)
echo.

:ask
set "CHOICE="
set /p "CHOICE=Enter 1 or 2, then press Enter [default 1]: "
if "!CHOICE!"=="" set "CHOICE=1"
if "!CHOICE!"=="1" (
    set "PACK_VARIANT=latest"
    goto :chosen
)
if "!CHOICE!"=="2" (
    set "PACK_VARIANT=full"
    goto :chosen
)
echo Sorry, please type 1 or 2.
goto :ask

:chosen
set "PACK_URL=!REPO_URL!/!PACK_VARIANT!/pack.toml"
echo.
echo Installing: !PACK_VARIANT!
echo Game folder: !GAME_DIR!
echo.

REM --- Pull Minecraft version from pack.toml ---
echo Fetching pack info...
powershell -NoProfile -Command "$r = Invoke-WebRequest -Uri '!PACK_URL!' -UseBasicParsing; $text = [System.Text.Encoding]::UTF8.GetString($r.Content); if ($text -match 'minecraft\s*=\s*\"(.+?)\"') { $Matches[1] }" > "%TEMP%\mcver.txt"
set /p MC_VERSION=<"%TEMP%\mcver.txt"

if "!MC_VERSION!"=="" (
    echo ERROR: Could not fetch pack info from !PACK_URL!
    echo Check that "!PACK_VARIANT!" is a real pack name, and that you are online.
    pause
    exit /b
)

echo Detected Minecraft version: !MC_VERSION!

REM --- One profile per Minecraft version, all sharing the same game dir ---
set "PROFILE_NAME=The Village !MC_VERSION!"

REM --- Download Fabric installer if not present ---
if not exist "%MC_DIR%\fabric-installer.jar" (
    echo Downloading Fabric installer...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar' -OutFile '%MC_DIR%\fabric-installer.jar'"
)

REM --- Install/update Fabric client ---
echo Installing Fabric for Minecraft !MC_VERSION!...
java -jar "%MC_DIR%\fabric-installer.jar" client -mcversion !MC_VERSION! -dir "%MC_DIR%"

REM --- Point only this version's Fabric profile at the game dir ---
echo Configuring launcher profile...
powershell -NoProfile -Command "& { $json = Get-Content '%MC_DIR%\launcher_profiles.json' -Raw | ConvertFrom-Json; foreach ($key in @($json.profiles.PSObject.Properties.Name)) { $p = $json.profiles.$key; if ($p.lastVersionId -like 'fabric-loader*-!MC_VERSION!') { $p | Add-Member -NotePropertyName 'gameDir' -NotePropertyValue '!GAME_DIR!' -Force; $p.name = '!PROFILE_NAME!'; Write-Host ('Updated profile: ' + $p.name) } }; $json | ConvertTo-Json -Depth 10 | Set-Content '%MC_DIR%\launcher_profiles.json' }"

REM --- Create game directory if needed ---
if not exist "!GAME_DIR!" mkdir "!GAME_DIR!"

REM --- Download packwiz bootstrap if not present ---
if not exist "%MC_DIR%\packwiz-installer-bootstrap.jar" (
    echo Downloading packwiz-installer-bootstrap...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar' -OutFile '%MC_DIR%\packwiz-installer-bootstrap.jar'"
)

REM --- Copy packwiz bootstrap to game dir ---
copy /y "%MC_DIR%\packwiz-installer-bootstrap.jar" "!GAME_DIR!\packwiz-installer-bootstrap.jar" >nul

REM --- Sync mods ---
echo Syncing mods...
cd /d "!GAME_DIR!"
java -jar packwiz-installer-bootstrap.jar "!PACK_URL!"

echo.
echo ===== Done! =====
echo Open the Minecraft launcher and pick the "!PROFILE_NAME!" profile.

pause
endlocal
exit /b

REM --- Reads the Minecraft version of one pack into MCV_<name>. Quiet on failure. ---
:lookup
powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%REPO_URL%/%~1/pack.toml' -UseBasicParsing -TimeoutSec 15; $t = [System.Text.Encoding]::UTF8.GetString($r.Content); if ($t -match 'minecraft\s*=\s*\"(.+?)\"') { $Matches[1] } } catch { }" > "%TEMP%\tv_mcv.txt" 2>nul
set /p MCV_%~1=<"%TEMP%\tv_mcv.txt"
goto :eof
