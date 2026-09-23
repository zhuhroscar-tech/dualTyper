import hashlib
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class RepositoryContractTests(unittest.TestCase):
    def test_required_project_files_are_present(self):
        required = [
            "README.md",
            "README.zh-CN.md",
            "LICENSE",
            "Package.swift",
            "project.yml",
            ".github/workflows/core.yml",
            "scripts/test-core.sh",
            "scripts/package-menubar-dmg.sh",
            "docs/architecture.md",
            "docs/free-distribution.md",
            "docs/release-packaging.md",
            "docs/images/dualtyper-setup.png",
        ]
        missing = [path for path in required if not (ROOT / path).exists()]
        self.assertEqual(missing, [])

    def test_readme_local_links_and_images_exist(self):
        for readme_name in ("README.md", "README.zh-CN.md"):
            text = (ROOT / readme_name).read_text(encoding="utf-8")
            links = re.findall(r"\[[^\]]+\]\(([^)]+)\)", text)
            images = re.findall(r"!\[[^\]]*\]\(([^)]+)\)", text)
            local_targets = [target for target in links + images if not target.startswith(("http://", "https://", "mailto:"))]
            missing = []
            for target in local_targets:
                clean = target.split("#", 1)[0]
                if clean and not (ROOT / clean).exists():
                    missing.append(target)
            self.assertEqual(missing, [], f"broken local targets in {readme_name}")

    def test_release_documentation_matches_tracked_checksum(self):
        release_name = "DualTyper-0.3.0-FREE-UNNOTARIZED.dmg"
        dmg = ROOT / "dist" / release_name
        sidecar = ROOT / "dist" / f"{release_name}.sha256"
        docs = (ROOT / "docs" / "free-distribution.md").read_text(encoding="utf-8")

        self.assertTrue(dmg.exists(), "tracked release DMG is missing")
        self.assertTrue(sidecar.exists(), "tracked release checksum is missing")
        sidecar_hash, sidecar_name = sidecar.read_text(encoding="utf-8").strip().split(maxsplit=1)
        actual_hash = hashlib.sha256(dmg.read_bytes()).hexdigest()

        self.assertEqual(sidecar_name, release_name)
        self.assertEqual(sidecar_hash, actual_hash)
        self.assertIn(sidecar_hash, docs)
        self.assertIn(f"Bytes    {dmg.stat().st_size}", docs)

    def test_ci_exercises_core_test_paths(self):
        workflow = (ROOT / ".github" / "workflows" / "core.yml").read_text(encoding="utf-8")
        self.assertIn("swift test", workflow)
        self.assertIn("./scripts/test-core.sh", workflow)
        self.assertIn("python3 -m unittest discover -s Tests/RepositoryContractTests -v", workflow)

    def test_xcodegen_project_keeps_supported_targets(self):
        project = (ROOT / "project.yml").read_text(encoding="utf-8")
        self.assertIn("minimumXcodeGenVersion: 2.46.0", project)
        self.assertIn("macOS: \"15.0\"", project)
        self.assertIn("DualTyperMenuBar:", project)
        self.assertIn("DualTyperInputMethod:", project)
        self.assertIn("CODE_SIGNING_ALLOWED: NO", project)


if __name__ == "__main__":
    unittest.main()
