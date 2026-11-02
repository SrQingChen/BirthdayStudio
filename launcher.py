"""Entry point used by PyInstaller / Nuitka builds (and by `python launcher.py`)."""

from app.main import main

if __name__ == "__main__":
    raise SystemExit(main())
