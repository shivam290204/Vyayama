#!/usr/bin/env python3
"""
Exports all exercises from assets/data/exercises.json to exercises_review.csv
for offline review by certified fitness professionals and physiotherapists.
"""

import csv
import json
import os

def export_exercises_csv():
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    json_path = os.path.join(repo_root, 'assets', 'data', 'exercises.json')
    csv_path = os.path.join(repo_root, 'exercises_review.csv')

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    exercises = data.get('exercises', [])
    print(f"Loaded {len(exercises)} exercises from {json_path}")

    fieldnames = [
        'id',
        'name',
        'muscle_group',
        'equipment',
        'met',
        'form_checklist',
        'contraindications',
        'common_mistakes',
        'instructions',
        'reviewed_by',
        'reviewed_at',
        'trainer_status',
        'trainer_notes',
    ]

    with open(csv_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()

        for ex in exercises:
            form_cues = ' | '.join(ex.get('form_checklist', []))
            contra = ', '.join(ex.get('contraindications', []))
            mistakes = ' | '.join(ex.get('common_mistakes', []))
            instructions = ' | '.join(ex.get('instructions', []))

            writer.writerow({
                'id': ex.get('id', ''),
                'name': ex.get('name', ''),
                'muscle_group': ex.get('muscle_group', ''),
                'equipment': ex.get('equipment', ''),
                'met': ex.get('met', ''),
                'form_checklist': form_cues,
                'contraindications': contra,
                'common_mistakes': mistakes,
                'instructions': instructions,
                'reviewed_by': ex.get('reviewed_by', ''),
                'reviewed_at': ex.get('reviewed_at', ''),
                'trainer_status': '',
                'trainer_notes': '',
            })

    print(f"Successfully generated {csv_path} with {len(exercises)} exercises.")

if __name__ == '__main__':
    export_exercises_csv()
