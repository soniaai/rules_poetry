import unittest

class TestInvalidImport(unittest.TestCase):
    def test_valid_import(self):
        def fail() -> None:
            import pandas
            pass

        self.assertRaises(ImportError, fail)

if __name__ == '__main__':
  unittest.main()
