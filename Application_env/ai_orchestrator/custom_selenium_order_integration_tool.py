
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from datetime import datetime
import logging
import re
import time



logger = logging.getLogger(__name__)

DEFAULT_HUB_URL = 'http://127.0.0.1:8099/index.html'


class OrderHubScraper:
    def __init__(self, headless=True, hub_url=None):
        self.driver =None
        self.headless = headless
        self.hub_url = hub_url or DEFAULT_HUB_URL
        self.loaded = False
        self.current_store_id = None

    def setup_driver(self) -> bool:
        if self.driver:
            return True
        opts = Options()
        if self.headless:
            opts.add_argument('--headless=new')
        opts.add_argument('--window-size=1920,1080')
        opts.add_argument('--no-sandbox')
        opts.add_argument('--disable-dev-shm-usage')
        try:
            self.driver = webdriver.Chrome(options=opts)
            logger.info('Chrome driver initialized')
            return True
        except Exception as e:
            logger.error(f'Failed to intialized driver: {e}')
            return False



    def close(self):
        if self.driver:
            try:
                self.driver.quit()
            except Exception:
                pass
            self.driver = None
            self.loaded = False


    def navigate_to_hub(self) -> bool:
        if self.loaded:
            return True
        try:
            logger.info(f'Navigating to hub: {self.hub_url}')
            self.driver.get(self.hub_url)
            if not self._wait_for_hub_ready(timeout=60):
                logger.error('Hub did not become ready within timeout')
                return False
            self.loaded = True
            return True
        except Exception as e:
            logger.error(f'Navigation failed: {e}')
            return False

    def _wait_for_hub_ready(self, timeout=60) -> bool:
        wait = WebDriverWait(self.driver, timeout)
        try:
            wait.until(EC.element_to_be_clickable(
                       (By.CSS_SELECTOR, "input[formcontrolname='customer']")))
            logger.info(f'   ready signal 1/3: store input clickable')
        except Exception as e:
            logger.error(f'  store input never became clickable: {e}')
            return False
        try:
            wait.until(EC.presence_of_element_located((By.CSS_SELECTOR, '.div-content.day')))
            logger.info(f'   ready signal 2/3: grid day columns rendered')
        except Exception as e:
            logger.warning(f'  grid did not render (may still work): {e}')
        time.sleep(2)  # signal 3: settle - bindings attach after paint
        logger.info(f'   ready signal 3/3: settle complete')
        return True


    def _wait_for_page_ready(self, timeout=30) -> bool:
        try:
            WebDriverWait(self.driver, timeout).until(EC.presence_of_element_located((
                By.CSS_SELECTOR, '.div-content.day')))
            time.sleep(1)
            return True
        except Exception as e:
            logger.warning(f' page ready wait timed out: {e}')
            return False


    def switch_to_store(self, store_id: str, store_name: str = None) -> bool:
        try:
            wait = WebDriverWait(self.driver, 30)
            input_el = wait.until(EC.element_to_be_clickable((
                By.CSS_SELECTOR, "input[formcontrolname='customer']")))
            input_el.click()
            input_el.clear()
            input_el.send_keys(store_id)

            wait.until(EC.presence_of_all_elements_located((By.CSS_SELECTOR, 'mat-option')))
            for opt in self.driver.find_elements(By.CSS_SELECTOR, 'mat-option'):
                if store_id in opt.text:
                    opt.click()
                    break
            else:
                logger.error(f'No dropdown option matched store {store_id}')
                return False
            return self._wait_for_store_switch(store_id)
        except Exception as e:
            logger.error(f'Store switch failed: {e}')
            return False

    def _wait_for_store_switch(self, store_id: str, timeout=30) -> bool:
        start = time.time()
        time.sleep(1)
        for attempt in range(3):
            try:
                input_el = WebDriverWait(self.driver, timeout // 3).until(EC.presence_of_element_located((
                    By.CSS_SELECTOR, "input[formcontrolname='customer'")))
                placeholder = input_el.get_attribute('placeholder') or ''
                value = input_el.get_attribute('value') or ''
                logger.info(f' switch check {attempt+1}: placeholder={placeholder!r}')
                if store_id in placeholder or store_id in value:
                    logger.info(f' store switch confirmed (attempt {attempt+1})')
                    self._wait_for_page_ready(timeout=20)
                    self.current_store_id = store_id
                    return True

            except Exception as e:
                logger.warning(f' switch check {attempt+1} failed: {e}')
            if time.time() -start > timeout:
                break
            time.sleep(2)

        # Fallback signal: the rebuild grid marks today's column .current.
        try:
            WebDriverWait(self.driver, 15).until(EC.presence_of_element_located((
                By.CSS_SELECTOR, '.div-content.day.current')))
            logger.info(f'grid loaded with current-day marker - switch likely OK')
            self.current_store_id = store_id
            return True
        except Exception:
            logger.error(f' store switch could not be confirmed')
            return False

    def search_product(self, product_id: str) -> bool:
        """Filter the grid to one product, Empty string clears the filter"""
        ladder = [
            'input.filter-input',                      # class - most stable
            "input[placeholder='Filter / Search]",     # current copy
            "input[placeholder='Filter']",             # historical copy
        ]
        try:
            wait = WebDriverWait(self.driver, 15)
            filter_input = None
            for selector in ladder:
                try:
                    filter_input = wait.until(EC.presence_of_element_located((
                        By.CSS_SELECTOR, selector)))
                    logger.info(f' filter matched via: {selector}')
                    break
                except Exception:
                    continue
            if filter_input is None:
                # Forensics: log every input's identifying attributes so the
                # Next selector run can be written from the log alone.
                fingerprint = [{
                    'placeholder': i.get_attribute('placeholder'),
                    'class': i.get_attribute('class'),
                    'id': i.get_attribute('id'),
                } for i in self.driver.find_elements(By.TAG_NAME, 'input')]
                logger.error(f' No filter input matched: Page inputs: {fingerprint}')
                return False
            filter_input.clear()
            filter_input.send_keys(product_id)
            filter_input.send_keys(Keys.RETURN)
            time.sleep(2) # the grid REBUILDS its rows on filter (by design)
            return True
        except Exception as e:
            logger.error(f' Product search failed: {e}')
            return False



























































