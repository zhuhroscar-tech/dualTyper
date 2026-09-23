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

    def test_release_documentation_tracks_public_artifact_identity(self):
        docs = (ROOT / "docs" / "free-distribution.md").read_text(encoding="utf-8")
        release_name = "DualTyper-0.3.0-FREE-UNNOTARIZED.dmg"
        checksum_match = re.search(r"SHA-256\s+([0-9a-f]{64})", docs)
        bytes_match = re.search(r"Bytes\s+(\d+)", docs)

        self.assertIn(release_name, docs)
        if checksum_match is None:
            self.fail("release docs must publish a SHA-256")
        if bytes_match is None:
            self.fail("release docs must publish an artifact byte count")
        self.assertGreater(int(bytes_match.group(1)), 0)

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
