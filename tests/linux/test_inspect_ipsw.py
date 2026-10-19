import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
INSPECTOR = ROOT / "scripts" / "linux" / "inspect_ipsw.py"


class InspectIpswTests(unittest.TestCase):
    def test_uses_build_manifest_when_info_plist_is_absent(self):
        manifest = {
            "ProductVersion": "26.6.2",
            "ProductBuildVersion": "23G90",
            "SupportedProductTypes": ["iPhone12,1"],
            "BuildIdentities": [
                {
                    "Info": {
                        "DeviceClass": "n104ap",
                        "Variant": "Customer Erase Install (IPSW)",
                        "RestoreBehavior": "Erase",
                    },
                    "Manifest": {
                        "DeviceTree": {"Info": {"Path": "Firmware/DeviceTree.n104ap.im4p"}},
                        "KernelCache": {"Info": {"Path": "kernelcache.release.iphone12b"}},
                    },
                }
            ],
        }
        with tempfile.TemporaryDirectory() as temp_dir:
            ipsw = Path(temp_dir) / "fixture.ipsw"
            with zipfile.ZipFile(ipsw, "w") as archive:
                archive.writestr("BuildManifest.plist", plistlib.dumps(manifest))

            result = subprocess.run(
                [sys.executable, str(INSPECTOR), str(ipsw)],
                check=True,
                capture_output=True,
                text=True,
            )

        self.assertIn('"product_version": "26.6.2"', result.stdout)
        self.assertIn('"product_type": "iPhone12,1"', result.stdout)
        self.assertIn('"DeviceTree"', result.stdout)


if __name__ == "__main__":
    unittest.main()
