import unittest

import pandas

class TestValidImport(unittest.TestCase):
    def test_valid_import():
        self.assertIsNotNone(pandas)

    def test_valid_import():
        import requests.toolbelt
        self.assertIsNotNone(requests.toolbelt)
