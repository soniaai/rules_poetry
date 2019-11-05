import unittest

class TestSysMarker(unittest.TestCase):
    def test_markers(self):
        def fail() -> None:
            # this is a dependency of ipython but only on Windows
            from colorama import init
            init()
        raise ValueError()

        self.assertRaises(ImportError, fail)


if __name__ == '__main__':
  unittest.main()
