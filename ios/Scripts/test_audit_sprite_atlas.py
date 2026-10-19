import unittest
import numpy as np
from audit_sprite_atlas import find_matches


class PixelMatchingTests(unittest.TestCase):
    def setUp(self):
        self.source = np.array([[[30, 60, 90, 255], [40, 50, 60, 128]],
                                [[0, 0, 0, 0], [80, 90, 100, 255]]], dtype=np.uint8)
        self.atlas = np.zeros((6, 7, 4), dtype=np.uint8)
        self.atlas[3:5, 4:6] = self.source

    def test_top_left_coordinates_and_full_padding(self):
        self.assertEqual(find_matches(self.atlas, self.source), [[4, 3, 2, 2]])

    def test_hidden_rgb_is_irrelevant(self):
        self.atlas[4, 4, :3] = [200, 201, 202]
        self.assertEqual(find_matches(self.atlas, self.source), [[4, 3, 2, 2]])

    def test_lost_or_partial_alpha_is_not_equivalent(self):
        for alpha in (0, 127, 255):
            self.atlas[3, 5, 3] = alpha
            self.assertEqual(find_matches(self.atlas, self.source), [])

    def test_visible_color_change_rejects_match(self):
        self.atlas[3, 4, 0] += 1
        self.assertEqual(find_matches(self.atlas, self.source), [])

    def test_duplicates_and_bottom_right_boundary_are_reported(self):
        self.atlas[0:2, 0:2] = self.source
        self.atlas[4:6, 5:7] = self.source
        self.assertEqual(find_matches(self.atlas, self.source), [[0, 0, 2, 2], [5, 4, 2, 2]])

    def test_oversized_or_unidentifiable_source(self):
        self.assertEqual(find_matches(self.atlas, np.ones((8, 8, 4), dtype=np.uint8)), [])
        with self.assertRaises(ValueError):
            find_matches(self.atlas, np.zeros((2, 2, 4), dtype=np.uint8))


if __name__ == '__main__':
    unittest.main()
