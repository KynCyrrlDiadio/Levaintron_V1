#!/usr/bin/env python3
"""
Selenium Tool for OrderHub Integration
Allows Qwen or the pre-trained MLP to place orders by editing ADJ cells for specific dates
"""

__all__ = ['OrderHubTool', 'OrderHubScraper']

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

# Session token + ordering-hub URL are resolved from the environment (never
# hardcoded). See hub_config for the resolution order and rotation steps.
try:
    from .hub_config import (ORDERING_HUB_URL, HUB_SESSION_TOKEN,
                              token_is_placeholder, mask_url)
except ImportError:  # run as a bare script (dir on sys.path[0]) rather than a package
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
        self._virtual_display = None  # Xvfb handle when running headful on a display-less host
        self.last_block_kind = None   # 'cloudflare' | 'ui_change' | 'unknown', set on hub-load failure
        # Persistent Chrome profile carries the Cloudflare cf_clearance cookie +
        # returning-visitor history so the daemon reads as a trusted human. Solve
        # the Turnstile challenge once (tests/solve_challenge.py) and every run
        # that shares this dir benefits. Env default keeps daemon + solver in sync.
        self.user_data_dir = user_data_dir or os.environ.get('LEVAINTRON_CHROME_PROFILE')

    def setup_driver(self):
        """Initialize Chrome driver.

        The hub sits behind a Cloudflare Turnstile challenge that fires on the
        headless fingerprint (HeadlessChrome UA + navigator.webdriver=true), so
        we NEVER pass --headless. On a display-less host we start an
        Xvfb virtual display and run Chrome headful behind it, plus masking flags
        so navigator.webdriver is hidden. Validated 2026-05-26 — see
        memory project_hub_bot_challenge.
        """
        if self.driver:
            return True

        # When the caller asks for "headless", give them a headful Chrome behind a
        # virtual display instead. If a real $DISPLAY already exists, reuse it.
        if self.headless and not os.environ.get('DISPLAY'):
            try:
                from pyvirtualdisplay import Display
                self._virtual_display = Display(visible=False, size=(1920, 1080))
                self._virtual_display.start()
                logger.info(f"Started Xvfb virtual display: {os.environ.get('DISPLAY')}")
            except Exception as e:
                logger.error(f"Could not start Xvfb virtual display: {e}")
                return False

        chrome_options = Options()
        # Deliberately NOT --headless: that token trips Cloudflare's bot challenge.
        chrome_options.add_argument('--no-sandbox')
        chrome_options.add_argument('--disable-dev-shm-usage')
        chrome_options.add_argument('--window-size=1920,1080')
        # Persistent profile (carries cf_clearance) when configured. Only one Chrome
        # may hold the profile lock at a time — daemon and solver must not overlap.
        if self.user_data_dir:
            os.makedirs(self.user_data_dir, exist_ok=True)
            chrome_options.add_argument(f'--user-data-dir={self.user_data_dir}')
            logger.info(f"Using persistent Chrome profile: {self.user_data_dir}")
        # Anti-bot masking so the automated session looks like a normal browser.
        chrome_options.add_argument('--disable-blink-features=AutomationControlled')
        chrome_options.add_experimental_option("excludeSwitches", ["enable-automation"])
        chrome_options.add_experimental_option("useAutomationExtension", False)

        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            try:
                self.driver.execute_cdp_cmd("Page.addScriptToEvaluateOnNewDocument", {
                    "source": "Object.defineProperty(navigator,'webdriver',{get:()=>undefined});"
                })
            except Exception as e:
                logger.warning(f"navigator.webdriver masking failed (non-fatal): {e}")
            logger.info("Chrome driver initialized (headful, masked)")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize driver: {e}")
            return False

    def navigate_to_ordering_hub(self) -> bool:
        """Navigate directly to OrderHub ordering hub with hash"""
        if self.logged_in:
            return True

        try:
            logger.info(f"Navigating to OrderHub: {mask_url(self.hub_url)}")
            self.driver.get(self.hub_url)

            logger.info("Waiting for ordering hub to fully load...")
            if not self._wait_for_hub_ready(timeout=60):
                logger.error("ordering hub did not fully load within timeout")
                return False

            logger.info("ordering hub fully loaded and ready")
            self.logged_in = True
            return True
        except Exception as e:
            logger.error(f"Navigation failed: {e}")
            return False

    def _wait_for_hub_ready(self, timeout=60):
        """Wait for the ordering hub to fully load after initial navigation.
        Checks 3 signals in sequence:
          1. Store input field exists and is clickable
          2. Grid day columns have rendered
          3. Brief settle time for Angular to finish binding
        Returns True when the page is ready for interaction."""
        wait = WebDriverWait(self.driver, timeout)
        try:
            logger.info("  Waiting for store input field...")
            wait.until(EC.element_to_be_clickable(
                (By.CSS_SELECTOR, "input[formcontrolname='customer']")
            ))
            logger.info("  Store input field is clickable")
        except Exception as e:
            logger.error(f"  Store input field never became clickable: {e}")
            self._report_cloudflare_block()
            return False

        try:
            logger.info("  Waiting for ordering grid to render...")
            wait.until(EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".div-content.day")
            ))
            logger.info("  Ordering grid rendered")
        except Exception as e:
            logger.warning(f"  Grid did not render (may still work): {e}")

        # Randomised human-like dwell before interacting (timing entropy only —
        # identity stays fixed). Replaces a flat 3s settle.
        time.sleep(random.uniform(2.5, 5.5))
        logger.info("  Page settle complete")
        return True

    def _report_cloudflare_block(self):
        """On hub-load failure, distinguish a Cloudflare bot challenge from a
        genuine hub UI change so the daemon logs an actionable cause rather
        than a blind Selenium timeout."""
        self.last_block_kind = 'unknown'
        try:
            title = (self.driver.title or "")
            src = (self.driver.page_source or "")
            markers = ["just a moment", "cdn-cgi/challenge-platform", "__cf_chl",
                       "turnstile", "checking your browser", "attention required"]
            if any(m in title.lower() or m in src.lower() for m in markers):
                self.last_block_kind = 'cloudflare'
                logger.error(
                    "  CLOUDFLARE BOT CHALLENGE detected (title=%r) — not a UI change. "
                    "Chrome must run headful (Xvfb), never --headless. "
                    "See project_hub_bot_challenge.", title)
            else:
                self.last_block_kind = 'ui_change'
                logger.error(
                    "  No Cloudflare markers (title=%r) — likely a genuine hub UI "
                    "revision; inspect the store-input selector.", title)
        except Exception as e:
            logger.warning(f"  Cloudflare-block diagnostic failed: {e}")

    def _wait_for_page_ready(self, timeout=30):
        """Wait for the hub page to finish loading after a store switch.
        Waits for the grid day columns to be present, which indicates the ordering
        grid has fully rendered for the selected store."""
        try:
            wait = WebDriverWait(self.driver, timeout)
            wait.until(EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".div-content.day")
            ))
            time.sleep(1)
            return True
        except Exception as e:
            logger.warning(f"Page ready wait timed out: {e}")
            return False

    def _dismiss_overlays(self):
        """Dismiss any overlays, dropdowns, or loading spinners blocking the page.
        Clicks the page body and presses Escape to close any open dropdowns."""
        try:
            self.driver.find_element(By.TAG_NAME, "body").click()
            time.sleep(0.5)
        except:
            pass
        try:
            from selenium.webdriver.common.action_chains import ActionChains
            ActionChains(self.driver).send_keys(Keys.ESCAPE).perform()
            time.sleep(0.5)
        except:
            pass

    def switch_to_store(self, store_id: str, store_name: str = None) -> bool:
        """
        Switch to any store using the store dropdown.
        Uses JavaScript clicks to avoid 'element click intercepted' errors from
        overlays/spinners, and WebDriverWait for store switch confirmation.
        """
        try:
            wait = WebDriverWait(self.driver, 30)

            self._dismiss_overlays()

            input_element = wait.until(EC.element_to_be_clickable(
                (By.CSS_SELECTOR, "input[formcontrolname='customer']")
            ))

            time.sleep(2)
            current_store = input_element.get_attribute("placeholder") or ""
            logger.info(f"Current store: {current_store}")

            if store_id in current_store:
                logger.info(f"Already on store {store_id}, no switch needed")
                self.target_store_id = store_id
                return True

            store_label = store_name or store_id
            logger.info(f"Switching to store: {store_label} (ID: {store_id})...")

            self.driver.execute_script("arguments[0].value = '';", input_element)
            self.driver.execute_script("arguments[0].dispatchEvent(new Event('input'));", input_element)
            time.sleep(1)

            self.driver.execute_script("arguments[0].focus();", input_element)
            self.driver.execute_script("arguments[0].click();", input_element)
            time.sleep(1)

            input_element.send_keys(store_id)
            logger.info(f"Typed store ID: {store_id}")
            time.sleep(3)

            autocomplete_options = wait.until(
                EC.presence_of_all_elements_located((By.CSS_SELECTOR, "mat-option"))
            )
            logger.info(f"Found {len(autocomplete_options)} autocomplete options")

            target_option = None
            for option in autocomplete_options:
                option_text = option.text.strip()
                logger.info(f"Option: {option_text}")
                if store_id in option_text:
                    target_option = option
                    break

            if not target_option:
                logger.error(f"Store {store_id} not found in autocomplete")
                return False

            logger.info(f"Clicking store option: {target_option.text}")
            try:
                target_option.click()
            except Exception:
                self.driver.execute_script("arguments[0].click();", target_option)

            logger.info("Waiting for page to reload after store switch...")
            self._wait_for_store_switch(store_id, timeout=45)

            self.target_store_id = store_id
            logger.info(f"Successfully switched to {store_label}!")
            return True

        except Exception as e:
            logger.error(f"Store switch failed: {e}")
            return False

    def _wait_for_store_switch(self, store_id: str, timeout=45):
        """Wait for the store switch to complete by checking multiple signals.
        Instead of a fixed sleep, polls for the page to settle after switching."""
        start_time = time.time()

        time.sleep(3)

        for attempt in range(3):
            try:
                wait = WebDriverWait(self.driver, timeout // 3)
                input_element = wait.until(EC.presence_of_element_located(
                    (By.CSS_SELECTOR, "input[formcontrolname='customer']")
                ))

                placeholder = input_element.get_attribute("placeholder") or ""
                value = input_element.get_attribute("value") or ""
                logger.info(f"Store switch check (attempt {attempt+1}): placeholder='{placeholder}', value='{value}'")

                if store_id in placeholder or store_id in value:
                    logger.info(f"Store switch confirmed via input field (attempt {attempt+1})")
                    self._wait_for_page_ready(timeout=20)
                    return True

            except Exception as e:
                logger.warning(f"Store switch check attempt {attempt+1} failed: {e}")

            if time.time() - start_time > timeout:
                break

            time.sleep(2)

        logger.info("Store input field not updated, checking if grid loaded instead...")
        try:
            wait = WebDriverWait(self.driver, 15)
            wait.until(EC.presence_of_element_located(
                (By.CSS_SELECTOR, ".div-content.day.current")
            ))
            logger.info("Grid loaded with current day marker - store switch likely successful")
            time.sleep(2)
            return True
        except:
            pass

        logger.info("Falling back: waiting for page to settle...")
        self._wait_for_page_ready(timeout=15)
        time.sleep(3)
        return True

    def search_product(self, product_id: str) -> bool:
        """Search for a product using the filter.
        Waits up to 15 seconds for the Filter input to appear (handles
        page reloads after week switches). Tries class anchor first
        (stable across hub copy changes), then placeholder fallbacks."""
        candidate_selectors = [
            "input.filter-input",
            "input[placeholder='Filter / Search']",
            "input[placeholder='Filter']",
        ]
        filter_input = None
        matched_selector = None
        try:
            wait = WebDriverWait(self.driver, 15)
            for selector in candidate_selectors:
                try:
                    filter_input = wait.until(EC.presence_of_element_located(
                        (By.CSS_SELECTOR, selector)
                    ))
                    matched_selector = selector
                    break
                except Exception:
                    continue

            if filter_input is None:
                for selector in candidate_selectors:
                    try:
                        filter_input = self.driver.find_element(By.CSS_SELECTOR, selector)
                        matched_selector = selector
                        break
                    except Exception:
                        continue

            if filter_input is None:
                inputs = self.driver.find_elements(By.TAG_NAME, "input")
                fingerprint = [
                    {
                        "placeholder": i.get_attribute("placeholder"),
                        "aria-label": i.get_attribute("aria-label"),
                        "class": i.get_attribute("class"),
                        "id": i.get_attribute("id"),
                    }
                    for i in inputs
                ]
                logger.error(f"No filter input matched. Page inputs: {fingerprint}")
                return False

            logger.info(f"Filter input matched via selector: {matched_selector}")
            filter_input.clear()
            filter_input.send_keys(product_id)
            filter_input.send_keys(Keys.RETURN)

            time.sleep(3)
            logger.info(f"Searched for product: {product_id}")
            return True
        except Exception as e:
            logger.error(f"Product search failed: {e}")
            return False

    def find_adj_row(self, product_id: str):
        """Find the ADJ row for a specific product"""
        try:
            time.sleep(2)

            adj_cells = self.driver.find_elements(By.CSS_SELECTOR, ".cell.adj.adjustable")

            logger.info(f"Found {len(adj_cells)} ADJ cells on page after searching for {product_id}")

            if adj_cells:
                return adj_cells[0].find_element(By.XPATH,
                                                 "./ancestor::tr | ./ancestor::div[contains(@class, 'product')]")

            logger.warning(f"No ADJ cells found after searching for product {product_id}")
            return None
        except Exception as e:
            logger.error(f"Error finding ADJ row: {e}")
            return None

    def click_single_adj_cell(self, cell_element, quantity: int) -> bool:
        """Click and edit a single ADJ cell element"""
        try:
            self.driver.execute_script("arguments[0].scrollIntoView(true);", cell_element)
            time.sleep(1)

            cell_element.click()
            time.sleep(2)

            try:
                input_field = cell_element.find_element(By.CSS_SELECTOR, "input[inputmode='numeric'][apphubcell]")
            except:
                input_field = cell_element.find_element(By.TAG_NAME, "input")

            logger.info(f"Entering quantity: {quantity}")
            print(f"DEBUG: Entering quantity: {quantity}")

            input_field.clear()
            time.sleep(0.5)
            input_field.send_keys(str(quantity))
            time.sleep(0.5)
            input_field.send_keys(Keys.RETURN)

            time.sleep(2)
            logger.info(f"Successfully entered {quantity} in ADJ cell")
            print(f"DEBUG: Successfully entered {quantity} in ADJ cell")
            return True

        except Exception as e:
            logger.error(f"Could not click/edit ADJ cell: {e}")
            print(f"DEBUG: ERROR clicking cell: {e}")
            return False

    def click_adj_cell_in_column(self, column_element, quantity: int) -> bool:
        """Find and click the adjustable ADJ cell within a specific column element"""
        try:
            print("DEBUG: === Starting click_adj_cell_in_column ===")
            logger.info("Starting click_adj_cell_in_column...")

            try:
                all_cells = column_element.find_elements(By.CSS_SELECTOR, ".cell")
                print(f"DEBUG: Column contains {len(all_cells)} cells")
                logger.info(f"Column contains {len(all_cells)} cells:")
                for i, cell in enumerate(all_cells):
                    cell_class = cell.get_attribute("class")
                    print(f"DEBUG:   Cell {i}: {cell_class}")
                    logger.info(f"  Cell {i}: {cell_class}")
            except Exception as e:
                print(f"DEBUG: FAILED to enumerate cells: {e}")
                logger.error(f"Failed to enumerate cells: {e}")
                raise

            print("DEBUG: Looking for .cell.adj.adjustable...")
            logger.info("Looking for .cell.adj.adjustable...")
            target_cell = column_element.find_element(By.CSS_SELECTOR, ".cell.adj.adjustable")
            print("DEBUG: Found adjustable ADJ cell!")
            logger.info(f"Found adjustable ADJ cell in column")

            self.driver.execute_script("arguments[0].scrollIntoView(true);", target_cell)
            time.sleep(1)

            target_cell.click()
            time.sleep(2)

            try:
                input_field = target_cell.find_element(By.CSS_SELECTOR, "input[inputmode='numeric'][apphubcell]")
            except:
                input_field = target_cell.find_element(By.TAG_NAME, "input")

            logger.info(f"Entering quantity: {quantity}")

            input_field.clear()
            time.sleep(0.5)
            input_field.send_keys(str(quantity))
            time.sleep(0.5)
            input_field.send_keys(Keys.RETURN)

            time.sleep(2)
            logger.info(f"Successfully entered {quantity} in ADJ cell")
            return True

        except Exception as e:
            logger.error(f"Could not find/click adjustable ADJ cell in column: {e}")
            return False

    def click_adj_cell(self, product_id: str, date_offset: int, quantity: int) -> bool:
        """
        Click and edit the ADJ cell for a product on a specific date
        Uses 'current day' anchor point and counts forward by date_offset
        """
        try:
            logger.info(f"Looking for ADJ cell at offset +{date_offset} from current day")

            try:
                current_day_column = self.driver.find_element(
                    By.CSS_SELECTOR,
                    ".div-content.day.current"
                )
                logger.info(f"Found current day column")
            except Exception as e:
                logger.error(f"Could not find 'current day' column after filtering!")
                logger.error(f"Error: {e}")
                all_day_columns = self.driver.find_elements(By.CSS_SELECTOR, ".div-content.day")
                logger.info(f"Found {len(all_day_columns)} total day columns")
                return False

            target_column = current_day_column

            if date_offset > 0:
                for i in range(date_offset):
                    try:
                        target_column = target_column.find_element(
                            By.XPATH,
                            "./following-sibling::div[contains(@class, 'day')]"
                        )
                        logger.info(f"  Moved to column +{i + 1}")
                    except:
                        logger.error(f"Could not navigate to column +{i + 1}")
                        return False
            elif date_offset < 0:
                for i in range(abs(date_offset)):
                    try:
                        target_column = target_column.find_element(
                            By.XPATH,
                            "./preceding-sibling::div[contains(@class, 'day')]"
                        )
                        logger.info(f"  Moved to column -{i + 1}")
                    except:
                        logger.error(f"Could not navigate to column -{i + 1}")
                        return False

            logger.info(f"Reached target column at offset {date_offset}")

            try:
                all_cells = target_column.find_elements(By.CSS_SELECTOR, ".cell")
                logger.info(f"  Column contains {len(all_cells)} total cells")
                for cell in all_cells:
                    cell_class = cell.get_attribute("class")
                    logger.info(f"    Cell class: {cell_class}")
            except Exception as e:
                logger.warning(f"  Could not enumerate cells: {e}")

            try:
                target_cell = target_column.find_element(
                    By.CSS_SELECTOR,
                    ".cell-col .cell.adj.adjustable"
                )
                logger.info(f"Found adjustable ADJ cell in target column")
            except:
                try:
                    target_cell = target_column.find_element(
                        By.CSS_SELECTOR,
                        ".cell.adj.adjustable"
                    )
                    logger.info(f"Found adjustable ADJ cell (no cell-col wrapper)")
                except:
                    logger.error(f"No adjustable ADJ cell found in target column (date may be locked/gray)")
                    return False

            self.driver.execute_script("arguments[0].scrollIntoView(true);", target_cell)
            time.sleep(1)

            target_cell.click()
            time.sleep(2)

            try:
                input_field = target_cell.find_element(
                    By.CSS_SELECTOR,
                    "input[inputmode='numeric'][apphubcell]"
                )
            except:
                input_field = target_cell.find_element(By.TAG_NAME, "input")

            logger.info(f"Entering quantity: {quantity}")

            input_field.clear()
            time.sleep(0.5)
            input_field.send_keys(str(quantity))
            time.sleep(0.5)
            input_field.send_keys(Keys.RETURN)

            time.sleep(2)
            logger.info(f"Successfully set ADJ cell for product {product_id} to {quantity}")
            return True

        except Exception as e:
            logger.error(f"Error clicking ADJ cell: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False

    def place_order(self, product_id: str, quantity: int, date_offset: int = 0) -> dict:
        """
        Place an order for a product on a specific date

        Args:
            product_id: Product SKU/ID
            quantity: Number of units to order
            date_offset: Days from today (0=today, 1=tomorrow, etc.)

        Returns:
            dict with success status and message
        """
        try:
            if not self.setup_driver():
                return {'success': False, 'error': 'Failed to setup driver'}

            if not self.logged_in:
                if not self.navigate_to_ordering_hub():
                    return {'success': False, 'error': 'Failed to navigate to OrderHub'}

                if not self.switch_to_store(self.target_store_id, "IGA BLACKFALDS"):
                    return {'success': False, 'error': f'Failed to switch to store {self.target_store_id}'}

            target_date = datetime.now() + timedelta(days=date_offset)
            date_str = target_date.strftime("%b %-d, %Y")

            logger.info(f"Placing order: Product {product_id}, Qty {quantity}, Date {date_str}")

            try:
                current_day_col = self.driver.find_element(By.CSS_SELECTOR, ".div-content.day.current")
                logger.info("Found 'current day' column before filtering")
            except:
                logger.error("Could not find 'current day' column")
                return {'success': False, 'error': 'Could not find current day marker on page'}

            all_day_columns = self.driver.find_elements(By.CSS_SELECTOR, ".div-content.day")
            logger.info(f"Found {len(all_day_columns)} day columns before filtering")

            current_day_index = -1
            for i, col in enumerate(all_day_columns):
                if "current" in col.get_attribute("class"):
                    current_day_index = i
                    logger.info(f"Current day is at column index {i}")
                    break

            if current_day_index == -1:
                return {'success': False, 'error': 'Could not determine current day index'}

            target_col_index = current_day_index + date_offset
            logger.info(f"Target column index: {target_col_index} (current {current_day_index} + offset {date_offset})")

            if target_col_index < 0 or target_col_index >= len(all_day_columns):
                return {'success': False, 'error': f'Target date out of range (column {target_col_index})'}

            if not self.search_product(product_id):
                return {'success': False, 'error': f'Failed to search for product {product_id}'}

            logger.info(f"Product {product_id} filtered successfully")

            logger.info("Finding ADJ cells after filtering...")
            print("DEBUG: Finding ADJ row after filtering...")

            time.sleep(2)

            all_adj_cells = self.driver.find_elements(By.CSS_SELECTOR, ".cell.adj")
            logger.info(f"Found {len(all_adj_cells)} total ADJ cells")
            print(f"DEBUG: Found {len(all_adj_cells)} total ADJ cells")

            adj_cells = []
            for i, cell in enumerate(all_adj_cells):
                cell_class = cell.get_attribute("class")
                class_list = cell_class.split()
                print(f"DEBUG:   ADJ cell {i}: {cell_class}")

                if "adjustable" in class_list or "unadjustable" in class_list or "featured" in class_list:
                    adj_cells.append(cell)
                else:
                    print(f"DEBUG:     Skipping Week Totals column at index {i}")

            logger.info(f"After filtering Week Totals: {len(adj_cells)} date cells")
            print(f"DEBUG: After filtering out Week Totals: {len(adj_cells)} date cells remaining")

            if target_col_index >= len(adj_cells):
                return {'success': False,
                        'error': f'Target column {target_col_index} out of range (only {len(adj_cells)} ADJ cells found)'}

            target_cell = adj_cells[target_col_index]
            cell_class = target_cell.get_attribute("class")
            print(f"DEBUG: Target ADJ cell (index {target_col_index}) class: {cell_class}")

            class_list = cell_class.split()
            if "adjustable" not in class_list:
                print(f"DEBUG: Cell at index {target_col_index} is LOCKED (not adjustable)")
                logger.warning(f"Cell at index {target_col_index} is not adjustable")
                return {'success': False, 'error': f'Date {date_str} is locked/committed (not adjustable)'}

            if "unadjustable" in class_list:
                print(f"DEBUG: Cell at index {target_col_index} is LOCKED (unadjustable)")
                logger.warning(f"Cell at index {target_col_index} is unadjustable")
                return {'success': False, 'error': f'Date {date_str} is locked/committed (already committed)'}

            logger.info(f"Clicking adjustable ADJ cell for {date_str}")
            print(f"DEBUG: Cell is adjustable! Clicking it now...")

            if not self.click_single_adj_cell(target_cell, quantity):
                return {'success': False, 'error': f'Failed to edit ADJ cell for {date_str}.'}

            return {
                'success': True,
                'product_id': product_id,
                'quantity': quantity,
                'date': date_str,
                'message': f"Successfully placed order: {quantity} units of {product_id} for {date_str}"
            }

        except Exception as e:
            logger.error(f"Order placement failed: {e}")
            return {'success': False, 'error': str(e)}

    def close(self):
        """Close the browser"""
        if self.driver:
            self.driver.quit()
            self.driver = None
            self.logged_in = False
            logger.info("Browser closed")
        if self._virtual_display:
            try:
                self._virtual_display.stop()
                logger.info("Xvfb virtual display stopped")
            except Exception as e:
                logger.warning(f"Failed to stop virtual display: {e}")
            self._virtual_display = None


class OrderHubScraper(OrderHubTool):
    """
    Scraper for reading committed/greyed cells from OrderHub
    Extends OrderHubTool to reuse browser and navigation infrastructure
    """

    def __init__(self, headless=True, hub_url=None, user_data_dir=None):
        """Initialize scraper (defaults to headless mode for automation)"""
        super().__init__(headless=headless, hub_url=hub_url, user_data_dir=user_data_dir)

    def get_day_columns_with_dates(self) -> list:
        """
        Get all day columns with their dates (robust column-to-date mapping)

        Returns:
            list of dicts: [{'column_element': WebElement, 'date': 'YYYY-MM-DD', 'day_name': 'Monday'}]
        """
        try:
            import re
            from dateutil import parser

            day_columns = self.driver.find_elements(By.CSS_SELECTOR, ".div-content.day")

            if not day_columns:
                raise Exception("No day columns found on page")

            logger.info(f"Found {len(day_columns)} day columns")

            result = []
            current_year = datetime.now().year

            for col_elem in day_columns:
                try:
                    date_str = None

                    date_str = col_elem.get_attribute("data-date")

                    if not date_str:
                        try:
                            date_elem = col_elem.find_element(By.CSS_SELECTOR, ".date, .header-date, [class*='date']")
                            date_text = date_elem.text.strip()

                            if date_text:
                                parsed = parser.parse(date_text, default=datetime(current_year, 1, 1))
                                date_str = parsed.strftime('%Y-%m-%d')
                        except:
                            pass

                    if not date_str:
                        col_text = col_elem.text.strip()

                        if 'Week' in col_text or 'Totals' in col_text or 'bookmark' in col_text:
                            continue

                        date_pattern = r'([A-Za-z]+)[\s-]+(\d{1,2})'
                        match = re.search(date_pattern, col_text)

                        if match:
                            try:
                                parsed = parser.parse(f"{match.group(1)} {match.group(2)}, {current_year}")
                                date_str = parsed.strftime('%Y-%m-%d')
                            except:
                                pass

                    if date_str:
                        day_name = datetime.strptime(date_str, '%Y-%m-%d').strftime('%A')

                        result.append({
                            'column_element': col_elem,
                            'date': date_str,
                            'day_name': day_name
                        })

                        logger.info(f"  Column: {day_name} {date_str}")
                    else:
                        logger.warning(f"  Skipping column - could not extract date")

                except Exception as e:
                    logger.warning(f"  Error parsing column: {e}")
                    continue

            if len(result) == 0:
                raise Exception("Could not parse any date columns - scraping failed")

            logger.info(f"Successfully mapped {len(result)} columns to dates")
            return result

        except Exception as e:
            logger.error(f"Fatal error in get_day_columns_with_dates: {e}")
            raise

    def is_cell_greyed(self, cell_element) -> bool:
        """
        Determine if a cell is greyed/committed (robust detection)
        """
        try:
            cell_class = cell_element.get_attribute("class") or ""

            if "unadjustable" in cell_class:
                return True
            if "committed" in cell_class:
                return True
            if "locked" in cell_class:
                return True

            try:
                input_elem = cell_element.find_element(By.TAG_NAME, "input")

                if input_elem.get_attribute("readonly"):
                    return True
                if input_elem.get_attribute("disabled"):
                    return True

                if input_elem.get_attribute("aria-disabled") == "true":
                    return True
                if input_elem.get_attribute("aria-readonly") == "true":
                    return True
            except:
                pass

            if cell_element.get_attribute("data-locked") == "true":
                return True
            if cell_element.get_attribute("data-committed") == "true":
                return True

            return False

        except Exception as e:
            logger.warning(f"Error checking if cell is greyed: {e}")
            return False

    def scrape_product_row(self, product_id: str) -> dict:
        """
        Scrape all cells (committed and uncommitted) for a single product
        """
        try:
            logger.info(f"Scraping product row for: {product_id}")

            if not self.driver:
                raise Exception("Driver not initialized - call setup_driver() and navigate_to_ordering_hub() first!")

            if not self.search_product(product_id):
                raise Exception(f'Failed to search for product {product_id}')

            time.sleep(3)

            day_columns = self.get_day_columns_with_dates()

            if not day_columns:
                raise Exception("No day columns found - cannot scrape product row")

            all_dates = {}
            greyed_cells = {}

            for col_info in day_columns:
                try:
                    col_elem = col_info['column_element']
                    date_str = col_info['date']
                    day_name = col_info['day_name']

                    adj_cell = None

                    try:
                        adj_cell = col_elem.find_element(By.CSS_SELECTOR, ".cell-col .cell.adj")
                    except:
                        try:
                            adj_cell = col_elem.find_element(By.CSS_SELECTOR, ".cell.adj")
                        except:
                            logger.warning(f"  No ADJ cell found for {day_name} {date_str}")
                            continue

                    if not adj_cell:
                        continue

                    value_text = adj_cell.text.strip()

                    if not value_text or not value_text.isdigit():
                        try:
                            input_elem = adj_cell.find_element(By.TAG_NAME, "input")
                            value_text = input_elem.get_attribute("value") or "0"
                        except:
                            value_text = "0"

                    quantity = int(value_text) if value_text.isdigit() else 0

                    all_dates[date_str] = quantity

                    is_greyed = self.is_cell_greyed(adj_cell)

                    if is_greyed:
                        greyed_cells[date_str] = quantity
                        logger.info(f"  {day_name} {date_str}: {quantity} units [GREYED]")
                    else:
                        logger.info(f"  {day_name} {date_str}: {quantity} units [editable]")

                except Exception as e:
                    logger.warning(f"  Error processing column {col_info.get('day_name', '?')}: {e}")
                    continue

            if len(all_dates) == 0:
                raise Exception("No cells scraped - scraping failed completely")

            return {
                'success': True,
                'product_id': product_id,
                'all_dates': all_dates,
                'greyed_cells': greyed_cells,
                'total_cells': len(all_dates),
                'total_greyed': len(greyed_cells)
            }

        except Exception as e:
            logger.error(f"Error scraping product row: {e}")
            raise

    def read_pipeline(self, product_id: str, store_id: str = '70012004',
                     tray_factor: int = 1) -> dict:
        """
        Read the hub pipeline for a product: scan the grid, extract F.O. values
        from locked/committed dates, identify adjustable dates for MLP decisions.

        hub grid structure (4 layers of .div-content.day elements):
          Layer 1 (cols 0-N):   Date headers ("Feb-25 Wed", "Week 9 Totals")
          Layer 2 (cols N+1):   Bookmark icons ("bookmark_border")
          Layer 3 (cols 2N+1):  Product data rows (S.O., ADJ, F.O., SFO cells)
          Layer 4 (cols 3N+1):  Grand Totals row (large aggregate numbers)

        This method reads ONLY Layer 1 (dates) and Layer 3 (product F.O./ADJ),
        maps them by position, and ignores bookmarks and grand totals.

        All values are in raw pieces as shown on the hub (no tray multiplication).

        Returns:
            dict with:
              - pipeline_incoming: total locked F.O. pieces in pipeline
              - locked_dates: {date: {fo_value, column_index}} for committed dates
              - adjustable_dates: [{date, dow, column_index, fo_value}] for editable dates
              - tray_factor_detected: tray factor shown on hub page (for reference)
        """
        try:
            import re
            logger.info(f"Reading pipeline for product {product_id} at store {store_id}")

            if not self.setup_driver():
                return {'success': False, 'error': 'Failed to initialize Chrome driver'}

            if not self.logged_in:
                if not self.navigate_to_ordering_hub():
                    return {'success': False, 'error': 'Failed to navigate to OrderHub'}

            if store_id != self.target_store_id:
                if not self.switch_to_store(store_id):
                    return {'success': False, 'error': f'Failed to switch to store {store_id}'}

            if not self.search_product(product_id):
                return {'success': False, 'error': f'Failed to search for product {product_id}'}

            time.sleep(3)

            all_day_cols = self.driver.find_elements(By.CSS_SELECTOR, ".div-content.day")
            if not all_day_cols:
                return {'success': False, 'error': 'No day columns found on hub grid'}

            logger.info(f"Total .div-content.day elements found: {len(all_day_cols)}")

            header_cols = []
            bookmark_cols = []
            product_cols = []
            other_cols = []

            for i, col in enumerate(all_day_cols):
                col_text = col.text.strip()

                if 'bookmark' in col_text.lower():
                    bookmark_cols.append((i, col))
                    continue

                has_fo_cell = False
                try:
                    col.find_element(By.CSS_SELECTOR, ".cell.fo")
                    has_fo_cell = True
                except:
                    pass

                date_match = re.search(r'[A-Za-z]{3}-\d{1,2}', col_text)
                week_match = 'Week' in col_text or 'Totals' in col_text

                if (date_match or week_match) and not has_fo_cell:
                    header_cols.append((i, col, col_text))
                elif has_fo_cell:
                    product_cols.append((i, col, col_text))
                else:
                    other_cols.append((i, col, col_text))

            logger.info(f"Grid layers: {len(header_cols)} headers, {len(bookmark_cols)} bookmarks, "
                        f"{len(product_cols)} product data, {len(other_cols)} other/totals")

            date_headers = []
            header_week_total_positions = set()
            for seq, (idx, col, text) in enumerate(header_cols):
                if 'Week' in text or 'Totals' in text:
                    header_week_total_positions.add(seq)
                    continue
                date_match = re.search(r'([A-Za-z]{3})-(\d{1,2})\s+([A-Za-z]{3})', text)
                if date_match:
                    month_str = date_match.group(1)
                    day_num = date_match.group(2)
                    dow_str = date_match.group(3)
                    try:
                        parsed = datetime.strptime(f"{month_str} {day_num} {datetime.now().year}", "%b %d %Y")
                        date_str = parsed.strftime('%Y-%m-%d')
                        date_headers.append({
                            'date': date_str,
                            'dow': dow_str,
                            'header_index': idx,
                            'header_seq': seq,
                            'is_current': "current" in (col.get_attribute("class") or ""),
                        })
                    except:
                        date_headers.append({
                            'date': f"col_{idx}",
                            'dow': dow_str,
                            'header_index': idx,
                            'header_seq': seq,
                            'is_current': "current" in (col.get_attribute("class") or ""),
                        })

            logger.info(f"Parsed {len(date_headers)} date headers, "
                        f"{len(header_week_total_positions)} week total columns to skip")

            product_data_only = []
            for seq, (idx, col, text) in enumerate(product_cols):
                if seq in header_week_total_positions:
                    logger.info(f"  Skipping product col {idx} (seq {seq}) as week total")
                    continue
                product_data_only.append((idx, col, text))

            logger.info(f"Product data columns (excluding week totals): {len(product_data_only)}")

            today_header_pos = -1
            for pos, hdr in enumerate(date_headers):
                if hdr['is_current']:
                    today_header_pos = pos
                    break

            locked_dates = {}
            adjustable_dates = []
            delivered_dates = []
            pipeline_incoming = 0

            num_to_pair = min(len(date_headers), len(product_data_only))

            for pos in range(num_to_pair):
                hdr = date_headers[pos]
                data_col_idx, data_col, data_text = product_data_only[pos]

                date_str = hdr['date']
                is_current = hdr['is_current']
                is_future = (pos > today_header_pos) if today_header_pos >= 0 else False
                is_past = (pos < today_header_pos) if today_header_pos >= 0 else False

                fo_value = 0
                fo_raw = ''
                is_locked = False
                is_adjustable = False

                try:
                    fo_cell = data_col.find_element(By.CSS_SELECTOR, ".cell.fo")
                    fo_raw = fo_cell.text.strip()
                    fo_first_line = fo_raw.split('\n')[0].strip()
                    if fo_first_line and fo_first_line.replace('-', '').replace('.', '').isdigit():
                        fo_value = int(float(fo_first_line))
                except:
                    pass

                # ── Read S.O. cell ──
                so_value = 0
                so_raw = ''
                try:
                    so_cell = data_col.find_element(By.CSS_SELECTOR, ".cell.so")
                    so_raw = so_cell.text.strip()
                    so_text = so_raw.split('\n')[0].strip()
                    if not so_text or not so_text.replace('-', '').replace('.', '').isdigit():
                        try:
                            inp = so_cell.find_element(By.TAG_NAME, "input")
                            so_text = inp.get_attribute("value") or "0"
                        except:
                            so_text = "0"
                    so_value = int(float(so_text)) if so_text.replace('-', '').replace('.', '').isdigit() else 0
                except:
                    pass

                # ── Read ADJ cell ──
                adj_value = 0
                adj_raw = ''
                adj_class_str = ''
                has_filler = False
                try:
                    adj_cell = data_col.find_element(By.CSS_SELECTOR, ".cell.adj")
                    adj_class_str = adj_cell.get_attribute("class") or ""
                    adj_raw = adj_cell.text.strip()

                    try:
                        data_col.find_element(By.CSS_SELECTOR, ".filler-button")
                        has_filler = True
                    except:
                        pass

                    if has_filler or "unadjustable" in adj_class_str:
                        is_locked = True
                    elif "adjustable" in adj_class_str:
                        is_adjustable = True
                        adj_text = adj_raw
                        if not adj_text or not adj_text.replace('-', '').replace('.', '').isdigit():
                            try:
                                inp = adj_cell.find_element(By.TAG_NAME, "input")
                                adj_text = inp.get_attribute("value") or "0"
                            except:
                                adj_text = "0"
                        adj_value = int(float(adj_text)) if adj_text.replace('-', '').replace('.', '').isdigit() else 0
                except:
                    pass

                time_label = 'PAST' if is_past else ('TODAY' if is_current else 'FUTURE')
                cell_label = 'LOCKED' if is_locked else ('ADJ' if is_adjustable else 'NONE')
                logger.info(f"  [DEBUG] {date_str} ({hdr['dow']}) pos={pos} {time_label} | "
                            f"S.O.={so_value} | F.O.raw='{fo_raw}' val={fo_value} | "
                            f"ADJ.raw='{adj_raw}' val={adj_value} | "
                            f"cell={cell_label} filler={has_filler} adj_class='{adj_class_str}' "
                            f"[col {data_col_idx}]")

                if (is_past or is_current) and fo_value > 0:
                    delivered_dates.append({
                        'date': date_str,
                        'dow': hdr['dow'],
                        'fo_value': fo_value,
                        'adj_value': adj_value,
                        'total_delivered': fo_value,
                        'date_position': pos,
                    })
                    logger.info(f"  Delivered: {date_str} ({hdr['dow']}) F.O.={fo_value} (S.O.+ADJ)")

                if is_future and fo_value > 0 and is_locked:
                    pipeline_incoming += fo_value

                if is_locked and fo_value > 0 and is_future:
                    locked_dates[date_str] = {
                        'fo_value': fo_value,
                        'column_index': data_col_idx,
                        'date_position': pos,
                    }
                    logger.info(f"  Locked: {date_str} ({hdr['dow']}) F.O.={fo_value}  [col {data_col_idx}]")

                if is_adjustable:
                    offset = (pos - today_header_pos) if today_header_pos >= 0 else pos
                    adjustable_dates.append({
                        'date': date_str,
                        'dow': hdr['dow'],
                        'column_index': data_col_idx,
                        'offset_from_today': offset,
                        'fo_value': fo_value,
                        'current_adj': adj_value,
                        'current_so': so_value,
                        'date_position': pos,
                    })
                    adj_note = f", ADJ={adj_value}" if adj_value > 0 else ""
                    so_note = f", S.O.={so_value}" if so_value > 0 else ""
                    logger.info(f"  Adjustable: {date_str} ({hdr['dow']}) offset +{offset}, "
                                f"F.O.={fo_value}{adj_note}{so_note}  [col {data_col_idx}]")

            tf_detected = None
            try:
                page_text = self.driver.find_element(By.TAG_NAME, "body").text
                tf_match = re.search(r'TF\s+(\d+)', page_text)
                if tf_match:
                    tf_detected = int(tf_match.group(1))
                    logger.info(f"Detected tray factor from page: TF {tf_detected}")
            except:
                pass

            return_rate_pct = None
            try:
                page_text = self.driver.find_element(By.TAG_NAME, "body").text
                rtn_match = re.search(r'(\d+\.?\d*)\s*%', page_text)
                if rtn_match:
                    return_rate_pct = float(rtn_match.group(1))
            except:
                pass

            today_date = date_headers[today_header_pos]['date'] if today_header_pos >= 0 else None

            delivered_total = sum(d['total_delivered'] for d in delivered_dates)
            logger.info(f"Delivered (past+today): {delivered_total} pieces across {len(delivered_dates)} dates")
            logger.info(f"Pipeline (future): {pipeline_incoming} pieces incoming")

            result = {
                'success': True,
                'product_id': product_id,
                'store_id': store_id,
                'today': today_date,
                'pipeline_incoming': pipeline_incoming,
                'locked_dates': locked_dates,
                'adjustable_dates': adjustable_dates,
                'delivered_dates': delivered_dates,
                'delivered_total': delivered_total,
                'tray_factor_detected': tf_detected,
                'four_week_return_pct': return_rate_pct,
                'total_date_columns': len(date_headers),
                'today_position': today_header_pos,
                'message': (
                    f"Pipeline: {pipeline_incoming} pieces incoming across {len(locked_dates)} locked dates. "
                    f"{len(adjustable_dates)} dates available for MLP adjustment."
                )
            }

            logger.info(f"Pipeline read complete: {result['message']}")
            return result

        except Exception as e:
            logger.error(f"Pipeline read failed: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return {'success': False, 'error': str(e), 'product_id': product_id}

    def _find_week_form_field(self):
        """
        Find the mat-form-field element that contains the 'Week' label.
        The hub has multiple mat-select dropdowns (Route, Customers, Week) —
        we specifically need the one labeled 'Week'.

        The Week form field has:
          - class 'week' on the mat-form-field
          - formcontrolname='week' on the mat-select
          - mat-label text = 'Week'

        Returns:
            (mat_form_field_element, mat_select_element) or (None, None)
        """
        try:
            try:
                ff = self.driver.find_element(By.CSS_SELECTOR, "mat-form-field.week")
                select = ff.find_element(By.CSS_SELECTOR, "mat-select")
                logger.info("Found Week form field via mat-form-field.week")
                return (ff, select)
            except:
                pass

            try:
                select = self.driver.find_element(
                    By.CSS_SELECTOR, "mat-select[formcontrolname='week']"
                )
                ff = select.find_element(By.XPATH, "./ancestor::mat-form-field")
                logger.info("Found Week form field via formcontrolname='week'")
                return (ff, select)
            except:
                pass

            form_fields = self.driver.find_elements(By.CSS_SELECTOR, "mat-form-field")
            for ff in form_fields:
                try:
                    labels = ff.find_elements(By.CSS_SELECTOR, "mat-label")
                    for label in labels:
                        label_text = label.text.strip()
                        if label_text == 'Week':
                            select = ff.find_element(By.CSS_SELECTOR, "mat-select")
                            logger.info(f"Found Week form field (label='{label_text}')")
                            return (ff, select)
                except:
                    continue

            logger.warning("Could not find Week form field")
            return (None, None)

        except Exception as e:
            logger.error(f"Error finding Week form field: {e}")
            return (None, None)

    def get_current_week_number(self) -> tuple:
        """
        Read the current week number from the hub Week dropdown.
        Specifically targets the mat-form-field labeled 'Week' to avoid
        reading the Route or Customers dropdown values.

        Returns:
            (current_week: int, is_current_label: bool)
            e.g. (10, True) means "Week 10 (Current)" is selected
        """
        try:
            import re

            _, week_select = self._find_week_form_field()
            if week_select:
                value_spans = week_select.find_elements(
                    By.CSS_SELECTOR,
                    ".mat-mdc-select-value-text, .mat-select-value-text"
                )
                for span in value_spans:
                    text = span.text.strip()
                    if text:
                        is_current = '(Current)' in text or 'Current' in text
                        num_match = re.search(r'(\d+)', text)
                        if num_match:
                            week_num = int(num_match.group(1))
                            logger.info(f"Current the hub week: {week_num}"
                                         f"{' (Current)' if is_current else ''}")
                            return (week_num, is_current)

                select_text = week_select.text.strip()
                if select_text:
                    is_current = '(Current)' in select_text
                    num_match = re.search(r'(\d+)', select_text)
                    if num_match:
                        week_num = int(num_match.group(1))
                        logger.info(f"Current the hub week (from select text): {week_num}"
                                     f"{' (Current)' if is_current else ''}")
                        return (week_num, is_current)

            logger.warning("Could not read current week number from Week dropdown")
            return (None, False)

        except Exception as e:
            logger.error(f"Error reading week number: {e}")
            return (None, False)

    def _find_week_dropdown(self):
        """
        Find the week dropdown mat-select element.
        Tries the direct class selector first, then falls back to scanning
        all mat-select elements for one showing a week number or '(Current)'.

        Returns:
            WebElement or None
        """
        _, week_select = self._find_week_form_field()
        if week_select:
            return week_select

        import re
        all_selects = self.driver.find_elements(By.CSS_SELECTOR, "mat-select")
        for sel in all_selects:
            try:
                sel_text = sel.text.strip()
                if '(Current)' in sel_text:
                    logger.info(f"Found week dropdown via '(Current)' text: '{sel_text}'")
                    return sel
                if re.match(r'^\d{1,2}$', sel_text):
                    logger.info(f"Found week dropdown via numeric text: '{sel_text}'")
                    return sel
            except:
                continue

        logger.warning("Could not find week dropdown")
        return None

    def _select_week_option(self, target_week: int) -> bool:
        """
        Select a specific week number from the open dropdown panel.
        The dropdown must already be open (call _open_week_dropdown first).

        The hub uses Angular Material CDK overlays — the dropdown panel appears
        inside a .cdk-overlay-pane, not inside the mat-form-field.

        Args:
            target_week: Week number to select (e.g. 11)

        Returns:
            True if selection succeeded
        """
        try:
            import re
            time.sleep(1)

            options = []

            overlay_panes = self.driver.find_elements(
                By.CSS_SELECTOR, ".cdk-overlay-pane"
            )
            for pane in overlay_panes:
                try:
                    if not pane.is_displayed():
                        continue
                    pane_options = pane.find_elements(By.CSS_SELECTOR, "mat-option")
                    if pane_options:
                        options = pane_options
                        logger.info(f"Found {len(options)} options in CDK overlay pane")
                        break
                except:
                    continue

            if not options:
                panel_selectors = [
                    ".mat-mdc-select-panel",
                    ".mat-select-panel",
                    "[role='listbox']",
                ]
                for sel in panel_selectors:
                    try:
                        panels = self.driver.find_elements(By.CSS_SELECTOR, sel)
                        for p in panels:
                            if p.is_displayed():
                                options = p.find_elements(By.CSS_SELECTOR, "mat-option")
                                if options:
                                    logger.info(f"Found {len(options)} options via {sel}")
                                    break
                    except:
                        continue
                    if options:
                        break

            if not options:
                options = self.driver.find_elements(
                    By.CSS_SELECTOR, "mat-option"
                )
                visible_options = [o for o in options if o.is_displayed()]
                if visible_options:
                    options = visible_options
                    logger.info(f"Found {len(options)} visible mat-option elements (global)")

            if not options:
                logger.error("No dropdown options found — is the dropdown open?")
                logger.info("Dumping CDK overlay state for debugging...")
                all_overlays = self.driver.find_elements(By.CSS_SELECTOR, ".cdk-overlay-pane")
                for i, ov in enumerate(all_overlays):
                    try:
                        logger.info(f"  Overlay {i}: displayed={ov.is_displayed()}, "
                                     f"text='{ov.text.strip()[:80]}'")
                    except:
                        pass
                self._dismiss_overlays()
                return False

            available = []
            target_str = str(target_week)
            for opt in options:
                opt_text = opt.text.strip()
                available.append(opt_text)
                num_match = re.search(r'^(\d+)', opt_text)
                if num_match and num_match.group(1) == target_str:
                    logger.info(f"Selecting week option: '{opt_text}'")
                    self.driver.execute_script("arguments[0].scrollIntoView(true);", opt)
                    time.sleep(0.3)
                    opt.click()
                    time.sleep(3)
                    logger.info(f"Selected week {target_week} — waiting for grid reload")
                    return True

            logger.error(f"Week {target_week} not found in dropdown. "
                          f"Available: {available}")
            self._dismiss_overlays()
            return False

        except Exception as e:
            logger.error(f"Error selecting week option: {e}")
            self._dismiss_overlays()
            return False

    def navigate_to_week(self, target_week: int) -> bool:
        """
        Navigate to a specific week number using the hub Week dropdown.
        Uses JavaScript clicks (proven reliable with Angular Material).

        Args:
            target_week: Week number to navigate to (e.g. 11)

        Returns:
            True if navigation succeeded
        """
        import re
        try:
            week_dropdown = self._find_week_dropdown()
            if not week_dropdown:
                logger.error("Could not find week dropdown — navigation failed")
                return False

            current_text = week_dropdown.text.strip()
            logger.info(f"Week paginator current: '{current_text}'")

            current_match = re.search(r'(\d+)', current_text)
            if current_match:
                current_num = int(current_match.group(1))
                if current_num == target_week:
                    logger.info(f"Already on week {target_week} — no navigation needed")
                    return True

            self.driver.execute_script("arguments[0].scrollIntoView(true);", week_dropdown)
            time.sleep(1)
            self.driver.execute_script("arguments[0].click();", week_dropdown)
            time.sleep(2)

            options = self.driver.find_elements(By.CSS_SELECTOR, "mat-option")
            logger.info(f"Dropdown options found: {len(options)}")

            clicked = False
            target_str = str(target_week)
            for opt in options:
                opt_text = opt.text.strip()
                opt_match = re.search(r'(\d+)', opt_text)
                if opt_match and opt_match.group(1) == target_str:
                    self.driver.execute_script("arguments[0].click();", opt)
                    logger.info(f"Advanced week paginator: '{current_text}' -> Week {target_week}")
                    clicked = True
                    break

            if not clicked:
                available = [opt.text.strip() for opt in options]
                logger.warning(f"Week {target_week} not found in dropdown. "
                                f"Available: {available}")
                body = self.driver.find_element(By.TAG_NAME, "body")
                body.click()
                time.sleep(1)
                return False

            time.sleep(5)
            return True

        except Exception as e:
            logger.error(f"Week navigation failed: {e}")
            return False

    def navigate_week(self, direction='forward') -> bool:
        """
        Navigate one week forward or backward using the hub Week dropdown.

        Args:
            direction: 'forward' for next week, 'backward' for previous week

        Returns:
            True if navigation succeeded
        """
        import re
        week_dropdown = self._find_week_dropdown()
        if not week_dropdown:
            logger.error("Cannot find week dropdown — navigation failed")
            return False

        current_text = week_dropdown.text.strip()
        current_match = re.search(r'(\d+)', current_text)
        if not current_match:
            logger.error(f"Cannot parse week number from '{current_text}'")
            return False

        current_num = int(current_match.group(1))
        if direction == 'forward':
            target = current_num + 1 if current_num < 53 else 1
        else:
            target = current_num - 1 if current_num > 1 else 52

        logger.info(f"Week {direction}: {current_num} → {target}")
        return self.navigate_to_week(target)

    def read_pipeline_extended(self, product_id: str, store_id: str = '70012004',
                               tray_factor: int = 1,
                               required_future_days: int = 7) -> dict:
        """
        Extended pipeline read for products with long lead times (e.g. rye 7d).

        Optimized flow (2 week switches total):
          1. Read current week (e.g. Week 10) for delivered/locked/inventory data
          2. Switch to next week (e.g. Week 11) — this view shows Week 11 + Week 12
          3. Read ALL adjustable dates from Week 11 view (replaces Week 10 adjustable)
          4. Stay on Week 11 — caller writes everything here, submits, then goes back

        Week 10 adjustable dates are committed/locked by Friday, so all writable
        cells live on the Week 11 view. No merging needed.

        Args:
            product_id: Product SKU
            store_id: hub store ID
            tray_factor: Tray factor (for reference)
            required_future_days: Minimum future days needed

        Returns:
            dict with:
              - delivered_pieces, pipeline_incoming, locked_dates from Week 10
              - adjustable_dates from Week 11 view (all column indices valid on Week 11)
              - original_week, extended_week, currently_on_week
        """
        logger.info(f"Extended pipeline read for {product_id} "
                     f"(need {required_future_days} future days)")

        original_week, is_current = self.get_current_week_number()
        logger.info(f"Starting on week {original_week}"
                     f"{' (Current)' if is_current else ''}")

        result = self.read_pipeline(product_id, store_id, tray_factor)

        if not result.get('success'):
            return result

        result['original_week'] = original_week

        adjustable_dates = result.get('adjustable_dates', [])
        today_str = result.get('today')

        if today_str:
            try:
                today_dt = datetime.strptime(today_str, '%Y-%m-%d')
            except:
                today_dt = datetime.now()
        else:
            today_dt = datetime.now()

        max_future_offset = 0
        for adj in adjustable_dates:
            try:
                adj_dt = datetime.strptime(adj['date'], '%Y-%m-%d')
                days_ahead = (adj_dt - today_dt).days
                max_future_offset = max(max_future_offset, days_ahead)
            except:
                pass

        logger.info(f"Current view: {len(adjustable_dates)} adjustable dates, "
                     f"furthest = +{max_future_offset} days from today")

        if max_future_offset >= required_future_days:
            logger.info(f"Current view covers {max_future_offset} days — "
                         f"no week navigation needed")
            result['week_navigation_used'] = False
            return result

        next_week = (original_week or 0) + 1
        logger.info(f"Need +{required_future_days} days but only have +{max_future_offset} — "
                     f"switching to week {next_week}")

        week10_delivered = result.get('delivered_pieces', 0)
        week10_pipeline = result.get('pipeline_incoming', 0)
        week10_locked = result.get('locked_dates', {})

        if not self.navigate_to_week(next_week):
            logger.warning("Week navigation failed — returning partial data from current view")
            result['week_navigation_used'] = False
            result['week_navigation_warning'] = 'Could not navigate to next week'
            return result

        logger.info(f"Waiting for grid to re-render after week switch...")
        self._wait_for_page_ready(timeout=15)
        time.sleep(3)

        logger.info(f"Reading pipeline on week {next_week} (all adjustable dates live here)...")
        extended = self.read_pipeline(product_id, store_id, tray_factor)

        if not extended.get('success'):
            logger.warning(f"Extended read failed: {extended.get('error')} — "
                            f"returning to week {original_week}")
            self.navigate_to_week(original_week)
            result['week_navigation_used'] = True
            result['week_navigation_warning'] = 'Extended read failed, using original data'
            return result

        result['adjustable_dates'] = extended.get('adjustable_dates', [])

        for date_str, lock_data in extended.get('locked_dates', {}).items():
            if date_str not in week10_locked:
                result['locked_dates'][date_str] = lock_data
                if lock_data.get('fo_value', 0) > 0:
                    result['pipeline_incoming'] += lock_data['fo_value']

        total_adjustable = len(result['adjustable_dates'])
        logger.info(f"Week {next_week} view: {total_adjustable} adjustable dates ready for MLP")

        result['week_navigation_used'] = True
        result['extended_week'] = next_week
        result['currently_on_week'] = next_week
        result['message'] = (
            f"Pipeline (extended): {result['pipeline_incoming']} pieces incoming. "
            f"{total_adjustable} adjustable dates on week {next_week} view."
        )

        logger.info(f"Extended pipeline read complete: {result['message']}")
        logger.info(f"Browser stays on week {next_week} — write here, submit, then return to {original_week}")
        return result

    def _submit_and_confirm(self, label: str = '') -> bool:
        """Submit changes on the current week view and confirm the popup.
        Used internally by write_adj_with_week_switch for per-week submissions."""
        try:
            submit_result = self.click_green_submit_button()
            if not submit_result.get('success') or not submit_result.get('popup_appeared'):
                logger.warning(f"Submit button issue on {label}: "
                                f"{submit_result.get('error', submit_result.get('message'))}")
                return False

            orders = submit_result.get('orders', [])
            logger.info(f"  Submit popup on {label}: {len(orders)} changed orders")

            confirm_result = self.confirm_popup_submit()
            if not confirm_result.get('success'):
                logger.error(f"  Confirm failed on {label}: {confirm_result.get('error')}")
                return False

            if confirm_result.get('second_dialog'):
                logger.info(f"  vendor confirmation dialog handled on {label}")
            logger.info(f"  Submitted successfully on {label}")
            time.sleep(3)
            return True

        except Exception as e:
            logger.error(f"Submit/confirm error on {label}: {e}")
            return False

    def write_and_submit_on_current_week(self, product_id: str, decisions: list,
                                          original_week: int = None) -> dict:
        """
        Write ALL ADJ values on the current week view, submit, then return home.

        Called after read_pipeline_extended which leaves the browser on Week 11.
        All adjustable dates come from Week 11's view, so column_index values
        are valid right now — no week switching needed for writes.

        Flow:
          1. Re-search product (already on Week 11)
          2. Write all ADJ cells
          3. Click submit
          4. Navigate back to original week (e.g. Week 10)

        Args:
            product_id: Product SKU
            decisions: List of decision dicts with column_index and final_decision
            original_week: Week to return to after submit (e.g. 10)

        Returns:
            dict with written/failed/submitted
        """
        if not decisions:
            logger.info("No decisions to write")
            return {'written': 0, 'failed': 0, 'submitted': False}

        logger.info(f"Writing S.O.+ADJ for ALL {len(decisions)} adjustable dates (MLP owns every cell)...")

        self._wait_for_page_ready(timeout=15)
        if not self.search_product(product_id):
            logger.error(f"Failed to filter product {product_id}")
            for d in decisions:
                d['otto_action'] = 'failed_product_filter'
            return {'written': 0, 'failed': len(decisions), 'submitted': False}

        time.sleep(2)

        written = 0
        failed = 0

        for d in decisions:
            col_index = d.get('column_index')
            qty = d.get('final_decision', 0)
            current_so = d.get('current_so', 0)
            if col_index is None:
                logger.warning(f"  {d.get('delivery_date')}: No column index — skipping")
                d['otto_action'] = 'skipped'
                failed += 1
                continue

            # ── Step 1: Zero out S.O. if it has a value ──
            if current_so > 0:
                so_result = self.write_so_cell_by_index(product_id, col_index, so_value=0)
                if so_result.get('success'):
                    logger.info(f"  {d.get('delivery_date')}: Zeroed S.O. (was {current_so}) col {col_index}")
                else:
                    logger.warning(f"  {d.get('delivery_date')}: S.O. zero FAILED — {so_result.get('error')}")

            # ── Step 2: Write ADJ = MLP decision (0 for HOLD, N for ORDER) ──
            result = self.write_adj_cell_by_index(product_id, col_index, adj_value=qty)
            if result.get('success'):
                action = 'HOLD' if qty == 0 else f'ORDER {qty}'
                logger.info(f"  {d.get('delivery_date')}: Wrote ADJ={qty} ({action}) to col {col_index}")
                d['otto_action'] = 'written'
                written += 1
            else:
                logger.error(f"  {d.get('delivery_date')}: Write FAILED — {result.get('error')}")
                d['otto_action'] = 'failed'
                failed += 1

        submitted = False
        if written > 0:
            logger.info(f"All {written} writes done (S.O. zeroed + ADJ set) — submitting...")
            submitted = self._submit_and_confirm("extended week")

        if original_week:
            logger.info(f"Returning to week {original_week}...")
            self.navigate_to_week(original_week)
            time.sleep(1)

        return {'written': written, 'failed': failed, 'submitted': submitted}

    def _read_committed_cell_value(self, column_index: int, cell_selector: str):
        """Re-find a cell fresh by column index and read its committed numeric value.

        Mirrors the read_pipeline parser: a blank adjustable cell counts as 0.
        Re-querying from .div-content.day avoids stale-element references after a
        write re-renders the grid. Returns an int, or None only when the cell
        itself cannot be located (structural failure)."""
        try:
            day_columns = self.driver.find_elements(By.CSS_SELECTOR, ".div-content.day")
            if column_index >= len(day_columns):
                return None
            cell = day_columns[column_index].find_element(By.CSS_SELECTOR, cell_selector)
        except Exception:
            return None

        raw = (cell.text or "").strip()
        if not raw or not raw.replace('-', '').replace('.', '').isdigit():
            try:
                inp = cell.find_element(By.TAG_NAME, "input")
                raw = (inp.get_attribute("value") or "0").strip()
            except Exception:
                raw = "0"
        if raw.replace('-', '').replace('.', '').isdigit():
            return int(float(raw))
        return 0

    def write_adj_cell_by_index(self, product_id: str, column_index: int,
                                 quantity_trays: int = None,
                                 adj_value: int = None) -> dict:
        """
        Write a value to a specific ADJ cell by column index.
        Used by the per-date MLP pipeline to set individual adjustments.

        The value written is in raw pieces (same units the hub displays).
        The parameter name 'quantity_trays' is kept for backwards compatibility
        but 'adj_value' is preferred.

        Args:
            product_id: Product SKU (must be filtered already or will filter)
            column_index: Column index from read_pipeline adjustable_dates
            quantity_trays: Value to write (legacy name, kept for compat)
            adj_value: Value to write in pieces (preferred over quantity_trays)
        """
        value = adj_value if adj_value is not None else quantity_trays
        if value is None:
            return {'success': False, 'error': 'No value provided (adj_value or quantity_trays)'}
        value = int(value)

        MAX_ATTEMPTS = 3
        last_read = None
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                day_columns = self.driver.find_elements(By.CSS_SELECTOR, ".div-content.day")
                if column_index >= len(day_columns):
                    return {'success': False, 'error': f'Column index {column_index} out of range'}

                target_col = day_columns[column_index]

                try:
                    adj_cell = target_col.find_element(By.CSS_SELECTOR, ".cell.adj.adjustable")
                except:
                    return {'success': False, 'error': f'Column {column_index} has no adjustable ADJ cell'}

                self.driver.execute_script("arguments[0].scrollIntoView(true);", adj_cell)
                time.sleep(1)

                adj_cell.click()
                time.sleep(2)

                try:
                    input_field = adj_cell.find_element(
                        By.CSS_SELECTOR, "input[inputmode='numeric'][apphubcell]"
                    )
                except:
                    input_field = adj_cell.find_element(By.TAG_NAME, "input")

                input_field.clear()
                time.sleep(0.5)
                input_field.send_keys(str(value))
                time.sleep(0.5)
                input_field.send_keys(Keys.RETURN)
                time.sleep(2)

                # Verify the value actually committed — re-find the cell fresh.
                # the hub's first edit on a cold grid often drops the keystroke; the
                # write is only trustworthy once the cell reads back our value.
                last_read = self._read_committed_cell_value(column_index, ".cell.adj.adjustable")
                if last_read == value:
                    logger.info(f"Wrote ADJ={value} to column {column_index} for {product_id} "
                                f"(verified, attempt {attempt}/{MAX_ATTEMPTS})")
                    return {
                        'success': True,
                        'product_id': product_id,
                        'column_index': column_index,
                        'value_written': value,
                        'value_read_back': last_read,
                        'attempts': attempt,
                        'message': f'Set ADJ to {value} at column {column_index}'
                    }

                logger.warning(f"ADJ col {column_index} for {product_id} read back {last_read}, "
                               f"expected {value} — retry {attempt}/{MAX_ATTEMPTS}")
                time.sleep(1)

            except Exception as e:
                logger.warning(f"Write ADJ attempt {attempt}/{MAX_ATTEMPTS} (col {column_index}, "
                               f"{product_id}) raised: {e}")
                time.sleep(1)

        logger.error(f"ADJ col {column_index} for {product_id} FAILED to commit after "
                     f"{MAX_ATTEMPTS} attempts (last read={last_read}, wanted {value})")
        return {
            'success': False,
            'product_id': product_id,
            'column_index': column_index,
            'value_written': value,
            'value_read_back': last_read,
            'error': f'value not committed (read {last_read}, wanted {value})'
        }

    def write_so_cell_by_index(self, product_id: str, column_index: int,
                                so_value: int = 0) -> dict:
        """
        Write a value to a specific S.O. cell by column index.
        Used to zero out Standing Orders so MLP fully owns F.O. via ADJ.

        Args:
            product_id: Product SKU (must be filtered already)
            column_index: Column index from read_pipeline adjustable_dates
            so_value: Value to write (typically 0)
        """
        so_value = int(so_value)

        MAX_ATTEMPTS = 3
        last_read = None
        for attempt in range(1, MAX_ATTEMPTS + 1):
            try:
                day_columns = self.driver.find_elements(By.CSS_SELECTOR, ".div-content.day")
                if column_index >= len(day_columns):
                    return {'success': False, 'error': f'Column index {column_index} out of range'}

                target_col = day_columns[column_index]

                try:
                    so_cell = target_col.find_element(By.CSS_SELECTOR, ".cell.so.adjustable")
                except:
                    return {'success': False, 'error': f'Column {column_index} has no adjustable S.O. cell'}

                self.driver.execute_script("arguments[0].scrollIntoView(true);", so_cell)
                time.sleep(1)

                so_cell.click()
                time.sleep(2)

                try:
                    input_field = so_cell.find_element(
                        By.CSS_SELECTOR, "input[inputmode='numeric'][apphubcell]"
                    )
                except:
                    input_field = so_cell.find_element(By.TAG_NAME, "input")

                input_field.clear()
                time.sleep(0.5)
                input_field.send_keys(str(so_value))
                time.sleep(0.5)
                input_field.send_keys(Keys.RETURN)
                time.sleep(2)

                # Verify the S.O. value committed — same cold-grid race as ADJ.
                last_read = self._read_committed_cell_value(column_index, ".cell.so.adjustable")
                if last_read == so_value:
                    logger.info(f"Wrote S.O.={so_value} to column {column_index} for {product_id} "
                                f"(verified, attempt {attempt}/{MAX_ATTEMPTS})")
                    return {
                        'success': True,
                        'product_id': product_id,
                        'column_index': column_index,
                        'value_written': so_value,
                        'value_read_back': last_read,
                        'attempts': attempt,
                        'message': f'Set S.O. to {so_value} at column {column_index}'
                    }

                logger.warning(f"S.O. col {column_index} for {product_id} read back {last_read}, "
                               f"expected {so_value} — retry {attempt}/{MAX_ATTEMPTS}")
                time.sleep(1)

            except Exception as e:
                logger.warning(f"Write S.O. attempt {attempt}/{MAX_ATTEMPTS} (col {column_index}, "
                               f"{product_id}) raised: {e}")
                time.sleep(1)

        logger.error(f"S.O. col {column_index} for {product_id} FAILED to commit after "
                     f"{MAX_ATTEMPTS} attempts (last read={last_read}, wanted {so_value})")
        return {
            'success': False,
            'product_id': product_id,
            'column_index': column_index,
            'value_written': so_value,
            'value_read_back': last_read,
            'error': f'value not committed (read {last_read}, wanted {so_value})'
        }

    def find_green_submit_button(self):
        """Find the green counter/submit button on ordering hub.
        Returns the clickable element or None if not found."""
        try:
            selectors = [
                "button[mat-mini-fab].green .mat-mdc-button-touch-target",
                "button[mat-mini-fab].green",
                "button.green.counter .mat-mdc-button-touch-target",
                "button.green.counter",
                "button.green",
            ]

            for selector in selectors:
                try:
                    elements = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    for elem in elements:
                        try:
                            parent = elem.find_element(By.XPATH, "..")
                            classes = parent.get_attribute("class") or ""
                            if "counter" in classes and "green" in classes:
                                logger.info(f"Found green counter button: {classes}")
                                return elem
                        except:
                            pass
                    if elements:
                        logger.info(f"Found green button with selector: {selector}")
                        return elements[0]
                except:
                    continue

            fallback_buttons = self.driver.find_elements(
                By.CSS_SELECTOR, "button[mat-mini-fab].green, button.green"
            )
            for btn in fallback_buttons:
                try:
                    touch = btn.find_element(By.CSS_SELECTOR, "span.mat-mdc-button-touch-target")
                    if touch:
                        logger.info(f"Found green button via fallback: {btn.get_attribute('class')}")
                        return touch
                except:
                    continue
                logger.info(f"Found green button (no touch target): {btn.get_attribute('class')}")
                return btn

            logger.warning("Green submit button not found")
            return None

        except Exception as e:
            logger.error(f"Error finding green submit button: {e}")
            return None

    def click_green_submit_button(self) -> dict:
        """Click the green submit button and scrape the confirmation popup.
        Returns dict with popup data for CLI review before final confirm."""
        try:
            target = self.find_green_submit_button()
            if not target:
                return {'success': False, 'error': 'Green submit button not found on page'}

            before_popups = len(self.driver.find_elements(
                By.CSS_SELECTOR, "app-changed-orders"
            ))

            logger.info("Clicking green submit button...")
            self.driver.execute_script("arguments[0].scrollIntoView(true);", target)
            time.sleep(1)

            try:
                target.click()
            except:
                self.driver.execute_script("arguments[0].click();", target)

            time.sleep(3)

            after_popups = len(self.driver.find_elements(
                By.CSS_SELECTOR, "app-changed-orders"
            ))

            if after_popups <= before_popups:
                return {
                    'success': True,
                    'popup_appeared': False,
                    'message': 'Green button clicked but no popup appeared (no pending changes)',
                    'orders': []
                }

            popup = self.driver.find_elements(By.CSS_SELECTOR, "app-changed-orders")[0]
            popup_text = popup.text.strip()

            no_orders_divs = popup.find_elements(By.XPATH,
                ".//div[contains(@class, 'no-orders')]")
            if no_orders_divs:
                self._dismiss_popup()
                return {
                    'success': True,
                    'popup_appeared': True,
                    'no_orders': True,
                    'message': 'No orders have been adjusted',
                    'orders': []
                }

            orders = self._extract_popup_orders(popup)

            return {
                'success': True,
                'popup_appeared': True,
                'no_orders': False,
                'orders': orders,
                'popup_text': popup_text,
                'message': f'Found {len(orders)} pending order changes'
            }

        except Exception as e:
            logger.error(f"Error clicking green submit button: {e}")
            return {'success': False, 'error': str(e)}

    def _extract_popup_orders(self, popup_element) -> list:
        """Extract order rows from the Changed Orders popup."""
        orders = []
        try:
            rows = popup_element.find_elements(
                By.CSS_SELECTOR, ".table-scroller .row, .row, tr, .order-row"
            )
            logger.info(f"Found {len(rows)} potential rows in popup")

            for i, row in enumerate(rows):
                try:
                    cols = row.find_elements(By.CSS_SELECTOR, ".col, td, .cell")
                    if len(cols) >= 5:
                        order = {
                            'customer_id': cols[0].text.strip(),
                            'product_id': cols[1].text.strip(),
                            'standing_order': cols[2].text.strip(),
                            'adjustment': cols[3].text.strip(),
                            'final_order': cols[4].text.strip(),
                        }
                        if len(cols) >= 6:
                            order['order_date'] = cols[5].text.strip()

                        if any(order[k] for k in ['customer_id', 'product_id', 'final_order']):
                            if order.get('customer_id', '').lower() == 'customer':
                                continue
                            orders.append(order)
                            logger.info(f"  Row {i}: Product {order['product_id']}, "
                                       f"S.O.={order['standing_order']}, ADJ={order['adjustment']}, "
                                       f"F.O.={order['final_order']}")
                except Exception as e:
                    logger.debug(f"Skipping row {i}: {e}")
                    continue

        except Exception as e:
            logger.error(f"Error extracting popup orders: {e}")

        return orders

    def confirm_popup_submit(self) -> dict:
        """Click the Submit button inside the Changed Orders popup, then handle
        the second 'Submit changes to the distributor' confirmation dialog.
        Call this AFTER click_green_submit_button() and user review."""
        try:
            popup = self.driver.find_elements(By.CSS_SELECTOR, "app-changed-orders")
            if not popup:
                return {'success': False, 'error': 'No popup found to confirm'}

            popup_elem = popup[0]

            first_submit = self._find_submit_button_in(popup_elem)
            if not first_submit:
                return {'success': False, 'error': 'Could not find Submit button in Changed Orders popup'}

            logger.info(f"Clicking first Submit button: '{first_submit.text.strip()}'")
            self.driver.execute_script("arguments[0].scrollIntoView(true);", first_submit)
            time.sleep(0.5)

            try:
                first_submit.click()
            except:
                self.driver.execute_script("arguments[0].click();", first_submit)

            time.sleep(3)

            second_result = self._handle_vendor_confirmation_dialog()

            return second_result

        except Exception as e:
            logger.error(f"Error confirming popup: {e}")
            return {'success': False, 'error': str(e)}

    def _find_submit_button_in(self, container) -> object:
        """Find a Submit/Confirm button within a container element."""
        confirm_selectors = [
            "button.confirm",
            "button.submit",
            "button[color='primary']",
            "button.mat-primary",
            "button.green",
            "button[type='submit']",
        ]

        for selector in confirm_selectors:
            try:
                buttons = container.find_elements(By.CSS_SELECTOR, selector)
                for btn in buttons:
                    btn_text = btn.text.strip().lower()
                    if any(word in btn_text for word in ['confirm', 'submit', 'save', 'ok', 'yes']):
                        return btn
                if buttons:
                    return buttons[0]
            except:
                continue

        all_buttons = container.find_elements(By.TAG_NAME, "button")
        for btn in all_buttons:
            btn_text = btn.text.strip().lower()
            if any(word in btn_text for word in ['confirm', 'submit', 'save', 'ok', 'yes', 'send']):
                return btn

        return None

    def _handle_vendor_confirmation_dialog(self) -> dict:
        """Handle the second 'Submit changes to the distributor' confirmation dialog.

        CRITICAL: This dialog lives in a SEPARATE cdk-overlay-pane from the first
        app-changed-orders popup. The DOM structure is:

        cdk-overlay-container
          ├─ cdk-overlay-pane  ← first overlay (app-changed-orders popup)
          │    └─ app-changed-orders ...
          └─ cdk-overlay-pane  ← SECOND overlay (vendor dialog) — LAST in DOM
               └─ mat-dialog-container#mat-mdc-dialog-2
                    └─ mdc-dialog__container
                         └─ mat-mdc-dialog-surface
                              └─ app-dialog
                                   └─ div.notification-message
                                        ├─ h2: "Submit changes to the distributor"
                                        └─ div.actions
                                             ├─ button.mat-primary (Submit)
                                             └─ button.mat-warn (Cancel)

        We MUST target the LAST cdk-overlay-pane to avoid re-clicking the first
        popup's Submit button.
        """
        try:
            submit_btn = None

            all_overlays = self.driver.find_elements(By.CSS_SELECTOR,
                ".cdk-overlay-container > .cdk-global-overlay-wrapper > .cdk-overlay-pane")

            if not all_overlays:
                all_overlays = self.driver.find_elements(By.CSS_SELECTOR, ".cdk-overlay-pane")

            logger.info(f"Found {len(all_overlays)} overlay pane(s)")

            dialog_overlay = None
            for overlay in reversed(all_overlays):
                try:
                    if not overlay.is_displayed():
                        continue
                    has_mat_dialog = overlay.find_elements(By.CSS_SELECTOR, "mat-dialog-container")
                    if has_mat_dialog:
                        dialog_overlay = overlay
                        logger.info("Found confirmation overlay: last cdk-overlay-pane with mat-dialog-container")
                        break
                    has_app_dialog = overlay.find_elements(By.CSS_SELECTOR, "app-dialog")
                    if has_app_dialog:
                        dialog_overlay = overlay
                        logger.info("Found confirmation overlay: last cdk-overlay-pane with app-dialog")
                        break
                except:
                    continue

            if not dialog_overlay:
                for overlay in reversed(all_overlays):
                    try:
                        if not overlay.is_displayed():
                            continue
                        text = overlay.text.lower()
                        if 'submit changes' in text:
                            dialog_overlay = overlay
                            logger.info("Found confirmation overlay via text content match")
                            break
                    except:
                        continue

            if not dialog_overlay:
                logger.warning("No vendor confirmation overlay found")
                return {
                    'success': False,
                    'second_dialog': False,
                    'error': 'Second confirmation overlay not found after first Submit'
                }

            overlay_text = dialog_overlay.text.strip()
            logger.info(f"confirmation overlay text preview: {overlay_text[:150]}")

            scoped_selectors = [
                "app-dialog div.actions button.mat-primary",
                "app-dialog button.mat-primary.mdc-button--unelevated",
                "app-dialog button[color='primary']",
                "mat-dialog-container button.mat-primary",
                "div.actions button.mat-primary",
                "button.mat-primary.mdc-button--unelevated",
                "button.mat-mdc-unelevated-button.mat-primary",
            ]
            for selector in scoped_selectors:
                try:
                    buttons = dialog_overlay.find_elements(By.CSS_SELECTOR, selector)
                    for btn in buttons:
                        if not btn.is_displayed():
                            continue
                        btn_text = btn.text.strip().lower()
                        if btn_text == 'submit':
                            submit_btn = btn
                            logger.info(f"Found confirmation Submit in overlay with: {selector}")
                            break
                except:
                    continue
                if submit_btn:
                    break

            if not submit_btn:
                try:
                    all_btns = dialog_overlay.find_elements(By.TAG_NAME, "button")
                    logger.info(f"Fallback: scanning {len(all_btns)} buttons in confirmation overlay")
                    for btn in all_btns:
                        if not btn.is_displayed():
                            continue
                        btn_text = btn.text.strip().lower()
                        btn_classes = btn.get_attribute("class") or ""
                        logger.info(f"  Button: text='{btn_text}' classes='{btn_classes[:80]}'")
                        if btn_text == 'submit':
                            submit_btn = btn
                            logger.info("Found confirmation Submit via overlay button scan")
                            break
                except Exception as e:
                    logger.debug(f"Button scan failed: {e}")

            if not submit_btn:
                return {
                    'success': False,
                    'second_dialog': True,
                    'error': 'Found confirmation overlay but no Submit button inside it',
                    'overlay_text': overlay_text[:300]
                }

            logger.info(f"Clicking confirmation Submit button: '{submit_btn.text.strip()}'")

            clicked = self._force_click(submit_btn)
            if not clicked:
                return {
                    'success': False,
                    'second_dialog': True,
                    'error': 'Found confirmation Submit button but all click strategies failed'
                }

            time.sleep(4)

            self._close_success_dialog()

            remaining = self.driver.find_elements(By.CSS_SELECTOR, "app-changed-orders")
            popup_gone = len(remaining) == 0 or not remaining[0].is_displayed()

            dialogs_gone = True
            try:
                still_visible = self.driver.find_elements(By.CSS_SELECTOR,
                    "mat-dialog-container, .mat-mdc-dialog-container, app-dialog")
                for e in still_visible:
                    if e.is_displayed():
                        dialogs_gone = False
                        break
            except:
                pass

            all_closed = popup_gone and dialogs_gone

            return {
                'success': True,
                'popup_closed': all_closed,
                'second_dialog': True,
                'message': 'Submission confirmed (both dialogs closed)' if all_closed else 'Final submit clicked but dialogs may still be visible'
            }

        except Exception as e:
            logger.error(f"Error handling vendor confirmation dialog: {e}")
            return {'success': False, 'error': str(e)}

    def _close_success_dialog(self):
        """Close the 'Success!' dialog that appears after the hub submission.
        The X button is: button.close.mdc-icon-button with mat-icon 'close' inside."""
        try:
            close_selectors = [
                "button.close.mdc-icon-button",
                "button.close.mat-mdc-icon-button",
                "button.close",
            ]

            close_btn = None
            for selector in close_selectors:
                try:
                    buttons = self.driver.find_elements(By.CSS_SELECTOR, selector)
                    for btn in buttons:
                        if btn.is_displayed():
                            close_btn = btn
                            logger.info(f"Found Success dialog close button with: {selector}")
                            break
                except:
                    continue
                if close_btn:
                    break

            if not close_btn:
                try:
                    icons = self.driver.find_elements(By.CSS_SELECTOR, "mat-icon")
                    for icon in icons:
                        if icon.is_displayed() and icon.text.strip().lower() == 'close':
                            close_btn = icon.find_element(By.XPATH, "..")
                            logger.info("Found close button via mat-icon text='close'")
                            break
                except:
                    pass

            if close_btn:
                try:
                    close_btn.click()
                except:
                    self.driver.execute_script("arguments[0].click();", close_btn)
                logger.info("Success dialog closed")
                time.sleep(1)
            else:
                logger.info("No Success dialog close button found (may have auto-closed)")

        except Exception as e:
            logger.debug(f"Error closing success dialog (non-fatal): {e}")

    def _force_click(self, element) -> bool:
        """Try multiple click strategies for Angular Material CDK overlay buttons.
        Angular Material buttons have nested spans (ripple, focus-indicator,
        touch-target) that can intercept clicks. We target the inner
        span.mdc-button__label and use full pointer event sequences.
        Returns True if at least one strategy executed without error."""
        from selenium.webdriver.common.action_chains import ActionChains

        strategies = []

        label_span = None
        try:
            label_span = element.find_element(By.CSS_SELECTOR, "span.mdc-button__label")
            logger.info(f"Found inner label span: '{label_span.text.strip()}'")
        except:
            logger.debug("No span.mdc-button__label found, will click button directly")

        try:
            self.driver.execute_script("""
                var btn = arguments[0];
                var label = arguments[1];
                var target = label || btn;
                ['pointerdown', 'mousedown'].forEach(function(t) {
                    target.dispatchEvent(new PointerEvent(t, {bubbles:true, cancelable:true}));
                });
                ['pointerup', 'mouseup'].forEach(function(t) {
                    target.dispatchEvent(new PointerEvent(t, {bubbles:true, cancelable:true}));
                });
                target.dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true, view:window}));
                btn.dispatchEvent(new MouseEvent('click', {bubbles:true, cancelable:true, view:window}));
            """, element, label_span)
            strategies.append("pointer sequence on label+button")
            logger.info("Click strategy 1: full pointer sequence on label span — executed")
            time.sleep(2)
        except Exception as e:
            logger.debug(f"Click strategy 1 failed: {e}")

        try:
            target = label_span if label_span else element
            ActionChains(self.driver).move_to_element(target).pause(0.2).click().perform()
            strategies.append("ActionChains on label")
            logger.info("Click strategy 2: ActionChains move+click on label — executed")
            time.sleep(2)
        except Exception as e:
            logger.debug(f"Click strategy 2 failed: {e}")

        try:
            self.driver.execute_script("""
                var btn = arguments[0];
                btn.focus();
                btn.click();
            """, element)
            strategies.append("JS focus+click")
            logger.info("Click strategy 3: JS focus+click — executed")
            time.sleep(2)
        except Exception as e:
            logger.debug(f"Click strategy 3 failed: {e}")

        try:
            self.driver.execute_script("""
                var btn = arguments[0];
                var rect = btn.getBoundingClientRect();
                var cx = rect.left + rect.width / 2;
                var cy = rect.top + rect.height / 2;
                var opts = {bubbles:true, cancelable:true, clientX:cx, clientY:cy, view:window};
                btn.dispatchEvent(new PointerEvent('pointerdown', opts));
                btn.dispatchEvent(new MouseEvent('mousedown', opts));
                btn.dispatchEvent(new PointerEvent('pointerup', opts));
                btn.dispatchEvent(new MouseEvent('mouseup', opts));
                btn.dispatchEvent(new MouseEvent('click', opts));
            """, element)
            strategies.append("coordinate-based pointer sequence")
            logger.info("Click strategy 4: coordinate-based pointer events — executed")
            time.sleep(2)
        except Exception as e:
            logger.debug(f"Click strategy 4 failed: {e}")

        try:
            element.click()
            strategies.append("Selenium native click")
            logger.info("Click strategy 5: Selenium native click — executed")
            time.sleep(2)
        except Exception as e:
            logger.debug(f"Click strategy 5 failed: {e}")

        try:
            self.driver.execute_script("""
                var btn = arguments[0];
                var ke = new KeyboardEvent('keydown', {key:'Enter', code:'Enter', bubbles:true});
                btn.focus();
                btn.dispatchEvent(ke);
                btn.dispatchEvent(new KeyboardEvent('keyup', {key:'Enter', code:'Enter', bubbles:true}));
            """, element)
            strategies.append("Enter key on focused button")
            logger.info("Click strategy 6: Enter keypress on button — executed")
        except Exception as e:
            logger.debug(f"Click strategy 6 failed: {e}")

        if strategies:
            logger.info(f"Click strategies executed: {', '.join(strategies)}")
            return True
        else:
            logger.error("All click strategies failed")
            return False

    def dismiss_popup(self) -> dict:
        """Dismiss/close the Changed Orders popup without confirming."""
        try:
            self._dismiss_popup()
            return {'success': True, 'message': 'Popup dismissed'}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def _dismiss_popup(self):
        """Internal: close popup via Escape key."""
        try:
            from selenium.webdriver.common.action_chains import ActionChains
            ActionChains(self.driver).send_keys(Keys.ESCAPE).perform()
            time.sleep(1)
        except:
            pass

    def scrape_committed_orders(self, product_id: str, store_id: str = '70012004',
                                days_filter: list = None) -> dict:
        """
        Scrape committed (greyed) orders for a product - MAIN AI TOOL ENTRY POINT
        """
        try:
            logger.info(f"Starting scrape_committed_orders: product={product_id}, store={store_id}")

            if not self.setup_driver():
                raise Exception('Failed to initialize Chrome driver')

            if not self.logged_in:
                logger.info("Not logged in - navigating to OrderHub...")
                if not self.navigate_to_ordering_hub():
                    raise Exception('Failed to navigate to OrderHub - check URL or network')

            if store_id != self.target_store_id:
                logger.info(f"Switching from {self.target_store_id} to {store_id}...")
                if not self.switch_to_store(store_id):
                    raise Exception(f'Failed to switch to store {store_id} - store may not exist')

            logger.info(f"Scraping product row for {product_id}...")
            result = self.scrape_product_row(product_id)

            committed_orders = result['greyed_cells']

            logger.info(f"Found {len(committed_orders)} committed/greyed cells")

            filtered_days = {}
            if days_filter:
                logger.info(f"Filtering for days: {days_filter}")

                for date_str, quantity in committed_orders.items():
                    try:
                        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
                        day_name = date_obj.strftime('%A')

                        if day_name in days_filter:
                            if day_name not in filtered_days:
                                filtered_days[day_name] = {}
                            filtered_days[day_name][date_str] = quantity
                    except:
                        continue

            return {
                'success': True,
                'product_id': product_id,
                'store_id': store_id,
                'committed_orders': committed_orders,
                'filtered_days': filtered_days if days_filter else {},
                'total_greyed_cells': len(committed_orders),
                'message': f"Found {len(committed_orders)} committed orders for product {product_id}"
            }

        except Exception as e:
            logger.error(f"Scraping failed: {e}")
            return {
                'success': False,
                'error': str(e),
                'product_id': product_id,
                'store_id': store_id
            }
