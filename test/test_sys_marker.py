import unittest

class TestSysMarker(unittest.TestCase):
    def test_markers(self):
        def fail() -> None:
            # this is a dependency for sunos4, should not be present on other platforms
            from colorama import init
            init()

        self.assertRaises(ImportError, fail)


if __name__ == '__main__':
    unittest.main()
