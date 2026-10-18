"""Live test against a real Google Cloud project (tests/integration).

Skipped unless DF_YAML_TEST_PROJECT is set. Uses Application Default
Credentials. Everything is created under dfyaml-<random suffix> and destroyed
at the end, also when a step fails. The streaming job runs one small worker
for the few minutes the test takes.

  apply  ->  plan shows no changes  ->  apply revision 2 (in-place update of
         the pipeline)  ->  plan shows no changes  ->  destroy

Optional environment variables:
  DF_YAML_TEST_REGION     region (default europe-west1)
  DF_YAML_TEST_PIPELINES  "true" to also test a paused Data Pipeline (needs
                          the Data Pipelines API and an App Engine region)
"""
import json
import os
import secrets
import shutil
import subprocess

import pytest

from conftest import REPO

PROJECT = os.environ.get("DF_YAML_TEST_PROJECT")

pytestmark = pytest.mark.skipif(not PROJECT, reason="set DF_YAML_TEST_PROJECT to run the live test")


def terraform(binary, args, cwd, env):
    return subprocess.run(
        [binary, *args], cwd=cwd, env=env, capture_output=True, text=True, encoding="utf-8", timeout=3600
    )


def check(result, what):
    assert result.returncode == 0, f"{what} failed:\n{result.stdout}\n{result.stderr}"


def test_live_lifecycle(terraform_bin, tmp_path):
    suffix = "t" + secrets.token_hex(3)
    work = tmp_path / "repo"
    shutil.copytree(REPO, work, ignore=shutil.ignore_patterns(".git", ".terraform*", "*.tfstate*", "__pycache__", ".pytest_cache"))
    cwd = work / "tests" / "integration"
    env = dict(os.environ, TF_IN_AUTOMATION="1", CHECKPOINT_DISABLE="1")

    def variables(revision):
        return [
            "-var", f"project_id={PROJECT}",
            "-var", f"suffix={suffix}",
            "-var", f"region={os.environ.get('DF_YAML_TEST_REGION', 'europe-west1')}",
            "-var", f"revision={revision}",
            "-var", f"enable_pipeline={os.environ.get('DF_YAML_TEST_PIPELINES', 'false')}",
        ]

    def assert_no_changes(revision):
        result = terraform(terraform_bin, ["plan", "-input=false", "-no-color", "-detailed-exitcode", *variables(revision)], cwd, env)
        assert result.returncode == 0, f"expected an empty plan after apply (exit code {result.returncode}):\n{result.stdout}\n{result.stderr}"

    check(terraform(terraform_bin, ["init", "-input=false", "-no-color"], cwd, env), "init")
    try:
        check(terraform(terraform_bin, ["apply", "-input=false", "-no-color", "-auto-approve", *variables(1)], cwd, env), "apply")
        assert_no_changes(1)

        outputs = json.loads(terraform(terraform_bin, ["output", "-json"], cwd, env).stdout)
        jobs = outputs["jobs"]["value"]
        assert sorted(jobs) == ["stream"]
        assert jobs["stream"]["job_id"]
        assert jobs["stream"]["type"] == "JOB_TYPE_STREAMING"
        assert jobs["stream"]["state"] in ("JOB_STATE_PENDING", "JOB_STATE_QUEUED", "JOB_STATE_RUNNING"), jobs["stream"]

        check(terraform(terraform_bin, ["apply", "-input=false", "-no-color", "-auto-approve", *variables(2)], cwd, env), "apply revision 2")
        assert_no_changes(2)
    finally:
        check(terraform(terraform_bin, ["destroy", "-input=false", "-no-color", "-auto-approve", *variables(2)], cwd, env), "destroy")
