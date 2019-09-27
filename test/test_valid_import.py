import unittest

import pandas

class TestValidImport(unittest.TestCase):
    def test_valid_import():
        self.assertIsNotNone(pandas)

