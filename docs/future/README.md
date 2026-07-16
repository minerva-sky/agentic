# Future Features

This directory contains design documentation for features that are planned but not yet implemented in the Agentic framework.

## Status Legend

- 📋 **Designed** - Comprehensive architecture documentation exists
- 🏗️ **In Progress** - Currently being implemented
- ✅ **Implemented** - Feature complete and merged to main

## Features

### Artifact System (📋 → 🏗️ Redesigning)

**Status**: Architecture redesign in progress
**Location**: `artifact-system/`
**Last Updated**: 2026-01-05

Original comprehensive design archived. Currently redesigning with focus on:
1. **Workspace Management** - Isolated execution environments for file generation
2. **Artifact Management** - Graph-based artifact reference model (not linear dependencies)

**Key Decision**: Moving from linear task dependencies to graph-based artifact references, where artifacts can reference other artifacts within a workspace.

**Architecture Review**: See `.architecture/reviews/artifact-generation-system---documentation-vs-implementation-gap-analysis-COMPLETE.md`

---

## Process

When a future feature moves to active development:
1. Create new architecture review with revised design
2. Update status in this README
3. Link to ADR when architectural decisions are finalized
4. Move documentation to main `/docs` when implementation begins
