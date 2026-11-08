@echo off
rem Launch BirthdayStudio player (runs from source)
rem Usage 1: drag a profile folder / profile.json / .bbp package onto this file
rem Usage 2: double-click - plays the profile most recently opened in the editor
cd /d "%~dp0"
if not "%~1"=="" (
  python -m app.main --play "%~1"
) else (
  python -m app.main --play last
)
if errorlevel 2 (
  echo.
  echo Playback failed. Open a profile in the editor first, or drag one onto this file.
  pause
)
