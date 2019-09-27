import unittest

class TestInvalidImport(unittest.TestCase):
    def test_valid_import():
        def fail() -> None:
            import pandas
            pass

        self.assertRaises(ImportError, fail)

