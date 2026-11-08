@echo off
rem Launch BirthdayStudio editor (runs from source, no packaging needed)
cd /d "%~dp0"
python -m app.main
if errorlevel 1 (
  echo.
  echo Launch failed. Install dependencies first:  pip install -r requirements.txt
  pause
)
