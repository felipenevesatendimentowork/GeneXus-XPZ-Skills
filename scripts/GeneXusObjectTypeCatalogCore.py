#!/usr/bin/env python3
"""Shared GeneXus object type catalog load/merge (base + optional parallel-KB override)."""

from __future__ import annotations

import json
from pathlib import Path

CATEGORY_PATH = Path(__file__).with_name("gx-object-type-catalog.json")
DEFAULT_OVERRIDE_RELATIVE = Path("scripts") / "gx-object-type-catalog.override.json"


def normalize_catalog_types(raw_types: object, source_label: str) -> dict[str, dict[str, object]]:
    if not isinstance(raw_types, dict):
        raise RuntimeError(f"Invalid object type catalog format: {source_label}")

    normalized_types: dict[str, dict[str, object]] = {}
    for canonical_type, payload in raw_types.items():
        if not isinstance(payload, dict):
            raise RuntimeError(f"Invalid entry for type {canonical_type!r} in {source_label}")
        entry = dict(payload)
        entry["canonicalType"] = str(canonical_type)
        normalized_types[str(canonical_type)] = entry
    return normalized_types


def load_gx_object_type_catalog_file(path: Path) -> dict[str, object]:
    """Load one object type catalog JSON file."""
    try:
        catalog = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError as exc:
        raise RuntimeError(f"Object type catalog not found: {path}") from exc

    return {
        "version": int(catalog.get("version", 0)),
        "types": normalize_catalog_types(catalog.get("types"), str(path)),
        "schemaVersion": catalog.get("schemaVersion"),
    }


def merge_gx_object_type_catalogs(base: dict[str, object], override: dict[str, object] | None) -> dict[str, object]:
    """Merge override types onto base; override wins per canonical type name."""
    merged_types = dict(base["types"])
    if override is not None:
        merged_types.update(override["types"])

    merged: dict[str, object] = {
        "version": int(base.get("version", 0)),
        "types": merged_types,
    }
    if override is not None and override.get("schemaVersion") is not None:
        merged["schemaVersion"] = override["schemaVersion"]
    return merged


def resolve_parallel_kb_root(source_root: Path, parallel_kb_root: Path | None) -> Path | None:
    if parallel_kb_root is not None:
        return parallel_kb_root.resolve()
    if source_root.name.casefold() == "objetosdakbemxml":
        return source_root.parent.resolve()
    return None


def resolve_parallel_kb_root_from_index_path(
    index_path: Path,
    parallel_kb_root: Path | None,
) -> Path | None:
    if parallel_kb_root is not None:
        return parallel_kb_root.resolve()
    parent = index_path.parent.resolve()
    if parent.name.casefold() == "kbintelligence":
        return parent.parent.resolve()
    return None


def resolve_catalog_override_path(
    parallel_kb_root: Path | None,
    catalog_override_path: Path | None,
) -> Path | None:
    if catalog_override_path is not None:
        resolved = catalog_override_path.resolve()
        return resolved if resolved.is_file() else None
    if parallel_kb_root is None:
        return None
    candidate = parallel_kb_root / DEFAULT_OVERRIDE_RELATIVE
    return candidate if candidate.is_file() else None


def build_type_guid_index(types_by_name: dict[str, dict[str, object]]) -> dict[str, str]:
    return {
        str(entry["objectTypeGuid"]).lower(): canonical_type
        for canonical_type, entry in types_by_name.items()
        if entry.get("objectTypeGuid")
    }


def load_gx_object_type_catalog() -> dict[str, object]:
    """Load the shared base object type catalog (no local override)."""
    return load_gx_object_type_catalog_file(CATEGORY_PATH)


def resolve_effective_object_type_catalog(
    source_root: Path,
    parallel_kb_root: Path | None = None,
    catalog_override_path: Path | None = None,
    base_catalog_path: Path | None = None,
) -> tuple[dict[str, object], Path | None]:
    """Resolve base + optional override into the effective catalog for indexing."""
    base_path = (base_catalog_path or CATEGORY_PATH).resolve()
    base_catalog = load_gx_object_type_catalog_file(base_path)
    resolved_parallel = resolve_parallel_kb_root(source_root, parallel_kb_root)
    override_path = resolve_catalog_override_path(resolved_parallel, catalog_override_path)
    override_catalog = load_gx_object_type_catalog_file(override_path) if override_path else None
    merged = merge_gx_object_type_catalogs(base_catalog, override_catalog)
    return merged, override_path


def resolve_effective_object_type_catalog_for_query(
    index_path: Path,
    parallel_kb_root: Path | None = None,
    catalog_override_path: Path | None = None,
    base_catalog_path: Path | None = None,
) -> tuple[dict[str, object], Path | None]:
    """Resolve base + optional override for Query-KbIntelligenceIndex (semantic gate)."""
    base_path = (base_catalog_path or CATEGORY_PATH).resolve()
    base_catalog = load_gx_object_type_catalog_file(base_path)
    resolved_parallel = resolve_parallel_kb_root_from_index_path(index_path, parallel_kb_root)
    override_path = resolve_catalog_override_path(resolved_parallel, catalog_override_path)
    override_catalog = load_gx_object_type_catalog_file(override_path) if override_path else None
    merged = merge_gx_object_type_catalogs(base_catalog, override_catalog)
    return merged, override_path
