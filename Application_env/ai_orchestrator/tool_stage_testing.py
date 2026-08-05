import argparse
import logging
import sys
import unittest

from custom_selenium_order_integration_tool import OrderHubScraper

logging.basicConfig(level=logging.INFO, format='%(levelname) -7s %(message)s')

STORE_A = '70012001'
STORE_B = '70012003'
PRODUCT = '500101'
PRODUCT_B = '500103'


def banner(n, tittle):
    print('\n' + '=' * 62)
    print(f' STAGE {n} TEST - {tittle}')
    print('=' * 62)
    
def make(args):
    return OrderHubScraper(headless=not args.headful, hub_url=args.url,)


def stage1(args):
    banner(1, 'driver bootstrap')
    s =make(args)
    assert s.setup_driver(), 'driver failed to start'
    assert s.setup_driver(), 'second call must be a no-op, not a second Chrome'
    print(f'PASS: Chrome up (idempotent). Session: {s.driver.session_id[:12]}...')
    s.close()
    s.close() 
    print('PASS: close() twice is safe')


def stage2(args):
    banner(2, 'load + readiness signals')
    s = make(args)
    try:
        assert s.setup_driver()
        assert s.navigate_to_hub(), 'hub never became ready'
        cols = s.driver.find_elements('css selector', '.div-content.day')
        print(f'PASS: hub ready - title={s.driver.title!r}, {len(cols)} day columns')
    finally:
        s.close()



def stage3(args):
    banner(3, 'store switching (wait for the new state)')
    s = make(args)
    try:
        assert s.setup_driver() and s.navigate_to_hub()
        assert s.switch_to_store(STORE_B), 'switch failed'
        ph = s.driver.find_element(
            'css selector', "input[formcontrolname='customer']"
        ).get_attribute('placeholder')
        assert STORE_B in ph, f'placeholder does not confirm switch: {ph!r}'
        print(f' PASS: switched, placeholder confirms: {ph!r}')
    finally:
        s.close()

def stage4(args):
    banner(4, 'product filtering (selector ladder + rebuild')
    s = make(args)
    try:
        assert s.setup_driver() and s.navigate_to_hub()
        before = len(s.driver.find_elements('css selector', '.product-block'))
        assert s.search_product(PRODUCT), 'product failed'
        after = len(s.driver.find_elements('css selector', '.product-block'))
        assert after ==1, f'expected exactly 1 product row, got {after}'
        print(f'PASS: {before} product rows -> {after} after filtering {PRODUCT}')
        assert s.search_product(''), 'clearing filter failed'
        restored = len(s.driver.find_elements('css selector', '.product-block'))
        print(f'PASS: filter cleared -> {restored} rows back')
    finally:
        s.close()





STAGES = {1: stage1, 2: stage2, 3: stage3, 4: stage4}

def main():
    ap = argparse.ArgumentParser(description='Run one rebuild stage test')
    ap.add_argument('stage', type=int, nargs='?', default=1, choices=sorted(STAGES),
    help='stage number to run (default: 1)')
    ap.add_argument('--url', default='http://127.0.0.1:8099/index.html')
    ap.add_argument('--headful', action='store_true' ,
                    help='visible Chrome so we can see what the tooling is doing)')

    args = ap.parse_args()
    try:
        STAGES[args.stage](args)
    except AssertionError as e:
        print(f'\nFAIL: {e}')
        sys.exit(1)


if __name__ == '__main__':
    main()






























