import importlib
import logging
from unittest.mock import patch


def test_logging_defaults_to_info():
    import app.main
    with patch.dict("os.environ", {"LOG_LEVEL": "INFO"}):
        importlib.reload(app.main)
    assert logging.getLogger().level == logging.INFO


def test_logging_uses_debug_when_set():
    import app.main
    with patch.dict("os.environ", {"LOG_LEVEL": "DEBUG"}):
        importlib.reload(app.main)
    assert logging.getLogger().level == logging.DEBUG
