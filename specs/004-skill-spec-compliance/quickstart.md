# Quickstart: Agent Skills Spec Compliance

## Validating Skills

Install the validator (one-time):

```bash
uv tool install git+https://github.com/agentskills/agentskills.git#subdirectory=skills-ref
```

Validate all skills:

```bash
skills-ref validate plugins/kusari/skills/kusari-change-evaluate
skills-ref validate plugins/kusari/skills/kusari-change-fix
```

Expected output for a compliant skill: no output (exit code 0).

## Skill Names (after migration)

| Old Name | New Name |
|----------|----------|
| `/kusari.change.evaluate` | `/kusari-change-evaluate` |
| `/kusari.change.fix` | `/kusari-change-fix` |

## Reading Skill Properties

```bash
skills-ref read-properties plugins/kusari/skills/kusari-change-evaluate
```

Outputs JSON with name, description, license, and metadata.
