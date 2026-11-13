#!/usr/bin/env python3
"""Render Helm-based Argo CD Applications without a cluster.

The normal kustomize build only renders the Argo CD Application objects.  This
script follows the chart source in each Application and runs `helm template`,
so chart-level errors (bad values, missing value files, invalid chart output)
are caught locally and in CI.

Argo CD value-file rules are deliberately stricter than Helm's:

* Inline `spec.source.helm.values` is written to a temporary values file.
* `$values/...` entries are resolved against the local checkout.
* Plain `valueFiles` entries are rejected for Helm repository sources because
  Argo CD cannot read a file from a Helm repository.

Applications listed in `hack/render-helm.skip` are skipped with a reason.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = ROOT / ".tmp" / "helm"
DEFAULT_SKIP_FILE = ROOT / "hack" / "render-helm.skip"
KUBE_VERSION = os.environ.get("KUBE_VERSION", "1.33.0")


class RenderError(Exception):
    pass


def load_yaml_documents(path: Path):
    """Yield every YAML document from a file, ignoring empty documents."""
    try:
        with path.open() as handle:
            for document in yaml.safe_load_all(handle):
                if document is not None:
                    yield document
    except yaml.YAMLError as exc:
        raise RenderError(f"{path.relative_to(ROOT)}: invalid YAML: {exc}") from exc


def load_skip_file(path: Path) -> dict[str, str]:
    """Read `<application>: <reason>` lines from the skip file."""
    if not path.is_file():
        return {}

    skipped: dict[str, str] = {}
    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            raise RenderError(
                f"{path.relative_to(ROOT)}: expected '<application>: <reason>', got {line!r}"
            )
        name, reason = line.split(":", 1)
        skipped[name.strip()] = reason.strip() or "no reason given"
    return skipped


def application_sources(spec: dict) -> list[dict]:
    if isinstance(spec.get("sources"), list):
        return [source for source in spec["sources"] if isinstance(source, dict)]
    if isinstance(spec.get("source"), dict):
        return [spec["source"]]
    return []


def find_chart_applications() -> list[dict]:
    """Return chart-backed Application documents with their source files."""
    applications: list[dict] = []
    for path in sorted(ROOT.glob("applications/**/*.yaml")):
        for document in load_yaml_documents(path):
            if not isinstance(document, dict) or document.get("kind") != "Application":
                continue
            spec = document.get("spec") or {}
            sources = application_sources(spec)
            chart_sources = [source for source in sources if source.get("chart")]
            if not chart_sources:
                continue
            applications.append(
                {
                    "path": path,
                    "name": (document.get("metadata") or {}).get("name") or path.stem,
                    "spec": spec,
                    "sources": sources,
                    "chart_source": chart_sources[0],
                }
            )
    return applications


def local_repo_url() -> str | None:
    try:
        result = subprocess.run(
            ["git", "config", "--get", "remote.origin.url"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return result.stdout.strip() or None


def repo_identity(url: str | None) -> str | None:
    """Normalize SSH and HTTPS Git URLs so they can be compared."""
    if not url:
        return None
    value = url.strip().rstrip("/")
    if value.endswith(".git"):
        value = value[:-4]
    if value.startswith("git@"):
        value = value[4:].replace(":", "/", 1)
    if "://" in value:
        value = value.split("://", 1)[1]
    if value.startswith("github.com/"):
        return value[len("github.com/") :]
    return value


def resolve_values_files(
    application: dict, values_dir: Path, repo_url: str | None
) -> list[Path]:
    """Resolve `$values/...` references to files in this checkout."""
    chart_source = application["chart_source"]
    helm = chart_source.get("helm") or {}
    value_files = helm.get("valueFiles") or []
    if not isinstance(value_files, list):
        raise RenderError(f"{application['name']}: helm.valueFiles must be a list")

    resolved: list[Path] = []
    for entry in value_files:
        if not isinstance(entry, str):
            raise RenderError(
                f"{application['name']}: helm.valueFiles entries must be strings"
            )

        if entry.startswith("$values/"):
            ref = entry[1:].split("/", 1)[0]
            values_source = next(
                (source for source in application["sources"] if source.get("ref") == ref),
                None,
            )
            if values_source is None:
                raise RenderError(
                    f"{application['name']}: value file {entry!r} uses ref "
                    f"{ref!r}, but no source defines that ref"
                )

            source_url = values_source.get("repoURL")
            if (
                repo_identity(repo_url)
                and repo_identity(source_url)
                and repo_identity(source_url) != repo_identity(repo_url)
            ):
                raise RenderError(
                    f"{application['name']}: value file {entry!r} points at "
                    f"{source_url!r}, which is not this checkout ({repo_url!r})"
                )

            relative = entry[len(f"$values/") :]
            candidate = (ROOT / relative).resolve()
            try:
                candidate.relative_to(ROOT)
            except ValueError as exc:
                raise RenderError(
                    f"{application['name']}: value file {entry!r} escapes the repository"
                ) from exc
            if not candidate.is_file():
                raise RenderError(
                    f"{application['name']}: value file {entry!r} does not exist "
                    f"({candidate.relative_to(ROOT)})"
                )
            resolved.append(candidate)
            continue

        raise RenderError(
            f"{application['name']}: value file {entry!r} is not under $values/. "
            "Argo CD cannot read value files from a Helm repository source; "
            "move the file into this repository and reference it as "
            f"$values/{entry.lstrip('/')}"
        )

    # Inline values are applied last, matching Argo CD's precedence.
    inline_values = helm.get("values")
    if inline_values is not None:
        values_path = values_dir / f"{application['name']}.yaml"
        values_path.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(inline_values, str):
            values_path.write_text(inline_values)
        else:
            values_path.write_text(yaml.safe_dump(inline_values, sort_keys=False))
        resolved.append(values_path)

    return resolved


def build_helm_command(
    application: dict, values_files: list[Path], values_dir: Path
) -> list[str]:
    chart_source = application["chart_source"]
    helm = chart_source.get("helm") or {}
    spec = application["spec"]
    destination = spec.get("destination") or {}

    release = helm.get("releaseName") or application["name"]
    namespace = helm.get("namespace") or destination.get("namespace") or "default"
    repo_url = chart_source.get("repoURL")
    chart = chart_source.get("chart")
    version = chart_source.get("targetRevision")

    if not repo_url or not chart:
        raise RenderError(
            f"{application['name']}: chart source needs repoURL and chart"
        )
    if not version:
        raise RenderError(
            f"{application['name']}: chart source needs targetRevision (chart version)"
        )

    if repo_url.startswith("oci://"):
        chart_ref = f"{repo_url.rstrip('/')}/{chart}"
        command = ["helm", "template", release, chart_ref]
    elif "://" not in repo_url:
        # Argo CD expects OCI chart registries without the oci:// prefix,
        # while Helm requires it. Treat a scheme-less chart repoURL as OCI.
        chart_ref = f"oci://{repo_url.rstrip('/')}/{chart}"
        command = ["helm", "template", release, chart_ref]
    else:
        chart_ref = chart
        command = [
            "helm",
            "template",
            release,
            chart_ref,
            "--repo",
            repo_url,
        ]

    command.extend(
        [
            "--version",
            version,
            "--namespace",
            namespace,
            "--kube-version",
            KUBE_VERSION,
            "--include-crds",
            "--skip-tests",
        ]
    )

    for values_path in values_files:
        command.extend(["--values", str(values_path)])

    parameters = helm.get("parameters") or []
    if parameters:
        if not isinstance(parameters, list):
            raise RenderError(
                f"{application['name']}: helm.parameters must be a list"
            )
        for parameter in parameters:
            if not isinstance(parameter, dict) or "name" not in parameter:
                raise RenderError(
                    f"{application['name']}: each helm parameter needs a name"
                )
            value = parameter.get("value", "")
            force_string = parameter.get("forceString", False)
            flag = "--set-string" if force_string else "--set"
            command.extend([flag, f"{parameter['name']}={value}"])

    return command


def render_application(application: dict, output: Path, values_dir: Path) -> Path:
    if shutil.which("helm") is None:
        raise RenderError("'helm' not found. Install Helm 3 and retry.")

    repo_url = local_repo_url()
    values_files = resolve_values_files(application, values_dir, repo_url)
    command = build_helm_command(application, values_files, values_dir)

    destination = output / f"{application['name']}.yaml"
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        details = result.stderr.strip() or result.stdout.strip() or "helm failed"
        raise RenderError(f"{application['name']}: {details}")

    if not result.stdout.strip():
        raise RenderError(
            f"{application['name']}: helm rendered no resources"
        )

    destination.write_text(result.stdout)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT),
        help=f"directory for rendered manifests (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--skip-file",
        default=str(DEFAULT_SKIP_FILE),
        help=f"application skip list (default: {DEFAULT_SKIP_FILE})",
    )
    parser.add_argument(
        "--app",
        action="append",
        default=[],
        help="only render this application (repeatable)",
    )
    args = parser.parse_args()

    output = Path(args.output).resolve()
    values_dir = output / "values"
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True)

    skipped = load_skip_file(Path(args.skip_file).resolve())
    applications = find_chart_applications()
    if args.app:
        wanted = set(args.app)
        applications = [app for app in applications if app["name"] in wanted]
        unknown = wanted - {app["name"] for app in applications}
        if unknown:
            raise RenderError(
                "requested application(s) not found: " + ", ".join(sorted(unknown))
            )

    if not applications:
        print("No chart-backed Applications found.")
        return 0

    failures: list[str] = []
    rendered = 0
    for application in applications:
        name = application["name"]
        if name in skipped:
            print(f"skip {name} ({skipped[name]})")
            continue
        try:
            destination = render_application(application, output, values_dir)
        except RenderError as exc:
            failures.append(str(exc))
            print(f"FAIL {name}")
            continue
        print(f"ok   {name} -> {destination.relative_to(ROOT)}")
        rendered += 1

    print(
        f"\nRendered {rendered}/{len(applications)} chart-backed Applications "
        f"into {output.relative_to(ROOT)}."
    )
    if skipped:
        print(f"Skipped {len(skipped)} application(s): {', '.join(sorted(skipped))}")

    if failures:
        print("\nHelm rendering failed:", file=sys.stderr)
        for failure in failures:
            print(f"  - {failure}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RenderError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
