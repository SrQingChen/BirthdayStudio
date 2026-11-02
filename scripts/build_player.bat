@echo off
chcp 65001 >nul
rem Build the standalone BirthdayStudio player.
rem Default: PyInstaller onefile (works out of the box here).
rem If Nuitka is installed, set USE_NUITKA=1 for the smaller build.
cd /d "%~dp0.."

if "%USE_NUITKA%"=="1" (
  echo [build] Nuitka standalone...
  python -m nuitka --standalone --enable-plugin=pyside6 --include-qt-plugins=all ^
    --assume-yes-for-downloads --include-package=app ^
    --include-data-dir=app/qml=app/qml ^
    --include-data-dir=resources=resources ^
    --include-data-dir=plugins=plugins ^
    --include-data-file=LICENSE=LICENSE ^
    --output-dir=dist\nuitka ^
    --output-filename=BirthdayStudioPlayer.exe ^
    launcher.py
  echo [build] Done: dist\nuitka\launcher.dist\BirthdayStudioPlayer.exe
  exit /b 0
)

echo [build] PyInstaller onefile...
python -m PyInstaller --noconfirm --clean --onefile --windowed ^
  --name BirthdayStudioPlayer ^
  --paths . ^
  --hidden-import PySide6.QtQuick ^
  --hidden-import PySide6.QtQuickControls2 ^
  --hidden-import PySide6.QtQuick3D ^
  --hidden-import PySide6.QtMultimedia ^
  --exclude-module matplotlib ^
  --exclude-module PIL ^
  --exclude-module numpy ^
  --exclude-module pandas ^
  --exclude-module scipy ^
  --exclude-module IPython ^
  --exclude-module jupyter ^
  --exclude-module tkinter ^
  --exclude-module win32com ^
  --exclude-module pythoncom ^
  --exclude-module pywintypes ^
  --add-data "app\qml;app\qml" ^
  --add-data "resources;resources" ^
  --add-data "plugins;plugins" ^
  --add-data "LICENSE;." ^
  launcher.py

if errorlevel 1 (
  echo [build] PyInstaller failed.
  exit /b 1
)
echo [build] Done: dist\BirthdayStudioPlayer.exe
