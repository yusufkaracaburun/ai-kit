#!/bin/bash
cat > .ai-kit-setup <<'MARKER'
{
  "version": "0.0.0-fixture",
  "branches": {
    "lifecycle": "development",
    "tracker": "github"
  }
}
MARKER
