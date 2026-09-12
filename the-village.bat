@echo off
setlocal enabledelayedexpansion

set PACK_URL=https://CracklyDuck.github.io/the-village/pack.toml
set MC_DIR=%APPDATA%\.minecraft
set GAME_DIR=%APPDATA%\.the-village

echo ===== The Village Modpack Installer =====
echo.

REM --- Check Java ---
where java >nul 2>nul
if !errorlevel! neq 0 (
    echo Java is not installed! Download it from https://www.java.com/en/download/
    pause
    exit /b
)

REM --- Pull Minecraft version from pack.toml ---
echo Fetching pack info...
powershell -NoProfile -Command "$r = Invoke-WebRequest -Uri '%PACK_URL%' -UseBasicParsing; $text = [System.Text.Encoding]::UTF8.GetString($r.Content); if ($text -match 'minecraft\s*=\s*\"(.+?)\"') { $Matches[1] }" > "%TEMP%\mcver.txt"
set /p MC_VERSION=<"%TEMP%\mcver.txt"

if "!MC_VERSION!"=="" (
    echo ERROR: Could not fetch Minecraft version from pack.toml
    pause
    exit /b
)

echo Detected Minecraft version: !MC_VERSION!

REM --- Download Fabric installer if not present ---
if not exist "%MC_DIR%\fabric-installer.jar" (
    echo Downloading Fabric installer...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar' -OutFile '%MC_DIR%\fabric-installer.jar'"
)

REM --- Install/update Fabric client ---
echo Installing Fabric for Minecraft !MC_VERSION!...
java -jar "%MC_DIR%\fabric-installer.jar" client -mcversion !MC_VERSION! -dir "%MC_DIR%"

REM --- Set game directory in launcher profile ---
echo Configuring launcher profile...
powershell -NoProfile -Command "& { $json = Get-Content '%MC_DIR%\launcher_profiles.json' -Raw | ConvertFrom-Json; foreach ($key in @($json.profiles.PSObject.Properties.Name)) { $p = $json.profiles.$key; if ($p.lastVersionId -like 'fabric-loader*') { $p | Add-Member -NotePropertyName 'gameDir' -NotePropertyValue '%GAME_DIR%' -Force; $p.name = 'The Village'; Write-Host ('Updated profile: ' + $p.name) } }; $json | ConvertTo-Json -Depth 10 | Set-Content '%MC_DIR%\launcher_profiles.json' }"

REM --- Create game directory if needed ---
if not exist "%GAME_DIR%" mkdir "%GAME_DIR%"

REM --- Download packwiz bootstrap if not present ---
if not exist "%MC_DIR%\packwiz-installer-bootstrap.jar" (
    echo Downloading packwiz-installer-bootstrap...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/packwiz/packwiz-installer-bootstrap/releases/latest/download/packwiz-installer-bootstrap.jar' -OutFile '%MC_DIR%\packwiz-installer-bootstrap.jar'"
)

REM --- Copy packwiz bootstrap to game dir ---
copy /y "%MC_DIR%\packwiz-installer-bootstrap.jar" "%GAME_DIR%\packwiz-installer-bootstrap.jar" >nul

REM --- Sync mods ---
echo Syncing mods...
cd /d "%GAME_DIR%"
java -jar packwiz-installer-bootstrap.jar %PACK_URL%

echo.
echo ===== Done! Launching Minecraft... =====

pause
endlocal