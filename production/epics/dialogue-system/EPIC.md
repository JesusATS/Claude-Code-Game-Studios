# Epic: Dialogue System

> **Layer**: Core
> **GDD**: design/gdd/dialogue-system.md
> **Architecture Module**: `DialogueManager` (`src/core/dialogue/dialogue_manager.gd` — Autoload)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories dialogue-system`

## Overview

This epic implements *Lux Aeterna*'s conversation engine. `DialogueManager` is an Autoload (position determined by ADR-0002 Autoload load order) backed by `DialogueGraph` data resources — authored conversation trees stored as `.tres` files. Each resource type (`DialogueGraph`, `DialogueNode`, `DialogueCondition`, `DialogueChoice`, `DialogueFlagWrite`) lives in its own standalone `.gd` file with `class_name … extends Resource` (required for Godot 4.x `.tres` deserialization). At runtime, `start_dialogue(graph_path)` loads the graph, `advance()` steps through nodes evaluating `StoryState.check_flag()` conditions to select branches, and `select_choice(index)` resolves player decisions. Significant nodes execute `StoryState.set_flag()` writes via `DialogueFlagWrite` payloads. The system emits `line_delivered(speaker_id, text, is_recognition, importance)`, `choices_presented(choices_array)`, and `dialogue_ended()` — all consumed by the dialogue UI. Narrative Event flags (typed Dictionaries in StoryState) allow fully differentiated responses to emotionally significant events rather than simple boolean branches.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Data-Driven Resource Registry | DialogueGraph + node types as Resource subclasses in standalone .gd files; loaded via ResourceRegistry / load() | HIGH |
| ADR-0002: Autoload Singleton Strategy | DialogueManager qualifies as Autoload (state survives scenes, 3+ unrelated consumers, no scene context); position 3 in load order | LOW |
| ADR-0005: RefCounted Class Naming | All dialogue Resource subtypes in own .gd files with class_name; typed collections in public APIs | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-DLG-001 | `DialogueManager` Autoload | ADR-0002 ✅ |
| TR-DLG-002 | `DialogueGraph` etc. in own `.gd` files with `class_name` | ADR-0001/0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/dialogue-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories dialogue-system` to break this epic into implementable stories.
