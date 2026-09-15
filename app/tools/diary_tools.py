DEFAULT_TARGETS = {
    "calories": 2350.0,
    "proteinG":  155.0,
    "carbsG":    260.0,
    "fatG":       70.0,
    "fiberG":     35.0,
}

async def get_remaining_macros(today_diary: list[dict], targets: dict | None = None) -> dict:
    active_targets = dict(DEFAULT_TARGETS)
    if targets:
        for k, v in targets.items():
            if v is not None:
                active_targets[k] = float(v)

    consumed = {k: 0.0 for k in active_targets}
    for entry in today_diary:
        for k in active_targets:
            consumed[k] += float(entry.get(k, 0))

    remaining = {k: round(active_targets[k] - consumed[k], 1) for k in active_targets}
    return {
        "consumed":  {k: round(v, 1) for k, v in consumed.items()},
        "remaining": remaining,
        "targets":   active_targets,
    }
