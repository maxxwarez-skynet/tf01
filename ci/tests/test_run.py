"""Tests for CI routing and saved-plan handling; no cloud calls."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("ci_run", REPO / "ci/run.py")
ci = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ci)


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.env = {
            "RUN_DEPLOYMENT": "true",
            "CI_PIPELINE_SOURCE": "web",
            "CI_COMMIT_REF_PROTECTED": "true",
            "CI_DEFAULT_BRANCH": "main",
            "CI_COMMIT_BRANCH": "main",
            "CI_PIPELINE_ID": "101",
            "CI_COMMIT_SHA": "a" * 40,
            "CI_PROJECT_ID": "42",
            "CI_JOB_ID": "202",
            "DEPLOY_TARGET": "azure-aira-dev-foundation",
            "ARM_CLIENT_ID": "client",
            "ARM_TENANT_ID": "tenant",
            "ARM_SUBSCRIPTION_ID": "subscription",
            "STATE_RESOURCE_GROUP": "state-rg",
            "STATE_STORAGE_ACCOUNT": "statetest",
            "STATE_CONTAINER": "tfstate",
            "AZURE_ID_TOKEN": "test-only-token",
        }

    def test_manifest_paths_and_unique_states(self):
        targets = [ci.resolve_target(name) for name in ci.targets()]
        self.assertEqual(len(targets), len({target["state_key"] for target in targets}))
        for target in targets:
            self.assertTrue((REPO / target["root"] / "versions.tf").is_file())
            for dependency in target["requires"]:
                self.assertIn(dependency, ci.targets())

    def test_unknown_target_rejected(self):
        with self.assertRaisesRegex(ValueError, "Unknown DEPLOY_TARGET"):
            ci.resolve_target("../../bootstrap")

    def test_azure_metadata_must_match_path(self):
        with patch.object(ci.json, "loads", side_effect=[
            {"test": {"root": "live/azure/aira/dev/centralindia/foundation", "requires": []}},
            {"deployment_id": "different", "environment": "dev", "location": "centralindia"},
        ]):
            with self.assertRaisesRegex(ValueError, "disagrees"):
                ci.resolve_target("test")

    def test_deployment_guard(self):
        ci.deployment_guard(self.env)
        for key, value in (("RUN_DEPLOYMENT", "false"), ("CI_PIPELINE_SOURCE", "merge_request_event"),
                           ("CI_COMMIT_BRANCH", "feature"), ("CI_COMMIT_REF_PROTECTED", "false")):
            with self.subTest(key=key), self.assertRaises(ValueError):
                ci.deployment_guard(dict(self.env, **{key: value}))

    def test_dependency_state_config_is_derived(self):
        target = ci.resolve_target("azure-aira-dev-data")
        backend = ci.backend_config(self.env, target)
        env = dict(self.env, TF_VAR_key_vault_name="test-vault",
                   TF_VAR_mysql_password="test-only-password", TF_VAR_state_backend="wrong")
        result = ci.plan_inputs(env, target, backend)
        self.assertEqual(json.loads(result["TF_VAR_state_backend"]), {
            "resource_group_name": "state-rg",
            "storage_account_name": "statetest",
            "container_name": "tfstate",
        })
        self.assertEqual(backend["key"], "azure/aira/dev/centralindia/data.tfstate")

    def test_missing_secret_error_does_not_print_other_secrets(self):
        target = ci.resolve_target("azure-aira-dev-data")
        with self.assertRaisesRegex(ValueError, "TF_VAR_mysql_password"):
            ci.plan_inputs(dict(self.env, TF_VAR_key_vault_name="test-vault"), target,
                           ci.backend_config(self.env, target))

    def test_aws_deployment_metadata_cannot_drift(self):
        target = ci.resolve_target("aws-aira-dev-recordings")
        env = dict(self.env, TF_VAR_aws_account_id="123456789012",
                   TF_VAR_bucket_name="test", TF_VAR_region="wrong", TF_VAR_environment="wrong")
        result = ci.plan_inputs(env, target, ci.backend_config(env, target))
        self.assertEqual(result["TF_VAR_region"], "ap-south-1")
        self.assertEqual(result["TF_VAR_environment"], "dev")
        self.assertEqual(result["TF_VAR_deployment_id"], "aira")

    def test_oidc_uses_job_credentials(self):
        target = ci.resolve_target("aws-aira-dev-recordings")
        with tempfile.TemporaryDirectory() as directory:
            env = dict(self.env, AWS_ROLE_ARN="arn:aws:iam::123456789012:role/test",
                       AWS_ID_TOKEN="test-aws-token", ARM_CLIENT_SECRET="old-secret",
                       AWS_ACCESS_KEY_ID="old-key", AWS_SECRET_ACCESS_KEY="old-secret")
            result = ci.cloud_auth(env, target, Path(directory))
            self.assertEqual(result["ARM_OIDC_TOKEN"], "test-only-token")
            self.assertNotIn("ARM_CLIENT_SECRET", result)
            self.assertNotIn("AWS_ACCESS_KEY_ID", result)
            self.assertEqual(Path(result["AWS_WEB_IDENTITY_TOKEN_FILE"]).read_text(), "test-aws-token")

    def test_saved_plan_binding_and_expiration(self):
        with tempfile.TemporaryDirectory() as directory:
            plan = Path(directory) / "plan"
            plan.write_bytes(b"mock-saved-plan")
            expected = {"target": "test", "pipeline": "101", "commit": "abc", "backend": {"key": "test"}}
            metadata = dict(expected, created_at=1000, sha256=ci.sha256(plan))
            ci.verify_plan(metadata, expected, plan, now=1100)
            for key in expected:
                with self.subTest(key=key), self.assertRaises(ValueError):
                    ci.verify_plan(metadata, dict(expected, **{key: "different"}), plan, now=1100)
            with self.assertRaisesRegex(ValueError, "expired"):
                ci.verify_plan(metadata, expected, plan, now=5000)
            plan.write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "checksum"):
                ci.verify_plan(metadata, expected, plan, now=1100)

    def test_apply_only_consumes_saved_plan(self):
        target = ci.resolve_target(self.env["DEPLOY_TARGET"])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifacts = root / ".ci-plan"
            artifacts.mkdir()
            work = root / "work"
            work.mkdir()
            plan = artifacts / "deployment.tfplan"
            plan.write_bytes(b"mock-saved-plan")
            expected = ci.identity(self.env, target, ci.backend_config(self.env, target))
            (artifacts / "metadata.json").write_text(json.dumps(
                dict(expected, created_at=ci.time.time(), sha256=ci.sha256(plan))))
            with patch.object(ci, "REPO", root), patch.object(ci, "resolve_target", return_value=target), patch.object(ci, "run") as run:
                ci.deploy("apply", self.env, work)
                commands = [call.args[0] for call in run.call_args_list]
            self.assertEqual([command[2] for command in commands], ["init", "apply"])
            self.assertEqual(commands[-1][-1], str(plan))
            self.assertNotIn("-auto-approve", commands[-1])


if __name__ == "__main__":
    unittest.main()
