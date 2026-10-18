"""The JSON Schema: is it valid, do the examples conform to it, and does it
stay in a shape that validation.tf can read?"""
import re

import pytest
from jsonschema import Draft7Validator

from conftest import REPO, example_configs, fixture_configs, load_yaml, object_definitions, ref_names, walk

# validation.tf walks the YAML this many levels deep (walk_0 ... walk_5).
WALK_LEVELS = 6


def test_schema_is_valid_draft7(schema):
    Draft7Validator.check_schema(schema)


@pytest.mark.parametrize("path", example_configs() + fixture_configs(), ids=lambda p: str(p.relative_to(REPO)))
def test_configuration_conforms_to_schema(schema, path):
    errors = sorted(Draft7Validator(schema).iter_errors(load_yaml(path)), key=lambda e: list(e.path))
    assert not errors, "\n".join(f"{'/'.join(map(str, e.path))}: {e.message}" for e in errors)


def test_object_definitions_are_closed(schema):
    """Unknown-key checks rely on every object definition listing its keys."""
    for name, d in object_definitions(schema).items():
        assert d.get("type") == "object", f"{name} needs type: object"
        assert d.get("additionalProperties") is False, f"{name} needs additionalProperties: false"


def test_nested_objects_are_named_definitions(schema):
    """validation.tf only follows $refs, so an inline object with properties
    would never be checked."""
    def inline_objects(node, where):
        if isinstance(node, dict):
            if "properties" in node and where.count("/") > 1:
                yield where
            for k, v in node.items():
                yield from inline_objects(v, f"{where}/{k}")
        elif isinstance(node, list):
            for i, v in enumerate(node):
                yield from inline_objects(v, f"{where}/{i}")

    offenders = []
    for name, d in schema["definitions"].items():
        for prop, p in d.get("properties", {}).items():
            offenders += list(inline_objects(p, f"definitions/{name}/{prop}"))
    for prop, p in schema["properties"].items():
        offenders += list(inline_objects(p, f"properties/{prop}"))
    assert not offenders, offenders


def test_schema_depth_fits_the_validation_walk(schema):
    defs = schema["definitions"]

    def depth(name, seen=()):
        node = schema if name == "root" else defs[name]
        best = 0
        for prop in node.get("properties", {}).values():
            children = [n for n in ref_names(prop) if "properties" in defs[n]]
            for key in ("items", "additionalProperties"):
                if isinstance(prop.get(key), dict):
                    children += [n for n in ref_names(prop[key]) if "properties" in defs[n]]
            for child in children:
                if child not in seen:
                    best = max(best, 1 + depth(child, seen + (child,)))
        return best

    assert depth("root") < WALK_LEVELS, f"schema is {depth('root')} levels deep; add walk levels to validation.tf"


def test_patterns_are_re2_compatible(schema):
    """Terraform evaluates the patterns with RE2: no lookaround or backreferences."""
    patterns = re.findall(r'"pattern":\s*"((?:[^"\\]|\\.)*)"', (REPO / "schemas" / "dataflow-config.schema.json").read_text(encoding="utf-8"))
    assert patterns
    for p in patterns:
        assert not re.search(r"\(\?[=!<]|\\[1-9]", p), p


def test_defaults_forbid_identity_keys(schema):
    """Each defaults.<type> names its forbidden keys where main.tf reads them
    (allOf[1].propertyNames.not.enum), and they exist on the definition."""
    props = schema["definitions"]["defaults"]["properties"]
    for type_name, expected in [("jobs", ["name"]), ("pipelines", ["name", "job_name"])]:
        all_of = props[type_name]["allOf"]
        definition = all_of[0]["$ref"].split("/")[-1]
        forbidden = all_of[1]["propertyNames"]["not"]["enum"]
        assert forbidden == expected, type_name
        assert set(forbidden) <= set(schema["definitions"][definition]["properties"])


def test_complete_example_uses_every_key(schema):
    """examples/complete is documented as using every configuration key."""
    used = {(d, k) for d, k, _ in walk(schema, load_yaml(REPO / "examples" / "complete" / "config.yaml"), "root")}
    expected = {(name, key) for name, d in object_definitions(schema).items() for key in d["properties"]}
    expected |= {("root", key) for key in schema["properties"]}
    missing = sorted(f"{d}.{k}" for d, k in expected - used)
    assert not missing, f"examples/complete/config.yaml does not use: {missing}"


INVALID = [
    ("unknown top-level key", {"job": {}}),
    ("unknown job key", {"jobs": {"a": {"descripton": "x"}}}),
    ("jobs as a list", {"jobs": [{"name": "a"}]}),
    ("job name with underscore", {"jobs": {"a": {"name": "my_job"}}}),
    ("template path not on Cloud Storage", {"jobs": {"a": {"template_gcs_path": "s3://x/y"}}}),
    ("temp location not on Cloud Storage", {"jobs": {"a": {"temp_location": "/tmp"}}}),
    ("google template without name", {"jobs": {"a": {"google_template": {"version": "latest"}}}}),
    ("bad google template type", {"jobs": {"a": {"google_template": {"name": "x", "type": "legacy"}}}}),
    ("bad ip configuration", {"jobs": {"a": {"ip_configuration": "PRIVATE"}}}),
    ("bad on_delete", {"jobs": {"a": {"on_delete": "DRAIN"}}}),
    ("too many workers", {"jobs": {"a": {"max_workers": 5000}}}),
    ("bad pipeline type", {"pipelines": {"p": {"type": "CRON"}}}),
    ("bad pipeline state", {"pipelines": {"p": {"state": "STOPPED"}}}),
    ("pipeline ID with spaces", {"pipelines": {"p": {"name": "my pipeline"}}}),
    ("pipeline-only key on a job", {"jobs": {"a": {"schedule": "0 1 * * *"}}}),
    ("job-only key on a pipeline", {"pipelines": {"p": {"on_delete": "drain"}}}),
    ("name as a default", {"defaults": {"jobs": {"name": "x"}}}),
    ("job_name as a default", {"defaults": {"pipelines": {"job_name": "x"}}}),
    ("boolean that is not a placeholder", {"jobs": {"a": {"enable_streaming_engine": "yes please"}}}),
]


@pytest.mark.parametrize("name,config", INVALID, ids=[n for n, _ in INVALID])
def test_invalid_configuration_is_rejected(schema, name, config):
    assert list(Draft7Validator(schema).iter_errors(config)), f"schema accepted: {name}"


def test_patterns_have_no_large_repetitions():
    """RE2 rejects repetition counts above 1000, which would break the plan."""
    text = (REPO / "schemas" / "dataflow-config.schema.json").read_text(encoding="utf-8")
    counts = [int(n) for n in re.findall(r"\{\d*,?(\d+)\}", text)]
    assert all(n <= 1000 for n in counts), counts


def test_placeholders_are_accepted_in_typed_fields(schema):
    config = {
        "jobs": {
            "a": {
                "enabled": "${env == \"dev\"}",
                "name": "job-${env}",
                "max_workers": "${max}",
                "ip_configuration": "${ip}",
                "temp_location": "${temp}",
                "google_template": {"name": "${template}", "type": "${type}"},
            }
        },
        "pipelines": {"p": {"type": "${type}", "state": "${state}", "name": "p_${env}"}},
    }
    errors = list(Draft7Validator(schema).iter_errors(config))
    assert not errors, [e.message for e in errors]
