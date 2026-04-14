import logging
from unittest.mock import patch


def test_logging_defaults_to_info_when_log_level_not_set():
    import importlib
    import app.main

    with patch.dict("os.environ", {}, clear=False):
        importlib.reload(app.main)

    assert logging.getLogger().level == logging.INFO


def test_logging_uses_debug_when_log_level_is_debug():
    import importlib
    import app.main

    with patch.dict("os.environ", {"LOG_LEVEL": "DEBUG"}):
        importlib.reload(app.main)

    assert logging.getLogger().level == logging.DEBUG


def test_logging_uses_warning_when_log_level_is_warning():
    import importlib
    import app.main

    with patch.dict("os.environ", {"LOG_LEVEL": "WARNING"}):
        importlib.reload(app.main)

    assert logging.getLogger().level == logging.WARNING


def test_logging_defaults_to_info_when_log_level_is_invalid():
    import importlib
    import app.main

    with patch.dict("os.environ", {"LOG_LEVEL": "INVALID"}):
        importlib.reload(app.main)

    assert logging.getLogger().level == logging.INFO
