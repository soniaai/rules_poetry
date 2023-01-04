import unittest

import pandas
import numpy

class TestValidImport(unittest.TestCase):
    def test_valid_import(self):
        self.assertIsNotNone(pandas)


if __name__ == '__main__':
  unittest.main()
