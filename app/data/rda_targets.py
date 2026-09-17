"""Daily RDA and Adequate Intake (AI) targets used for nutrient pacing and ceilings.

Values are sourced directly from the primary ICMR-NIN publication:
*Nutrient Requirements for Indians: Recommended Dietary Allowances (RDA)
and Estimated Average Requirements (EAR) - 2020*, National Institute of Nutrition.
Reference: Adult Men (19-39 years, reference weight 65 kg).
URL: https://www.nin.res.in/rdabook/brief_note.pdf

Primary Source Citations per Nutrient:
1. Vitamin D (15.0 mcg / 600 IU): Table 3 (Summary of RDA for Indians 2020)
2. Vitamin B12 (2.2 mcg): Table 3 & Table 8.2 (Summary of RDA for Indians 2020)
3. Iron (19.0 mg): Table 3 (Summary of RDA for Indians 2020)
4. Calcium (1000.0 mg): Table 3 (Summary of RDA for Indians 2020)
5. Magnesium (440.0 mg): Table 3 (Summary of RDA for Indians 2020)
6. Zinc (17.0 mg): Table 3 (Summary of RDA for Indians 2020)
7. Potassium (3510.0 mg): Table 11.2 & Summary Table on Adequate Intake (AI)
8. Omega-3 (2.2 g): Brief Note & Chapter on Dietary Fats (n-3 PUFA required amount: 2.2 g/day)
9. Folate / B9 (300.0 mcg): Table 3 (Summary of RDA for Indians 2020)
"""

TARGET_TYPES = {
    "vitaminD_mcg": "RDA",
    "b12_mcg": "RDA",
    "iron_mg": "RDA",
    "calcium_mg": "RDA",
    "magnesium_mg": "RDA",
    "zinc_mg": "RDA",
    "potassium_mg": "AI",
    "omega3_g": "AI",
    "folate_mcg": "RDA",
}

DAILY_RDA = {
    "vitaminD_mcg": 15.0,     # mcg (600 IU) - Table 3
    "b12_mcg": 2.2,           # mcg - Table 3
    "iron_mg": 19.0,          # mg - Table 3
    "calcium_mg": 1000.0,     # mg - Table 3
    "magnesium_mg": 440.0,    # mg - Table 3
    "zinc_mg": 17.0,          # mg - Table 3
    "potassium_mg": 3510.0,   # mg - Adequate Intake (AI), Table 11.2
    "omega3_g": 2.2,          # g - n-3 PUFA Adequate Intake (AI), Brief Note
    "folate_mcg": 300.0,      # mcg - Table 3
}

WEEKLY_RDA = {key: round(value * 7, 2) if value is not None else None for key, value in DAILY_RDA.items()}

RDA_SOURCE = "ICMR-NIN RDA and EAR 2020 (Adult Men, 65 kg reference)"

