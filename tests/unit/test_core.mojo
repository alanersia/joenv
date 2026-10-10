from std.pathlib import Path
from std.os import makedirs
from std.tempfile import TemporaryDirectory
from std.testing import assert_equal, assert_false, assert_true, assert_raises, TestSuite
from std.subprocess import run as capture

from src.config.manifest import Dependency, Manifest, lock_text, manifest_text, parse_lock, parse_manifest, upsert
from src.git.source import normalize_repository, repository_name, run_process, safe_name, shell_quote
from src.installer.install import install_checkout
from src.resolver.package import detect_package


def test_repository_urls_normalize_to_one_identity() raises:
    var shorthand = normalize_repository("github.com/alanersia/typejo")
    var https = normalize_repository("https://github.com/alanersia/typejo.git")
    assert_equal(shorthand, "https://github.com/alanersia/typejo.git")
    assert_equal(shorthand, https)
    assert_equal(repository_name(https), "typejo")


def test_only_safe_github_paths_and_package_names_are_accepted() raises:
    assert_true(safe_name("typejo"))
    assert_false(safe_name("../typejo"))
    with assert_raises():
        _ = normalize_repository("https://github.com/alanersia/../../etc")
    with assert_raises():
        _ = normalize_repository("https://github.com.evil.test/alanersia/typejo")
    assert_equal(run_process("/bin/false", List[String]()), 1)


def test_manifest_and_lock_round_trip_git_dependencies() raises:
    var manifest_text_value = '[package]\nname = "my-app"\nversion = "0.1.0"\n\n[dependencies]\ntypejo = { git = "https://github.com/alanersia/typejo.git" }\n'
    var manifest = parse_manifest(manifest_text_value)
    assert_equal(manifest.name, "my-app")
    assert_equal(manifest.dependencies[0].git, "https://github.com/alanersia/typejo.git")
    var lock = List[Dependency]()
    lock.append(Dependency("typejo", manifest.dependencies[0].git, "0123456789012345678901234567890123456789", "typejo"))
    var parsed = parse_lock(lock_text(lock))
    assert_equal(parsed[0].name, "typejo")
    assert_equal(parsed[0].subdir, "typejo")
    assert_equal(manifest_text(parse_manifest(manifest_text(manifest))), manifest_text_value)


def test_unsupported_dependency_fields_fail_loudly() raises:
    with assert_raises():
        _ = parse_manifest('[package]\nname = "app"\nversion = "0.1.0"\n[dependencies]\ntypejo = { git = "https://github.com/alanersia/typejo.git", branch = "main" }\n')


def test_package_resolver_uses_repo_name_and_rejects_ambiguity() raises:
    var temp = TemporaryDirectory(prefix="joenv-resolver-test-")
    var checkout = Path(temp.name)
    var package = checkout.joinpath("typejo")
    makedirs(package.path)
    package.joinpath("__init__.mojo").write_text("# typejo")
    var selected = detect_package(checkout, "typejo")
    assert_equal(selected.name, "typejo")
    assert_equal(selected.subdir, "typejo")
    var other = checkout.joinpath("other")
    makedirs(other.path)
    other.joinpath("__init__.mojo").write_text("# other")
    with assert_raises():
        _ = detect_package(checkout, "missing")


def test_package_resolver_requires_a_package_entrypoint() raises:
    var temp = TemporaryDirectory(prefix="joenv-empty-repo-")
    with assert_raises():
        _ = detect_package(Path(temp.name), "typejo")


def test_upsert_replaces_duplicate_package_metadata() raises:
    var dependencies = List[Dependency]()
    upsert(dependencies, Dependency("typejo", "https://github.com/alanersia/typejo.git"))
    upsert(dependencies, Dependency("typejo", "https://github.com/alanersia/typejo.git", "0123456789012345678901234567890123456789", "typejo"))
    assert_equal(len(dependencies), 1)
    assert_equal(dependencies[0].subdir, "typejo")


def test_install_replaces_existing_package_and_rejects_traversal() raises:
    var temp = TemporaryDirectory(prefix="joenv-install-test-")
    var root = Path(temp.name)
    var checkout = root.joinpath("checkout")
    var package = checkout.joinpath("typejo")
    makedirs(package.path)
    package.joinpath("__init__.mojo").write_text("# installed")
    package.joinpath("version.mojo").write_text("# first")
    _ = capture("git init -q " + shell_quote(checkout.path))
    _ = capture("git -C " + shell_quote(checkout.path) + " add typejo")
    _ = capture("git -C " + shell_quote(checkout.path) + " -c user.name=Joenv -c user.email=joenv@example.invalid commit -qm fixture")
    install_checkout(root, "typejo", checkout, "typejo")
    package.joinpath("version.mojo").write_text("# second")
    install_checkout(root, "typejo", checkout, "typejo")
    var installed = root.joinpath("mojo_packages").joinpath("packages").joinpath("typejo")
    assert_equal(installed.joinpath("version.mojo").read_text(), "# second")
    with assert_raises():
        install_checkout(root, "typejo", checkout, "../outside")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
