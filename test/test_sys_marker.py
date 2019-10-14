import unittest

class TestSysMarker(unittest.TestCase):
    def test_():
        def fail() -> None:
            # this is a dependency of ipython but only
            from colorama import init
            init()

        self.assertRaises(ImportError, fail)

