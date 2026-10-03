# Review Checklist for Exercises

All movements added to the Vyayama exercise database must go through a strict safety review process before being merged.

## Who Approves
- **Developer/Curator**: Ensures the data model is fully populated (instructions, mistakes, tags).
- **Fitness Professional**: A certified personal trainer or physiotherapist must review the `form_checklist` and `contraindications`.

## Checklist
1. **Safety First**: Are contraindications correctly listed? (e.g., knee issues for squats).
2. **Form Checklist**: Is the `form_checklist` populated with 2-3 clear, critical safety cues? (e.g., "Keep lower back flat").
3. **Semantic Description**: Does the `semantic_description` accurately describe the movement for screen readers?
4. **Visual Accuracy**: Do the provided poses (start/finish) accurately reflect safe biomechanics?
5. **Attribution**: Are visual assets correctly credited in `assets/ATTRIBUTIONS.md`?

When complete, the `reviewed_by` and `reviewed_at` fields on the `Exercise` model must be filled.
