import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from import_dane_divipola_sidecar import build_sidecar, valid_point  # noqa: E402


class DaneSidecarTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        fixture = Path(__file__).parent / "fixtures" / "dane_mgn_2025_centroid_fragment.json"
        cls.fragment = json.loads(fixture.read_text(encoding="utf-8"))

    def test_official_fragment_builds_wgs84_reference_only_points(self):
        response = self.fragment["response"]
        self.assertEqual(4326, response["spatialReference"]["wkid"])
        sidecar = build_sidecar(
            response["features"],
            self.fragment["verifiedAt"],
            self.fragment["sourceService"],
        )
        self.assertEqual(2, len(sidecar["features"]))
        first = sidecar["features"][0]
        self.assertEqual("05001", first["parentDivipolaCode"])
        self.assertEqual("derived_centroid_reference_only", first["pointRole"])
        self.assertTrue(-180 <= first["longitude"] <= 180)
        self.assertTrue(-90 <= first["latitude"] <= 90)

    def test_missing_or_invalid_centroid_stays_unknown(self):
        for centroid in (None, {"x": 0, "y": 0}, {"x": 200, "y": 100}):
            self.assertEqual((None, None, "unknown"), valid_point(centroid))


if __name__ == "__main__":
    unittest.main()
