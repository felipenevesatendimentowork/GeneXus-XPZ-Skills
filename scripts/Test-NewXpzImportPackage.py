#!/usr/bin/env python3
"""Regression tests for New-XpzImportPackage.py."""

from __future__ import annotations

import importlib.util
import tempfile
from pathlib import Path
from typing import Any


OBJECT_XML = """<?xml version="1.0" encoding="utf-8"?>
<Object type="11111111-1111-1111-1111-111111111111" name="Cliente">
  <Properties>
    <Property>
      <Name>Name</Name>
      <Value>Cliente</Value>
    </Property>
  </Properties>
</Object>
"""


def load_engine(script_dir: Path) -> Any:
    engine_path = script_dir / "New-XpzImportPackage.py"
    spec = importlib.util.spec_from_file_location("new_xpz_import_package", engine_path)
    if spec is None or spec.loader is None:
        raise SystemExit(f"Unable to load engine: {engine_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_accepts_regular_object(engine: Any) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        front_dir = Path(temp_dir)
        (front_dir / "Cliente.xml").write_text(OBJECT_XML, encoding="utf-8")

        objects, attributes = engine.classify_front_xmls(front_dir)

        assert len(objects) == 1, f"expected 1 object, got {len(objects)}"
        assert len(attributes) == 0, f"expected 0 attributes, got {len(attributes)}"


def assert_blocks_reference_named_object(engine: Any) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        front_dir = Path(temp_dir)
        (front_dir / "Cliente_referencia.xml").write_text(OBJECT_XML, encoding="utf-8")

        try:
            engine.classify_front_xmls(front_dir)
        except RuntimeError as exc:
            message = str(exc)
            assert message.startswith("BLOCK: XML de referencia/exemplo/template"), message
            return

        raise AssertionError("expected reference-like XML to block packaging")


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    engine = load_engine(script_dir)

    assert_accepts_regular_object(engine)
    assert_blocks_reference_named_object(engine)

    print("Test-NewXpzImportPackage.py: passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
