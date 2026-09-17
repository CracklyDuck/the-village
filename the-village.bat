@echo off
setlocal enabledelayedexpansion

set "REPO_URL=https://CracklyDuck.github.io/the-village"
set "MC_DIR=%APPDATA%\.minecraft"

echo ===== The Village Modpack Installer =====
echo.

REM --- Check Java ---
where java >nul 2>nul
if !errorlevel! neq 0 (
    echo Java is not installed! Download it from https://www.java.com/en/download/
    pause
    exit /b
)

REM --- Pick which modpack to install (or pass it as an argument) ---
set "PACK_VARIANT=%~1"
if "!PACK_VARIANT!"=="" (
    echo Which modpack do you want?
    echo    [1] full     Minecraft 26.2, 31 mods, full performance stack
    echo    [2] latest   Minecraft 26.3, 17 mods, fewer are updated so far
    echo.
    set /p "CHOICE=Enter 1 or 2 [default 1]: "
    if "!CHOICE!"=="2" (set "PACK_VARIANT=latest") else (set "PACK_VARIANT=full")
)

set "PACK_URL=!REPO_URL!/!PACK_VARIANT!/pack.toml"

REM --- Each variant gets its own game dir; full keeps the original path ---
if /i "!PACK_VARIANT!"=="full" (
    set "GAME_DIR=%APPDATA%\.the-village"
) else (
    set "GAME_DIR=%APPDATA%\.the-village-!PACK_VARIANT!"
)

echo Installing: !PACK_VARIANT!
echo Game folder: !GAME_DIR!
echo.

REM --- Pull Minecraft version from pack.toml ---
echo Fetching pack info...
powershell -NoProfile -Command "$r = Invoke-WebRequest -Uri '!PACK_URL!' -UseBasicParsing; $text = [System.Text.Encoding]::UTF8.GetString($r.Content); if ($text -match 'minecraft\s*=\s*\"(.+?)\"') { $Matches[1] }" > "%TEMP%\mcver.txt"
set /p MC_VERSION=<"%TEMP%\mcver.txt"

if "!MC_VERSION!"=="" (
    echo ERROR: Could not fetch Minecraft version from !PACK_URL!
    pause
    exit /b
)

echo Detected Minecraft version: !MC_VERSION!

REM --- Name the launcher profile per variant so they do not overwrite each other ---
if /i "!PACK_VARIANT!"=="full" (
    set "PROFILE_NAME=The Village"
) else (
    set "PROFILE_NAME=The Village !MC_VERSION!"
)

REM --- Download Fabric installer if not present ---
if not exist "%MC_DIR%\fabric-installer.jar" (
    echo Downloading Fabric installer...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar' -OutFile '%MC_DIR%\fabric-installer.jar'"
)

REM --- Install/update Fabric client ---
echo Installing Fabric for Minecraft !MC_VERSION!...
java -jar "%MC_DIR%\fabric-installer.jar" client -mcversion !MC_VERSION! -dir "%MC_DIR%"

REM --- Point only this version's Fabric profile at this variant's game dir ---
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
echo ===== Done! Launching Minecraft... =====
echo Pick the "!PROFILE_NAME!" profile in the launcher.
start "" minecraft-launcher://

pause
endlocal
