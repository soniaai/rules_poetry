import unittest

import pandas

class TestValidImport(unittest.TestCase):
    def test_valid_import(self):
        self.assertIsNotNone(pandas)

    def test_valid_import(self):
        import requests_toolbelt
        self.assertIsNotNone(requests_toolbelt)

if __name__ == '__main__':
  unittest.main()
