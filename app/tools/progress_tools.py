from statistics import mean

async def get_weight_trend(weigh_ins: list[dict], weeks: int = 4) -> dict:
    sorted_ins = sorted(weigh_ins, key=lambda w: w.get("date", ""))
    weights = [float(w["weightKg"]) for w in sorted_ins if w.get("weightKg")]
    if not weights:
        return {"trend": [], "delta": 0.0, "latest_avg": None}

    rolling = [
        round(mean(weights[max(0, i - 2): i + 1]), 2)
        for i in range(len(weights))
    ]
    delta = round(rolling[-1] - rolling[0], 2) if len(rolling) > 1 else 0.0
    return {"trend": rolling, "delta": delta, "latest_avg": rolling[-1]}

async def get_workout_trend(
    workout_logs: list[dict],
    exercise_name: str,
) -> list[dict]:
    matches = [
        w for w in workout_logs
        if w.get("exerciseName", "").lower() == exercise_name.lower()
    ]
    return sorted(matches, key=lambda w: w.get("date", ""), reverse=True)[:5]

async def get_adherence_flags(weigh_ins: list[dict]) -> dict:
    sorted_ins = sorted(weigh_ins, key=lambda w: w.get("date", ""))
    weights = [float(w["weightKg"]) for w in sorted_ins if w.get("weightKg")]

    plateau = False
    delta_3wk = None
    if len(weights) >= 3:
        delta_3wk = round(weights[-1] - weights[-3], 2)
        plateau = abs(delta_3wk) <= 0.25

    return {
        "plateau_detected": plateau,
        "weight_delta_3wk": delta_3wk,
    }
