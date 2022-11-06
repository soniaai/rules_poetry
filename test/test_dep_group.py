import unittest

import cowsay

class TestValidImport(unittest.TestCase):
    def test_valid_dep_group_import(self):
        self.assertIsNotNone(cowsay)
        self.assertIsNotNone(cowsay.get_output_string("trex", "Hello World"))

if __name__ == '__main__':
  unittest.main()
