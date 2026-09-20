""""
Selenium Tool for OrderHub Integration
Allows Qwen or the pre-trained MLP model to place orders by editing ADJ cells for specific dates
"""


__all__ = ['OrderHubtool', 'OrderHubScraper']

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from datetime import datetime, timedelta
import os
import time
import random
import logging


# Session-token + ordering-hub URL are resolved from the environment (never hardcoded).
# See hub_config for the resolution order and rotation steps.

try:
    from .hub_config import (ORDERING_HUB_URL, HUB_SESSION_TOKEN,
                             token_is_placeholder, mask_url)
except ImportError: # run as a bare script (dir on sys.path[0]) rather than a package
    from hub_config import (ORDERING_HUB_URL, HUB_SESSION_TOKEN,
                            token_is_placeholder, mask_url)


logger = logging.getLogger(__name__)


class OrderHubTool:
    """Selenium tool for placing orders on OrderHub"""

    def __init__(self, headless=False, hub_url=None, user_data_dir=None):
        self.driver = None
        self.headless = headless
        self.target_store_id = '70012004'
        self.hub_url = hub_url or ORDERING_HUB_URL
        self.logged_in = False
        self._virtual_display = None # Xvfb handle when running headful on a display-less host (my beellink server)
        self.last_block_kind = None # 'cloudflare' | 'ui_change' | 'unknown', set on hub-load failure
        # Persistent Chrome profile carries the Cloudflare cf_clearance cookie +
        # returning-visitor history so the daemon reads as a trusted human.
        # Solve the Turnstile challenge once (tests/solve_challenge.py) and every run that shares this dir benefits.
        # Env default keeps daemon + solver in sync.
        self.user_data_dir = user_data_dir  or os.environ.get('LEVAINTRON_CHROME_PROFILE')

























































