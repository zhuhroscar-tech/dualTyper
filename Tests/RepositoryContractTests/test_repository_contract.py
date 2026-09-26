import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class RepositoryContractTests(unittest.TestCase):
    def test_required_project_files_are_present(self):
        required = [
            "README.md",
            "README.zh-CN.md",
            "CHANGELOG.md",
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

    def test_release_packaging_points_to_supported_menu_bar_artifact(self):
        packaging = (ROOT / "docs" / "release-packaging.md").read_text(encoding="utf-8")

        self.assertIn("supported public artifact is the shortcut-driven menu-bar app", packaging)
        self.assertIn("./scripts/package-menubar-dmg.sh", packaging)
        self.assertIn("DualTyper.app", packaging)
        self.assertIn("Applications -> /Applications", packaging)
        self.assertIn("not the downloadable release product", packaging)
        self.assertNotIn("The `.inputmethod` bundle is the installable engine", packaging)
        self.assertNotIn("dist/DualTyper-0.1.0.dmg", packaging)
        self.assertNotIn("System Settings → Keyboard", packaging)

    def test_changelog_tracks_source_releases_without_relabeling_download(self):
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        zh_readme = (ROOT / "README.zh-CN.md").read_text(encoding="utf-8")

        for version in ("0.3.4", "0.3.3", "0.3.2", "0.3.1", "0.3.0", "0.1.0"):
            self.assertRegex(changelog, rf"(?m)^## {re.escape(version)}\b", f"missing changelog entry for {version}")
        self.assertIn("source-quality release", changelog)
        self.assertIn("downloadable DMG remains `v0.3.0`", changelog)
        self.assertIn("CHANGELOG.md", readme)
        self.assertIn("CHANGELOG.md", zh_readme)

    def test_ci_exercises_core_test_paths(self):
        workflow = (ROOT / ".github" / "workflows" / "core.yml").read_text(encoding="utf-8")
        self.assertIn("branches: [main]", workflow)
        self.assertIn('tags: ["v*"]', workflow)
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
