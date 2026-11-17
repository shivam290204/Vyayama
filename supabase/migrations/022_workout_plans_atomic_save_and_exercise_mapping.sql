-- 022: atomic workout plan save and exercise ID mapping
-- Forward-only migration to ensure idempotent plan creation and prevent partial writes.

-- 1. Add catalog_id to public.exercises and index it
alter table public.exercises add column if not exists catalog_id text;
create unique index if not exists exercises_catalog_id_idx on public.exercises(catalog_id);

-- 2. Seed exercises from bundled catalog with deterministic UUID v5 IDs
insert into public.exercises (id, catalog_id, name, muscle_group, equipment, instructions, animation_asset, contraindications)
values
  ('5e48e150-9cee-54f0-a5d2-79d7ef5ae7dd'::uuid, 'ex_bodyweight_squat', 'Bodyweight Squat', 'legs', 'none', 'Stand with feet shoulder-width apart, toes slightly turned out.
Brace your core and push your hips back as if sitting into a chair.
Lower until your thighs are about parallel to the floor, or only as far as feels comfortable, keeping your heels down.
Press through your whole foot to stand tall and squeeze your glutes at the top.', 'assets/exercises/squat.webp', array['knee']::text[]),
  ('dbf3b292-1e2d-53e9-bbc5-f231873e1a63'::uuid, 'ex_lunge', 'Forward Lunge', 'legs', 'none', 'Stand tall with feet hip-width apart and hands on your hips.
Step forward into a comfortable stride length.
Lower your back knee toward the floor until both knees are bent to about 90 degrees.
Push through the front heel to return to standing, then switch legs.', 'assets/exercises/lunge.webp', array['knee']::text[]),
  ('46335e69-97c6-557d-af76-05c220ba8bc9'::uuid, 'ex_calf_raise', 'Standing Calf Raise', 'legs', 'none', 'Stand tall with feet hip-width apart. Rest one hand on a wall or chair for balance.
Press up onto the balls of your feet as high as you comfortably can.
Pause for one second at the top.
Lower your heels slowly back to the floor.', 'assets/exercises/calf_raise.webp', '{}'::text[]),
  ('7417c933-82ba-55dc-baa7-8a1e9deed1fd'::uuid, 'ex_straight_leg_raise', 'Lying Straight Leg Raise', 'legs', 'mat', 'Lie on your back with one knee bent and the other leg straight.
Tighten the thigh muscle of the straight leg.
Lift that leg until it is level with your bent knee, keeping it straight.
Lower slowly. Finish your reps, then switch legs.', 'assets/exercises/straight_leg_raise.webp', '{}'::text[]),
  ('4073f8ad-3be8-5e95-bcad-60c68fff6f78'::uuid, 'ex_wall_sit', 'Wall Sit', 'legs', 'none', 'Stand with your back against a wall and feet about 60 cm (2 ft) in front of you.
Slide down until your knees are bent to about 90 degrees, or stay higher if that feels better.
Keep your back flat on the wall and breathe steadily.
Hold for the set time, then slide back up.', 'assets/exercises/wall_sit.webp', array['knee']::text[]),
  ('d9309732-adb1-5e05-af0b-3d928cab2d67'::uuid, 'ex_goblet_squat', 'Dumbbell Goblet Squat', 'legs', 'dumbbells', 'Hold one dumbbell upright against your chest with both hands.
Stand with feet slightly wider than shoulder-width.
Sit your hips down and back, keeping your chest tall and elbows inside your knees.
Drive through your feet to stand up.', 'assets/exercises/goblet_squat.webp', array['knee','lower_back']::text[]),
  ('14c8d146-0543-51b5-9126-482fe3046cc1'::uuid, 'ex_glute_bridge', 'Glute Bridge', 'glutes', 'mat', 'Lie on your back with knees bent and feet flat, hip-width apart.
Press through your heels and lift your hips until your body makes a straight line from shoulders to knees.
Squeeze your glutes for one second at the top.
Lower your hips slowly.', 'assets/exercises/glute_bridge.webp', '{}'::text[]),
  ('73928dec-b2e0-5d11-b679-74daf03a812d'::uuid, 'ex_clamshell', 'Clamshell', 'glutes', 'mat', 'Lie on your side with knees bent and feet together.
Rest your head on your arm and keep your hips stacked.
Lift your top knee while your feet stay touching.
Lower slowly. Finish your reps, then switch sides.', 'assets/exercises/clamshell.webp', '{}'::text[]),
  ('26212441-05be-5ec0-b6f3-296ae6494d77'::uuid, 'ex_dumbbell_rdl', 'Dumbbell Romanian Deadlift', 'glutes', 'dumbbells', 'Stand tall holding a light dumbbell in each hand in front of your thighs.
With a soft bend in your knees, push your hips back and slide the weights down your legs.
Stop when you feel a stretch in the back of your thighs, keeping your back flat.
Squeeze your glutes to stand back up.', 'assets/exercises/dumbbell_rdl.webp', array['lower_back']::text[]),
  ('a4c4d992-3f44-5b87-b794-788128ef397c'::uuid, 'ex_pushup', 'Push-Up', 'chest', 'none', 'Start in a high plank with hands slightly wider than your shoulders.
Keep your body in one straight line from head to heels.
Bend your elbows to lower your chest toward the floor, elbows about 45 degrees from your body.
Press back up until your arms are straight.', 'assets/exercises/pushup.webp', array['wrist','shoulder']::text[]),
  ('b8230f98-b302-579c-b937-1d3381c915bd'::uuid, 'ex_incline_pushup', 'Incline Push-Up', 'chest', 'none', 'Place your hands on a sturdy counter, bench or wall, slightly wider than your shoulders.
Walk your feet back until your body makes a straight line.
Bend your elbows to bring your chest toward the surface.
Press away until your arms are straight.', 'assets/exercises/incline_pushup.webp', array['wrist']::text[]),
  ('91461f51-d0a3-50fd-a076-45d532d20572'::uuid, 'ex_floor_press', 'Dumbbell Floor Press', 'chest', 'dumbbells', 'Lie on your back with knees bent, holding a dumbbell in each hand above your chest.
Lower your elbows until your upper arms lightly touch the floor.
Press the weights up until your arms are straight.
Keep your wrists straight and your core gently braced.', 'assets/exercises/dumbbell_floor_press.webp', array['shoulder']::text[]),
  ('fa1f394d-2149-5df3-a750-2435df37295a'::uuid, 'ex_chair_dips', 'Chair Dips', 'arms', 'chair', 'Sit on the edge of a sturdy chair placed against a wall and put your hands beside your hips.
Slide your hips off the seat with your knees bent.
Bend your elbows straight back to lower a few inches.
Press back up until your arms are straight.', 'assets/exercises/chair_dips.webp', array['shoulder','wrist']::text[]),
  ('abc36cee-c14e-51eb-b5d4-85c0916ad94a'::uuid, 'ex_dumbbell_curl', 'Dumbbell Biceps Curl', 'arms', 'dumbbells', 'Stand tall holding a dumbbell in each hand, palms facing forward.
Keep your elbows close to your sides.
Curl the weights up toward your shoulders.
Lower them slowly.', 'assets/exercises/bicep_curl.webp', '{}'::text[]),
  ('7cd82d53-56f7-50f6-90d4-e0571991f1a3'::uuid, 'ex_shoulder_press', 'Dumbbell Shoulder Press', 'shoulders', 'dumbbells', 'Stand or sit tall holding dumbbells at shoulder height, palms facing forward.
Brace your core.
Press the weights overhead until your arms are almost straight.
Lower them with control.', 'assets/exercises/shoulder_press.webp', array['shoulder']::text[]),
  ('d9f63aec-c130-5db5-8aea-f8a926fac4ef'::uuid, 'ex_shoulder_stretch', 'Cross-Body Shoulder Stretch', 'shoulders', 'none', 'Stand tall and bring one arm across your chest.
Use your other hand to hold it gently just above the elbow.
Draw it closer until you feel a mild stretch, never pain.
Hold, breathe slowly, then switch arms.', 'assets/exercises/shoulder_crossbody_stretch.webp', '{}'::text[]),
  ('3747bad6-bdf9-5256-8eb8-5fa7f63b13c7'::uuid, 'ex_dumbbell_row', 'One-Arm Dumbbell Row', 'back', 'dumbbells', 'Rest one hand on a sturdy chair or bench with a flat back, holding a dumbbell in the other hand.
Let the weight hang straight down.
Pull the dumbbell toward your hip, squeezing your shoulder blade back.
Lower slowly. Finish your reps, then switch sides.', 'assets/exercises/one_arm_dumbbell_row.webp', array['lower_back']::text[]),
  ('987cc437-a68d-5776-9d55-944b31f8113e'::uuid, 'ex_band_pull_apart', 'Band Pull-Apart', 'back', 'resistance_band', 'Hold a light resistance band in front of you at shoulder height, hands shoulder-width apart.
Keep your arms straight and gently squeeze your shoulder blades together.
Pull the band apart until it reaches your chest.
Return slowly.', 'assets/exercises/band_pull_apart.webp', '{}'::text[]),
  ('5584a185-bd15-5b6c-b2bf-39b5637da65e'::uuid, 'ex_superman', 'Superman Hold', 'back', 'mat', 'Lie face down with your arms extended in front and legs straight.
Gently lift your arms, chest and legs a few centimetres off the floor.
Keep your neck neutral with your eyes on the floor.
Hold briefly, then lower with control.', 'assets/exercises/superman_hold.webp', array['lower_back']::text[]),
  ('74b3c710-dcb9-5261-af2f-97a57a4f12e3'::uuid, 'ex_cat_cow', 'Cat-Cow Stretch', 'back', 'mat', 'Start on hands and knees with wrists under shoulders and knees under hips.
Inhale: let your belly drop and lift your chest and tailbone (cow).
Exhale: round your spine and tuck your chin (cat).
Move slowly with your breath.', 'assets/exercises/cat_cow.webp', array['wrist']::text[]),
  ('ba7854cd-57b6-5bc8-8728-a182cd9d04b7'::uuid, 'ex_plank', 'Forearm Plank', 'core', 'mat', 'Place your forearms on the mat with elbows under your shoulders.
Extend your legs behind you with toes tucked.
Make a straight line from head to heels, squeezing your core and glutes.
Hold while breathing steadily. Drop to your knees to make it easier.', 'assets/exercises/plank.webp', array['shoulder','lower_back']::text[]),
  ('7496fdec-b5d2-5076-9039-c0bf91c6a64d'::uuid, 'ex_dead_bug', 'Dead Bug', 'core', 'mat', 'Lie on your back with arms reaching to the ceiling and hips and knees bent to 90 degrees.
Press your lower back gently toward the floor.
Slowly lower the opposite arm and leg toward the floor.
Return to the start and switch sides.', 'assets/exercises/dead_bug.webp', '{}'::text[]),
  ('6b80602a-7ef3-51bc-a683-18bcefb47feb'::uuid, 'ex_bird_dog', 'Bird Dog', 'core', 'mat', 'Start on hands and knees.
Extend one arm forward and the opposite leg back, keeping your hips level.
Hold for a moment with your neck neutral.
Return and switch sides.', 'assets/exercises/bird_dog.webp', array['wrist']::text[]),
  ('f7fc3ba6-5e0f-58f3-9450-1adccd97f4f1'::uuid, 'ex_bicycle_crunch', 'Bicycle Crunch', 'core', 'mat', 'Lie on your back with hands lightly behind your head and legs lifted, knees bent.
Bring one elbow toward the opposite knee while extending the other leg.
Switch sides in a smooth pedalling motion.
Keep your neck relaxed and do not pull on your head.', 'assets/exercises/bicycle_crunch.webp', array['lower_back']::text[]),
  ('ca7c8e6f-4d3d-599c-b1c6-4df6cce32163'::uuid, 'ex_jumping_jacks', 'Jumping Jacks', 'cardio', 'none', 'Stand with feet together and arms by your sides.
Jump your feet apart while raising your arms overhead.
Jump back to the start.
Land softly on the balls of your feet.', 'assets/exercises/jumping_jacks.webp', array['high_impact','knee','cardio_risk']::text[]),
  ('b0f35c06-3910-5ecf-ab2f-04ee825d2452'::uuid, 'ex_march_in_place', 'March in Place', 'cardio', 'none', 'Stand tall with your arms bent.
Lift your knees one at a time to a comfortable height.
Swing your arms naturally.
Keep a steady rhythm and breathe normally.', 'assets/exercises/march_in_place.webp', '{}'::text[]),
  ('5f0f9e77-9d5b-54af-ad4d-cc6624f43a75'::uuid, 'ex_brisk_walk', 'Brisk Walk', 'cardio', 'none', 'Stand tall, look ahead and relax your shoulders.
Walk at a pace where you can talk but not sing.
Swing your arms and let your heel land first.
Slow down gradually to cool off.', 'assets/exercises/running.webp', '{}'::text[]),
  ('77a34ca4-dd6e-5e40-ad37-2929b5d756a5'::uuid, 'ex_light_jog', 'Easy Jog', 'cardio', 'none', 'Warm up with a brisk walk for 3 to 5 minutes.
Ease into a slow jog at a pace where you can still hold a conversation.
Take short, quiet steps landing under your body.
Finish with a few minutes of walking.', 'assets/exercises/running.webp', array['high_impact','knee','cardio_risk']::text[]),
  ('e1892f47-c395-52f9-83a5-a002724491d1'::uuid, 'ex_high_knees', 'High Knees', 'cardio', 'none', 'Stand tall with feet hip-width apart.
Drive one knee up toward hip height while pumping the opposite arm.
Alternate quickly, landing softly.
Keep your chest tall and core tight.', 'assets/exercises/high_knees.webp', array['high_impact','knee','cardio_risk']::text[]),
  ('b9089421-e09c-53a0-a88d-4a8cca18d241'::uuid, 'ex_burpee', 'Burpee', 'full_body', 'none', 'Stand with feet shoulder-width apart.
Squat down and place your hands on the floor.
Step or jump your feet back into a plank.
Step your feet back in, then stand and reach up. Jump only if it feels comfortable.', 'assets/exercises/burpee.webp', array['high_impact','knee','wrist','lower_back','cardio_risk']::text[]),
  ('88aebd4a-7edd-5784-84bd-2d5c12cb4142'::uuid, 'ex_step_jacks', 'Step Jacks', 'full_body', 'none', 'Stand with feet together.
Step one foot out to the side while raising both arms overhead.
Step back in and lower your arms.
Alternate sides at a smooth pace.', 'assets/exercises/step_jacks.webp', '{}'::text[]),
  ('f0639b65-29ce-5e28-991c-b418740ea22a'::uuid, 'ex_sun_salutation', 'Sun Salutation (Surya Namaskar)', 'full_body', 'mat', 'Stand at the front of your mat with palms together.
Inhale and reach your arms overhead. Exhale and fold forward with soft knees.
Step back to a plank or lower to your knees, then slide forward into a gentle cobra with elbows bent.
Press back to downward dog, step forward and rise tall.', 'assets/exercises/sun_salutation.webp', array['wrist','shoulder']::text[]),
  ('fbf6fc65-93f7-57b2-a227-565b9bf693af'::uuid, 'ex_child_pose', 'Balasana (Child''s Pose)', 'flexibility', 'mat', 'Kneel on the mat with big toes touching and knees wide apart.
Sit your hips back toward your heels and fold forward.
Rest your forehead gently on the mat and extend arms forward or alongside your body.
Breathe deeply into your lower back and ribs.', 'assets/exercises/child_pose.webp', array['knee']::text[]),
  ('55e5faa2-daed-5f0f-b516-05f804587cf2'::uuid, 'ex_quad_stretch', 'Standing Quad Stretch', 'flexibility', 'none', 'Stand tall and hold a wall for balance.
Bend one knee and hold your ankle behind you.
Keep your knees close together and tuck your pelvis slightly.
Hold, breathe, then switch legs.', 'assets/exercises/quad_stretch.webp', array['knee']::text[]),
  ('d96a8e3a-2aee-513b-a054-02adf942b035'::uuid, 'ex_hamstring_stretch', 'Lying Hamstring Stretch', 'flexibility', 'mat', 'Lie on your back with both knees bent.
Loop a towel around one foot and raise that leg toward the ceiling.
Straighten the leg as far as is comfortable and feel a mild stretch behind the thigh.
Hold, breathe, then switch legs.', 'assets/exercises/hamstring_stretch.webp', '{}'::text[]),
  ('8b66793c-fccd-5bbd-a095-def46d3b2c01'::uuid, 'ex_warrior_1', 'Virabhadrasana I (Warrior I)', 'flexibility', 'mat', 'Step one foot forward into a lunge with front knee bent at 90 degrees.
Turn back foot out 45 degrees, grounding firmly through heel.
Square hips forward and sweep both arms straight overhead.
Hold for 5 deep breaths, then switch sides.', 'assets/exercises/warrior_pose.webp', array['knee','shoulder']::text[]),
  ('fa6b1d10-21b7-558b-bcb0-bd70c26c6edb'::uuid, 'ex_downward_dog', 'Adho Mukha Svanasana (Downward-Facing Dog)', 'flexibility', 'mat', 'From hands and knees, tuck toes and lift hips toward ceiling in an inverted V.
Press evenly through all ten fingers, rotating upper arms outward.
Pedal heels gently or keep knees slightly bent to lengthen spine.
Hold for 5 smooth breaths.', 'assets/exercises/downward_dog.webp', array['wrist','shoulder']::text[]),
  ('3f715b72-df94-5fe8-acf3-509c9e2612b3'::uuid, 'ex_cobra_pose', 'Bhujangasana (Cobra Pose)', 'flexibility', 'mat', 'Lie face down with legs extended and tops of feet flat.
Place palms flat under your shoulders with elbows tucked close to your ribs.
Inhale and gently lift your chest off the floor using your back muscles.
Keep a soft bend in elbows and open your heart forward.
Hold for 15-30 seconds, then release down on an exhale.', 'assets/exercises/cobra_pose.webp', array['lower_back','wrist']::text[]),
  ('1cd8c168-1dbc-5427-b5d6-0843e079324b'::uuid, 'ex_tree_pose', 'Vrikshasana (Tree Pose)', 'flexibility', 'none', 'Stand tall in mountain pose with weight evenly distributed.
Shift weight to your standing leg and place the sole of the other foot against inner calf or thigh (never on the knee).
Bring hands together at prayer position in front of your chest or reach overhead.
Fix your gaze on an unmoving spot in front of you.
Hold for 30 seconds, breathe smoothly, then switch sides.', 'assets/exercises/tree_pose.webp', array['knee']::text[]),
  ('565077c4-8937-5c03-afce-bb5524e42361'::uuid, 'ex_seated_forward_fold', 'Paschimottanasana (Seated Forward Bend)', 'flexibility', 'mat', 'Sit with legs straight in front of you and toes flexed back.
Inhale arms overhead, then exhale and hinge forward from hips.
Hold shins, ankles, or feet with chest leading toward thighs.
Hold for 30 to 60 seconds with steady, deep breaths.', 'assets/exercises/seated_forward_fold.webp', array['lower_back']::text[]),
  ('5e8e9629-fb54-583d-ace7-cc72c8aff411'::uuid, 'ex_bridge_pose', 'Setu Bandhasana (Bridge Pose)', 'flexibility', 'mat', 'Lie on your back with knees bent and feet flat on mat hip-width apart.
Press feet into the floor and lift hips toward the ceiling.
Roll shoulders underneath you and lengthen tailbone toward backs of knees.
Hold for 30 seconds, breathing smoothly, then lower vertebra by vertebra.', 'assets/exercises/glute_bridge.webp', array['lower_back']::text[]),
  ('173f042e-b905-5279-836a-3d72e6797564'::uuid, 'ex_savasana', 'Shavasana (Corpse Pose)', 'flexibility', 'mat', 'Lie flat on your back with legs naturally apart and arms beside body, palms up.
Close your eyes and release all muscular tension from head to toes.
Allow breath to become soft, natural, and effortless.
Rest quietly for 3 to 5 minutes.', 'assets/exercises/savasana.webp', '{}'::text[]),
  ('cbf7b24c-a689-5328-9ffd-9953d9036d4c'::uuid, 'ex_mountain_pose', 'Tadasana (Mountain Pose)', 'flexibility', 'none', 'Stand tall with big toes touching and heels slightly apart, distributing weight evenly.
Ground through the four corners of your feet and engage quadriceps lightly.
Draw your tailbone slightly down, lengthen your spine, and relax shoulders back and down.
Let arms hang naturally by your sides with palms facing forward.
Breathe steadily and hold for 30 to 60 seconds.', 'assets/exercises/standing_hero.webp', '{}'::text[]),
  ('92b91dbe-7c21-5125-b8a0-69188e3ab6be'::uuid, 'ex_russian_twist', 'Russian Twist', 'core', 'mat', 'Sit on the floor with knees bent and feet flat or slightly elevated for a greater challenge.
Lean your torso back slightly to engage your core, keeping your spine straight.
Clasp your hands in front of your chest and rotate your torso smoothly from side to side.
Tap the floor beside your hip on each side before rotating back.
Continue for 10-15 controlled repetitions per side.', 'assets/exercises/russian_twist.webp', array['lower_back']::text[]),
  ('61ff8fc4-011b-5e39-95f6-b5b7aee3d7a6'::uuid, 'ex_mountain_climbers', 'Mountain Climbers', 'cardio', 'none', 'Start in a high plank position with shoulders directly above wrists and core tight.
Drive your right knee up toward your chest without letting your hips pike up.
Quickly switch legs, extending your right leg back while driving your left knee forward.
Maintain a steady, rhythmic pace while keeping your core braced and back flat.
Repeat continuously for 30 to 45 seconds.', 'assets/exercises/mountain_climbers.webp', array['high_impact','wrist','shoulder']::text[]),
  ('67597495-f1ce-539a-968a-2e8bd41011a4'::uuid, 'ex_side_plank', 'Side Plank', 'core', 'mat', 'Lie on your side with your elbow directly below your shoulder and legs stacked straight.
Engage your abdominal muscles and lift your hips off the floor until your body forms a straight line.
Rest your top hand on your hip or extend it toward the ceiling.
Hold without letting your hips sag toward the mat for 20-40 seconds.
Switch sides and repeat.', 'assets/exercises/side_plank.webp', array['shoulder','wrist']::text[]),
  ('cb68565c-0569-536c-a51d-7448f39c87e9'::uuid, 'ex_lateral_raise', 'Dumbbell Lateral Raise', 'shoulders', 'dumbbells', 'Stand tall with feet hip-width apart holding light dumbbells at your sides.
With a slight bend in your elbows, raise the dumbbells out to the sides until parallel to the floor.
Lead with the elbows, keeping your palms facing downward at the top.
Lower the dumbbells back down with control over 2 seconds.
Perform 10 to 12 controlled reps without swinging.', 'assets/exercises/lateral_raise.webp', array['shoulder']::text[]),
  ('2a3a6432-c280-5405-b06a-757064689760'::uuid, 'ex_reverse_lunge', 'Reverse Lunge', 'legs', 'none', 'Stand tall with feet hip-width apart and hands on your hips or held at chest.
Take a controlled step backward with one leg and lower your hips.
Bend both knees to roughly 90 degrees, keeping front knee aligned over ankle.
Drive through the heel of your front foot to return to the standing position.
Alternate legs for 10-12 repetitions per leg.', 'assets/exercises/reverse_lunge.webp', array['knee']::text[]),
  ('e902dc68-844d-5c0e-90f9-ee35365cffa1'::uuid, 'ex_overhead_triceps_ext', 'Overhead Dumbbell Triceps Extension', 'arms', 'dumbbells', 'Stand or sit upright holding a single dumbbell vertically overhead with both hands cup-gripping the top plate.
Keep your upper arms stationary close to your ears and elbows pointing forward.
Slowly bend your elbows to lower the weight behind your head until your forearms pass parallel.
Contract your triceps to press the dumbbell back overhead to the start position.
Perform 10 to 12 controlled reps.', 'assets/exercises/overhead_triceps_ext.webp', array['shoulder','wrist']::text[]),
  ('417cdb2e-bdf3-58f3-bbef-9e2399cbb1f5'::uuid, 'ex_warrior_2', 'Virabhadrasana II (Warrior II)', 'flexibility', 'mat', 'Step feet wide apart. Turn front foot out 90 degrees and back foot in slightly.
Inhale arms parallel to floor; exhale and bend front knee to 90 degrees.
Keep torso centered and gaze over front fingertips.
Hold for 5 deep breaths, then switch sides.', 'assets/exercises/warrior_2.webp', array['knee','shoulder']::text[]),
  ('85daa3c3-5371-555d-990c-36abee392c46'::uuid, 'ex_triangle_pose', 'Trikonasana (Triangle Pose)', 'flexibility', 'mat', 'Stand with wide legs. Turn front foot out 90 degrees, back foot in slightly.
Inhale arms parallel to floor, exhale and reach sideways over front leg.
Lower front hand to shin, ankle, or block, extending top arm toward sky.
Keep chest open and hold for 5 breaths.', 'assets/exercises/triangle_pose.webp', array['lower_back','neck']::text[]),
  ('5a1f130e-2da7-5d20-84d2-618ef6f375d1'::uuid, 'ex_marjaryasana', 'Marjaryasana (Cat Pose)', 'flexibility', 'mat', 'Begin on all fours with wrists directly under shoulders and knees under hips.
Exhale and round your spine upward toward the ceiling, tucking your tailbone.
Gently release your head toward the floor without forcing your chin to chest.
Draw your navel in toward your spine to deeply stretch back muscles.', 'assets/exercises/cat_cow.webp', array['wrist']::text[]),
  ('df05e931-de9c-59e0-894a-01b929062e47'::uuid, 'ex_bitilasana', 'Bitilasana (Cow Pose)', 'flexibility', 'mat', 'From tabletop on all fours, inhale and drop your belly toward the mat.
Lift your chest, collarbones, and tailbone toward the ceiling.
Gaze gently forward or slightly upward without compressing back of neck.
Open through the chest while keeping core lightly engaged.', 'assets/exercises/cat_cow.webp', array['neck','lower_back']::text[]),
  ('4fea2550-c7a2-5828-a30c-b3d3f4fef8aa'::uuid, 'ex_sukhasana', 'Sukhasana (Easy Pose)', 'flexibility', 'mat', 'Sit cross-legged comfortably on your mat, elevating hips on a folded blanket if needed.
Lengthen your spine upward from tailbone to crown of head.
Rest your hands palms-up or palms-down on your knees.
Relax your face and shoulders, breathing deeply and evenly.', 'assets/exercises/meditation.webp', array['knee']::text[]),
  ('167808e8-68d3-553f-828a-6f685645b39b'::uuid, 'ex_vajrasana', 'Vajrasana (Thunderbolt Pose)', 'flexibility', 'mat', 'Kneel on the floor with knees together and big toes touching.
Lower your buttocks onto the heels, resting palms flat on thighs.
Keep the spine erect and chest open.
Breathe slowly; this pose aids digestion after meals.', 'assets/exercises/vajrasana.webp', array['knee','ankle']::text[]),
  ('c54abec3-aa29-572d-9b50-c6ca69e83f88'::uuid, 'ex_makarasana', 'Makarasana (Crocodile Pose)', 'flexibility', 'mat', 'Lie prone on your stomach with legs comfortably apart, heels turned in or out.
Cross your arms in front of you, holding opposite elbows or stacking palms.
Rest your forehead or cheek on your folded forearms.
Close your eyes and breathe deeply into the belly, relaxing the entire spine.', 'assets/exercises/makarasana.webp', '{}'::text[]),
  ('84f1f1cf-1aa8-5f64-b740-5b4332800116'::uuid, 'ex_pavanamuktasana', 'Pavanamuktasana (Wind-Relieving Pose)', 'flexibility', 'mat', 'Lie on your back and draw both knees gently in toward your chest.
Clasp your hands or forearms around your shins.
Keep your lower back and tailbone grounded onto the mat.
Gently rock side to side to massage your lumbar spine.', 'assets/exercises/pavanamuktasana.webp', array['lower_back','knee']::text[]),
  ('56e505d8-984a-583a-adf6-618ddd3f8f54'::uuid, 'ex_baddha_konasana', 'Baddha Konasana (Butterfly Pose)', 'flexibility', 'mat', 'Sit tall with soles of your feet pressed together, drawing heels comfortably near groin.
Hold feet with hands and lengthen spine upwards.
Gently press knees down toward the floor without forcing or bouncing.
Breathe into inner thighs and hips for 30 to 60 seconds.', 'assets/exercises/baddha_konasana.webp', array['knee','hip']::text[]),
  ('d6210b88-9a09-5814-8eeb-ba4af1fe8bce'::uuid, 'ex_ardha_matsyendrasana', 'Ardha Matsyendrasana (Half Spinal Twist)', 'flexibility', 'mat', 'Sit with legs extended. Bend right knee and place right foot outside left thigh.
Inhale and reach left arm overhead, lengthening spine.
Exhale and twist torso right, hugging right knee with left arm or hooking elbow.
Place right fingertips on floor behind you for support. Breathe and switch sides.', 'assets/exercises/ardha_matsyendrasana.webp', array['lower_back']::text[]),
  ('a9fb80e8-a19b-5150-80f6-832984a63d9f'::uuid, 'ex_virabhadrasana_3', 'Virabhadrasana III (Warrior III)', 'flexibility', 'none', 'From a high lunge, shift weight onto your front foot.
Hinge forward at the hips, lifting back leg parallel to floor.
Extend arms forward, sideways, or alongside body, forming a T-shape.
Keep hips level and standing knee slightly soft.
Hold for 3 to 5 breaths, then switch legs.', 'assets/exercises/warrior_3.webp', array['knee','lower_back']::text[]),
  ('e06a54d4-bbb8-5e59-9556-d4e4a9066944'::uuid, 'ex_utkatasana', 'Utkatasana (Chair Pose)', 'legs', 'none', 'Stand with feet together or hip-width apart.
Inhale and raise arms overhead, keeping shoulders relaxed.
Exhale and bend knees, sitting hips back as if into a chair.
Shift weight toward heels and keep chest lifted.
Hold for 5 breaths.', 'assets/exercises/chair_pose.webp', array['knee']::text[]),
  ('8bca488b-4eca-5c37-8b39-cc4273e0148b'::uuid, 'ex_natarajasana', 'Natarajasana (Dancer Pose)', 'flexibility', 'none', 'Shift weight onto right foot. Bend left knee and grasp inside of left foot.
Reach right arm forward and upward.
Kick left foot back into hand, opening chest and tilting slightly forward.
Maintain gaze on a fixed point. Hold for 3 to 5 breaths, then switch.', 'assets/exercises/natarajasana.webp', array['knee','lower_back']::text[]),
  ('16167504-4064-576c-b66a-5df7310ebe8e'::uuid, 'ex_garudasana', 'Garudasana (Eagle Pose)', 'flexibility', 'none', 'Bend knees slightly and cross right thigh over left, hooking toes behind left calf if able.
Bring arms forward, cross left arm over right at elbows, and wrap forearms to touch palms.
Lift elbows to shoulder height and sit hips deeper.
Breathe steadily for 5 breaths, then unwind and switch sides.', 'assets/exercises/tree_pose.webp', array['knee']::text[]),
  ('55643eee-7c7f-554e-8ce8-1107e5361bd3'::uuid, 'ex_ardha_chandrasana', 'Ardha Chandrasana (Half Moon Pose)', 'flexibility', 'mat', 'From Triangle Pose, bend front knee and place fingertips 6-12 inches ahead on floor or block.
Lift back leg parallel to floor while straightening standing leg.
Stack hips and shoulders vertically, extending top arm toward ceiling.
Gaze sideways or upward. Hold for 5 breaths, then switch sides.', 'assets/exercises/triangle_pose.webp', array['knee','neck']::text[]),
  ('e2ae30d6-ddd2-5e4c-8b26-cb3c1a4912c5'::uuid, 'ex_parsvakonasana', 'Parsvakonasana (Extended Side Angle Pose)', 'flexibility', 'mat', 'From Warrior II, rest front forearm on front thigh or place hand on floor/block outside foot.
Sweep top arm alongside ear, creating a straight diagonal line from back heel to fingertips.
Rotate chest open toward ceiling.
Hold for 5 breaths, then switch sides.', 'assets/exercises/warrior_2.webp', array['knee']::text[]),
  ('b7b79a37-06e2-56bc-b4d3-25e23ea24b61'::uuid, 'ex_prasarita_padottanasana', 'Prasarita Padottanasana (Wide-Legged Forward Bend)', 'flexibility', 'mat', 'Stand with feet 3-4 feet apart, toes slightly turned in.
Place hands on hips, inhale and lengthen spine.
Exhale and hinge forward from hips, lowering palms flat to floor under shoulders.
Release crown of head toward floor, keeping legs active.
Hold for 5 to 8 breaths.', 'assets/exercises/seated_forward_fold.webp', array['lower_back']::text[]),
  ('65261b72-5442-5625-9e0f-c3eb74df79b3'::uuid, 'ex_dhanurasana', 'Dhanurasana (Bow Pose)', 'flexibility', 'mat', 'Lie on stomach, bend knees and reach back to grasp ankles.
Inhale and kick ankles back and up, lifting thighs and chest off mat.
Draw shoulder blades together and keep neck long.
Hold for 20-30 seconds, breathing smoothly, then release.', 'assets/exercises/cobra_pose.webp', array['lower_back','shoulder']::text[]),
  ('65f771f9-f176-5b33-aba7-abb3f33d2c99'::uuid, 'ex_ustrasana', 'Ustrasana (Camel Pose)', 'flexibility', 'mat', 'Kneel with knees hip-width apart and hips stacked directly over knees.
Place hands on lower back with fingers pointing down.
Inhale, press hips gently forward and lift chest toward ceiling.
Optionally reach hands back to touch heels while keeping hips pushed forward.
Hold for 5 breaths, then carefully rise on an inhale.', 'assets/exercises/vajrasana.webp', array['lower_back','neck']::text[]),
  ('52fdb95e-07df-50d5-a087-60fc669d5bc6'::uuid, 'ex_janu_sirsasana', 'Janu Sirsasana (Head-to-Knee Pose)', 'flexibility', 'mat', 'Sit with right leg extended and left foot pressed against inner right thigh.
Inhale arms overhead, squaring chest toward right leg.
Exhale and fold forward over right thigh, holding foot or shin.
Keep spine long and breathe deeply for 5 breaths, then switch legs.', 'assets/exercises/seated_forward_fold.webp', array['knee','lower_back']::text[]),
  ('470a3e6a-c569-5284-aae6-ad14361822f2'::uuid, 'ex_gomukhasana', 'Gomukhasana (Cow Face Pose)', 'flexibility', 'mat', 'Stack right knee directly over left knee with feet beside opposite hips.
Reach right arm overhead, bend elbow and place hand down middle of back.
Reach left arm behind back and up, clasping fingers or holding a strap.
Keep spine tall and breathe for 5 breaths, then switch sides.', 'assets/exercises/seated_forward_fold.webp', array['shoulder','knee']::text[]),
  ('c23abc20-10ba-5098-9039-01ca9c19c05e'::uuid, 'ex_bakasana', 'Bakasana (Crow Pose)', 'core', 'mat', 'Squat on mat with feet together, hands shoulder-width flat on floor.
Place knees high against backs of upper arms or armpits.
Lean forward, shift weight into hands, and lift one foot then both off mat.
Engage core and round upper back slightly. Balance for 15-30 seconds.', 'assets/exercises/crow_pose.webp', array['wrist','shoulder']::text[]),
  ('1cf74a9f-d45f-55ba-83cb-c3b63280c42b'::uuid, 'ex_sirsasana', 'Sirsasana (Headstand)', 'full_body', 'mat', 'Interlace fingers and place forearms on mat elbow-width apart.
Crown of head rests on mat cupped by interlaced hands.
Lift hips, walk feet close, engage core, and float legs up vertically.
Press actively through forearms to keep neck free of compression.
Hold for 5 to 10 controlled breaths with wall support if needed.', 'assets/exercises/standing_hero.webp', array['neck','hypertension','shoulder']::text[]),
  ('6660b970-3714-555a-81f9-c3cde857f7b6'::uuid, 'ex_pincha_mayurasana', 'Pincha Mayurasana (Forearm Stand)', 'shoulders', 'mat', 'Start on hands and knees, placing forearms parallel shoulder-width apart.
Lift hips into Dolphin Pose and walk feet toward elbows.
Gaze slightly forward between wrists, engage core, and kick or press legs up.
Draw ribs in and balance vertically over forearms for 5 breaths.', 'assets/exercises/plank.webp', array['shoulder','wrist']::text[]),
  ('409a16f9-ef14-5e28-9804-7065f0c7f7d0'::uuid, 'ex_adho_mukha_vrksasana', 'Adho Mukha Vrksasana (Handstand)', 'full_body', 'mat', 'Place palms flat shoulder-width apart near a wall, spreading fingers wide.
Step one foot forward and kick back leg up into handstand.
Stack wrists, shoulders, hips, and ankles in a straight line.
Engage core and press floor actively away. Hold for 15-30 seconds.', 'assets/exercises/standing_hero.webp', array['wrist','shoulder','hypertension']::text[]),
  ('21d8a5cd-da9f-5a58-a617-04ba08878d20'::uuid, 'ex_mayurasana', 'Mayurasana (Peacock Pose)', 'core', 'mat', 'Kneel with hands flat between knees, fingers pointing back toward feet.
Press elbows together into abdomen near navel.
Lean forward, extend legs straight back, and lift feet off floor parallel to mat.
Balance entirely on palms and wrists for 10-20 seconds.', 'assets/exercises/plank.webp', array['wrist','elbow','hypertension']::text[]),
  ('c93dda99-8668-5ac3-806f-9cdbbdb7471e'::uuid, 'ex_eka_pada_rajakapotasana', 'Eka Pada Rajakapotasana (King Pigeon Pose)', 'flexibility', 'mat', 'From One-Legged Pigeon, bend back knee and point back foot toward ceiling.
Reach overhead with both hands to grasp back toes, flipping elbows forward.
Lift chest and curve spine in a deep backbend toward back foot.
Hold for 5 breaths, then carefully release and switch legs.', 'assets/exercises/cobra_pose.webp', array['knee','lower_back','shoulder']::text[]),
  ('2278abf1-9746-5b94-a967-523ac65fdbd4'::uuid, 'ex_hanumanasana', 'Hanumanasana (Monkey Pose / Splits)', 'flexibility', 'mat', 'From a low lunge, slide front foot forward while sliding back leg straight back.
Keep hips squared forward, using blocks under hands for support.
Slowly lower pelvis toward mat until both legs are straight.
Bring hands to heart or raise arms overhead. Breathe and switch sides.', 'assets/exercises/seated_forward_fold.webp', array['hamstring','knee']::text[]),
  ('971178cd-82e6-5e6a-b6de-f0676e54ebc7'::uuid, 'ex_urdhva_dhanurasana', 'Urdhva Dhanurasana (Wheel Pose)', 'flexibility', 'mat', 'Lie on back with knees bent, feet flat and hands beside ears with fingers pointing toward shoulders.
Press into feet and hands simultaneously to lift body up into a full arch.
Roll shoulders open, press chest toward wall behind you, and relax neck.
Hold for 5 deep breaths, then tuck chin and lower down slowly.', 'assets/exercises/glute_bridge.webp', array['wrist','lower_back','shoulder']::text[]),
  ('ac682cf1-2340-511b-afae-a8945ffb9de6'::uuid, 'ex_eka_pada_koundinyasana', 'Eka Pada Koundinyasana (Flying Splits Pose)', 'core', 'mat', 'From a lunge, hook front thigh over back of front upper arm.
Plant both palms firmly on floor shoulder-width apart.
Shift chest forward into Chaturanga arms, lift back leg and extend front leg straight.
Hover both legs split in air for 10-20 seconds, then switch sides.', 'assets/exercises/crow_pose.webp', array['wrist','shoulder']::text[]),
  ('5f36f69d-c86f-5574-800e-8f826a05735a'::uuid, 'ex_astavakrasana', 'Astavakrasana (Eight-Angle Pose)', 'core', 'mat', 'Sit with legs out. Hook right leg high over right upper arm.
Plant hands on floor, cross left ankle over right ankle.
Press into hands to lift hips off floor, bend elbows to 90 degrees.
Extend both legs straight out to the right side, chest parallel to floor.
Hold for 5 breaths, then repeat on opposite side.', 'assets/exercises/crow_pose.webp', array['wrist','shoulder']::text[]),
  ('90673c21-f00d-59ed-8ab0-71673e6b4045'::uuid, 'ex_tittibhasana', 'Tittibhasana (Firefly Pose)', 'core', 'mat', 'Squat with feet slightly wider than mat. Work shoulders underneath thighs.
Plant palms flat on floor behind heels.
Shift weight back onto hands, lift feet off mat, and straighten legs out to sides.
Press firmly through hands, engage inner thighs, and lift chest for 5 breaths.', 'assets/exercises/crow_pose.webp', array['wrist','hamstring']::text[]),
  ('0c96d1f3-1fec-54ba-9bf3-f1c831c88331'::uuid, 'ex_vrschikasana', 'Vrschikasana (Scorpion Pose)', 'shoulders', 'mat', 'Begin in a stable Forearm Stand (Pincha Mayurasana).
Bend knees and begin arching spine, dropping feet toward crown of head.
Lift chest and head forward, gazing toward hands.
Hold for 3 to 5 controlled breaths, then return to forearm stand and lower.', 'assets/exercises/plank.webp', array['shoulder','lower_back','neck']::text[]),
  ('27111dcc-801e-5299-90ea-c74f4304c769'::uuid, 'ex_parsva_bakasana', 'Parsva Bakasana (Side Crow Pose)', 'core', 'mat', 'Squat and twist torso deeply to the right, placing both hands flat on floor outside right thigh.
Rest outer right thigh across back of left upper arm.
Shift chest forward, bend elbows to 90 degrees, and float feet off floor.
Hold for 15-20 seconds, then switch sides.', 'assets/exercises/crow_pose.webp', array['wrist','lower_back']::text[]),
  ('13185c4a-8a17-58b6-8e2e-723424c0be6f'::uuid, 'ex_kapotasana', 'Kapotasana (Pigeon Pose / Full Backbend)', 'flexibility', 'mat', 'Kneel upright with knees hip-width apart.
Inhale and reach arms overhead; exhale and arch backward into a deep backbend.
Lower forearms to floor and walk hands to grasp heels or ankles.
Drop head gently back, press thighs forward, and hold for 5 breaths.', 'assets/exercises/cobra_pose.webp', array['lower_back','knee','neck']::text[]),
  ('1a81f445-9184-55b8-ac18-1cd7301b563e'::uuid, 'ex_kukkutasana', 'Kukkutasana (Rooster Pose)', 'core', 'mat', 'Sit in full Lotus Pose (Padmasana).
Slide arms down through the space between thighs and calves until palms reach floor.
Spread fingers wide and press firmly into mat.
Engage core and lift entire body and lotus legs off floor, balancing on palms.
Hold for 10-20 seconds, breathing steadily.', 'assets/exercises/meditation.webp', array['wrist','knee']::text[]),
  ('e7f73cbc-baa4-5fe6-9d11-fd8eb3aa2bfb'::uuid, 'ex_arm_circles', 'Arm Circles', 'arms', 'none', 'Stand tall with feet hip-width apart and extend your arms straight out to the sides at shoulder height.
Make small, controlled circular motions forward with both arms.
Gradually increase circle diameter to mobilize shoulder capsules and rotator cuffs.
Reverse direction halfway through to work opposing muscle groups.', 'assets/exercises/arm_circles.webp', array['shoulder']::text[]),
  ('01818647-7426-58f3-a91b-481abf532253'::uuid, 'ex_shoulder_rolls', 'Shoulder Rolls', 'arms', 'none', 'Stand tall with arms relaxed naturally at your sides.
Lift shoulders up toward your ears, roll them backward, squeeze shoulder blades together, then lower down.
Perform smooth, fluid circular motions to release upper neck and shoulder tension.
Switch to rolling forward halfway through.', 'assets/exercises/shoulder_rolls.webp', '{}'::text[]),
  ('ebf5cfe2-3916-51a8-ab6b-942705833394'::uuid, 'ex_hip_circles', 'Hip Circles', 'legs', 'none', 'Stand with feet slightly wider than shoulder-width, placing hands firmly on your hips.
Rotate your hips in wide, smooth clockwise circles.
Engage core gently while opening up pelvic girdle, hip flexors, and lower back.
Reverse direction and complete equal rotations counter-clockwise.', 'assets/exercises/hip_circles.webp', array['hip']::text[]),
  ('b2d18137-70fe-5249-9efc-559b65641283'::uuid, 'ex_ankle_rotations', 'Ankle Rotations', 'legs', 'none', 'Stand tall or sit comfortably with one foot lifted slightly off the floor.
Rotate foot and ankle in slow, complete circles in a clockwise direction.
Complete desired reps, then rotate counter-clockwise.
Switch feet and repeat to prepare calves and ankles for impact.', 'assets/exercises/ankle_rotations.webp', array['ankle']::text[]),
  ('8b5a9431-4b6e-55ad-afc8-ced4bac7d3cd'::uuid, 'ex_hip_rotations', 'Hip Rotations', 'legs', 'none', 'Stand on one leg while lifting the opposite knee up to hip level.
Open the knee out to the side in a smooth arc, then lower back to starting position.
Alternate legs or complete sets on one side before switching.
Hold onto a sturdy wall or surface if you need balance support.', 'assets/exercises/hip_rotations.webp', array['hip']::text[]),
  ('ecd94471-6ee1-5bea-bab9-837edfaac53f'::uuid, 'ex_leg_swings', 'Leg Swings', 'legs', 'none', 'Stand beside a wall or sturdy support, holding it lightly with one hand.
Swing the outer leg forward and backward smoothly in a pendulum motion.
Allow hamstring and hip flexor to dynamically stretch without forcing end range.
Switch sides and repeat with other leg.', 'assets/exercises/leg_swings.webp', array['hip']::text[]),
  ('815a2528-f0c6-57f0-b419-7ea5700dae75'::uuid, 'ex_inchworm', 'Inchworms', 'full_body', 'none', 'Stand tall with feet hip-width apart.
Hinge forward at hips and place hands on the floor (bend knees slightly if hamstrings are tight).
Walk hands forward one by one until you reach a straight-arm plank position.
Hold for a brief moment, then walk hands back toward feet and stand up tall.', 'assets/exercises/inchworm.webp', array['wrist','lower_back']::text[]),
  ('8857e24d-0dd0-560b-a91b-79af8e870f94'::uuid, 'ex_arm_swings', 'Arm Swings', 'arms', 'none', 'Stand tall with feet hip-width apart and knees slightly bent.
Swing both arms across the front of your chest, alternating which arm crosses on top.
Open arms wide horizontally to stretch chest and shoulders dynamically.
Maintain a steady, rhythmic breathing pattern throughout.', 'assets/exercises/arm_swings.webp', array['shoulder']::text[]),
  ('70d71eca-44e9-5cda-ba6f-51217f01fac4'::uuid, 'ex_dynamic_lunges', 'Dynamic Lunges', 'legs', 'none', 'Stand tall with feet together and hands on hips.
Step forward smoothly into a controlled lunge, lowering hips until front thigh is parallel to ground.
Push off front foot in one fluid motion to return to starting stance.
Immediately step forward with opposite leg and alternate continuously.', 'assets/exercises/dynamic_lunges.webp', array['knee']::text[]),
  ('d8e51c2f-1d74-5980-b5b9-4e937d2c2ea9'::uuid, 'ex_wall_pushups', 'Wall Push-ups', 'chest', 'none', 'Stand arm-length away from a sturdy wall with feet hip-width apart.
Place palms flat against wall at shoulder height and shoulder-width apart.
Keeping body straight from head to heels, bend elbows to lower chest toward wall.
Press through palms to push back to straight arms.', 'assets/exercises/wall_pushup.webp', array['wrist','shoulder']::text[]),
  ('925060c9-bfee-5daa-a258-5d5727ed2850'::uuid, 'ex_knee_pushups', 'Knee Push-ups', 'chest', 'none', 'Start on all fours, then walk hands forward and lower hips so body forms a straight line from knees to head.
Place hands slightly wider than shoulder-width.
Lower chest toward the floor until elbows bend to 90 degrees.
Press through palms firmly to return to the starting plank position on knees.', 'assets/exercises/knee_pushup.webp', array['wrist','shoulder']::text[]),
  ('1bba0f8a-edb2-59ce-af16-dde900eeb60f'::uuid, 'ex_chair_squats', 'Chair Squats', 'legs', 'none', 'Stand a few inches in front of a sturdy chair with feet shoulder-width apart.
Push hips back and bend knees, lowering slowly until glutes lightly touch the seat.
Do not collapse your weight onto the chair; pause for a half-second.
Drive through your heels and stand up tall, squeezing glutes at the top.', 'assets/exercises/chair_squat.webp', array['knee']::text[]),
  ('e3ef89e9-b067-5a59-ada2-d4ac4e32947b'::uuid, 'ex_knee_plank', 'Knee Plank', 'core', 'none', 'Rest on your forearms and knees, with elbows directly under shoulders.
Walk knees back slightly so your body forms a straight line from knees to head.
Engage your abdominal wall and glutes, keeping your spine neutral.
Breathe steadily and hold for the target duration.', 'assets/exercises/knee_plank.webp', array['wrist','lower_back']::text[]),
  ('80c99e9c-ea21-5c06-9f99-aff932da36a5'::uuid, 'ex_wide_pushups', 'Wide-Grip Push-ups', 'chest', 'none', 'Set up in a high plank position with hands placed about 1.5 times shoulder-width apart.
Keep your body straight from heels to head with core braced.
Lower chest toward floor by bending elbows outwards at roughly 45 to 60 degrees.
Push through palms to return to full lockout.', 'assets/exercises/wide_pushup.webp', array['shoulder','wrist']::text[]),
  ('793624b9-63c4-5e59-ac87-65eda311d84e'::uuid, 'ex_diamond_pushups', 'Diamond Push-ups', 'arms', 'none', 'Start in a high plank with hands directly under chest, thumbs and index fingers touching to form a diamond or triangle shape.
Maintain a rigid plank alignment from head to heels.
Lower chest toward your hands while keeping elbows tucked close to your ribcage.
Drive powerfully through palms and triceps to push back to top position.', 'assets/exercises/diamond_pushup.webp', array['wrist','elbow']::text[]),
  ('b1ac294d-3022-5a53-a651-a32c8c089935'::uuid, 'ex_sumo_squats', 'Sumo Squats', 'legs', 'none', 'Stand with feet considerably wider than shoulder-width, toes turned outward at 45 degrees.
Keep chest upright and hands clasped in front of your chest.
Bend knees and push hips back, tracking knees directly over your flared toes.
Descend until thighs are parallel to ground, then drive through heels to stand tall.', 'assets/exercises/sumo_squat.webp', array['groin','knee']::text[]),
  ('ac1cb1d2-395d-5ecd-8a9b-641c10245f9b'::uuid, 'ex_jump_squats', 'Jump Squats', 'legs', 'none', 'Stand with feet shoulder-width apart, arms at your sides.
Hinge and bend knees into a quarter-to-half squat, swinging arms back.
Explosively extend hips, knees, and ankles, driving arms up and jumping into the air.
Land softly on balls of feet and absorb impact by sinking immediately into the next squat.', 'assets/exercises/jump_squat.webp', array['knee','ankle','lower_back']::text[]),
  ('efccc8cc-fa1c-56a8-9e7e-032cb593eb0f'::uuid, 'ex_walking_lunges', 'Walking Lunges', 'legs', 'none', 'Stand tall with feet together and hands on hips or at your sides.
Take a large step forward with your right leg, lowering hips until front thigh is parallel to floor.
Drive through right heel and step your left leg forward directly into the next lunge.
Continue walking forward in a smooth, continuous alternating cadence.', 'assets/exercises/walking_lunge.webp', array['knee']::text[]),
  ('94990f28-3b38-57ab-a11b-d0bced4e772b'::uuid, 'ex_bulgarian_split_squat', 'Bulgarian Split Squats', 'legs', 'none', 'Stand about two feet in front of a bench or chair, facing away.
Reach one foot back and rest the top of your foot on the elevated surface.
Lower your hips straight down until your front thigh is roughly parallel to floor.
Drive through your front heel to stand back up, keeping rear leg relaxed.', 'assets/exercises/bulgarian_split_squat.webp', array['knee']::text[]),
  ('b60a691b-aad8-58a4-8ce4-f30a6f6fc2e2'::uuid, 'ex_decline_pushups', 'Decline Push-ups', 'chest', 'none', 'Kneel facing away from a sturdy bench, chair, or bed.
Place hands flat on floor slightly wider than shoulder-width, then place toes on the elevated surface.
Brace core to form a rigid line from toes to head.
Lower chest toward floor until elbows bend to 90 degrees, then press back up forcefully.', 'assets/exercises/decline_pushup.webp', array['wrist','shoulder']::text[]),
  ('1ffa7011-a6cf-55ab-a244-aa1621912cf7'::uuid, 'ex_archer_pushups', 'Archer Push-ups', 'chest', 'none', 'Set up in a pushup position with hands placed significantly wider than normal.
Lower your body toward one side, bending that arm fully while extending the other arm straight out.
Press back up to the center using the bent working arm.
Repeat on the opposite side, alternating smoothly like an archer drawing a bow.', 'assets/exercises/archer_pushup.webp', array['shoulder','wrist']::text[]),
  ('94c4d22f-cc2d-556f-8490-40377635567e'::uuid, 'ex_explosive_pushups', 'Explosive Push-ups', 'chest', 'none', 'Start in a standard pushup position with core tightly braced.
Lower chest down under control until an inch above the floor.
Explosively push through your hands with maximum speed so hands leave the ground momentarily.
Land with soft, unlocked elbows and immediately descend into the next repetition.', 'assets/exercises/explosive_pushup.webp', array['wrist','shoulder','elbow']::text[]),
  ('d8583d14-26c8-5377-92c7-a3b20ea30334'::uuid, 'ex_pike_pushups', 'Pike Push-ups', 'shoulders', 'none', 'Begin in a downward-dog or inverted V position with hands shoulder-width and hips pushed high.
Shift your weight forward so shoulders are stacked directly over wrists.
Bend elbows and lower crown of head forward and down in a diagonal arc between hands.
Press through shoulders and palms to push back up into the high pike.', 'assets/exercises/pike_pushup.webp', array['shoulder','wrist']::text[]),
  ('aee920b2-6e44-5476-94e6-1041283d21af'::uuid, 'ex_assisted_pistol_squats', 'Assisted Pistol Squats', 'legs', 'none', 'Stand tall on one leg with a wall, doorframe, or sturdy post at your side for balance.
Extend the non-working leg straight out in front of you.
Lower down on your standing leg into a deep, full single-leg squat, using hand support as needed.
Press through heel and midfoot to stand back up without relying purely on hand assistance.', 'assets/exercises/pistol_squat.webp', array['knee','ankle']::text[]),
  ('a0f845a9-97ed-5209-bf03-f448d1310bef'::uuid, 'ex_single_leg_glute_bridge', 'Single-Leg Glute Bridges', 'glutes', 'none', 'Lie on your back with knees bent, feet flat on the floor, and arms at your sides.
Lift one leg off the ground, extending it straight or holding knee toward chest.
Drive through the heel of the planted foot, raising hips until thighs and torso align.
Squeeze the working glute hard at top, lower slowly, and repeat before switching sides.', 'assets/exercises/single_leg_glute_bridge.webp', array['lower_back']::text[]),
  ('27c6369d-b125-5622-8031-d70ad08c464a'::uuid, 'ex_plank_to_pushup', 'Plank to Push-up', 'full_body', 'none', 'Start in a forearm plank with elbows directly under shoulders.
Place right hand flat under right shoulder and push up, immediately followed by left hand to reach high plank.
Lower right elbow back down, then left elbow back to forearm plank.
Alternate the leading arm on each rep to balance triceps and shoulder effort.', 'assets/exercises/plank_to_pushup.webp', array['wrist','shoulder']::text[]),
  ('177046e6-ba7f-551a-bc96-24c9851d1133'::uuid, 'ex_v_ups', 'V-ups', 'core', 'none', 'Lie flat on your back with legs straight together and arms extended overhead.
Engage your core to simultaneously lift your straight legs and upper torso off the floor.
Reach hands toward toes, forming a crisp V-shape balancing on your glutes.
Lower under control back to starting position without letting lower back arch.', 'assets/exercises/v_ups.webp', array['lower_back','neck']::text[]),
  ('772bc823-fd07-5537-a715-15b4893eff2c'::uuid, 'ex_hip_flexor_stretch', 'Hip Flexor Stretch', 'legs', 'none', 'Kneel on your back knee with the front foot planted flat at 90 degrees.
Tuck your pelvis slightly underneath you to engage glutes.
Shift your weight gently forward until you feel a deep stretch in the front of your back hip.
Hold with tall spine and relaxed breathing, then switch sides.', 'assets/exercises/hip_flexor_stretch.webp', array['knee']::text[]),
  ('8a416c4d-0adf-562e-be5c-549575a8a585'::uuid, 'ex_chest_stretch', 'Chest Stretch', 'chest', 'none', 'Stand next to a wall or doorway, placing one forearm and elbow flat at shoulder height.
Step forward with the inside leg and gently turn your body away.
Feel a broad opening stretch across your chest and anterior shoulder.
Breathe deeply for the duration, then switch sides.', 'assets/exercises/chest_stretch.webp', array['shoulder']::text[]),
  ('88743500-24cd-5775-a6d4-be2c62fa0fdf'::uuid, 'ex_pigeon_stretch', 'Pigeon Stretch', 'glutes', 'none', 'From all fours, slide right knee forward behind right wrist, angling right foot toward left hip.
Slide left leg straight back along the floor, pointing toes.
Lower hips square toward the floor, keeping hands on ground for support or resting on forearms.
Hold and breathe into the deep outer hip and glute stretch before switching sides.', 'assets/exercises/pigeon_stretch.webp', array['knee','hip']::text[]),
  ('32f68f5e-cbf8-5b29-af41-91d8a2d9bf68'::uuid, 'ex_deep_breathing', 'Deep Breathing', 'full_body', 'none', 'Sit comfortably or lie on your back with hands resting softly on your belly.
Inhale slowly and deeply through your nose for 4 seconds, feeling your belly expand.
Hold gently for 2 seconds.
Exhale slowly and completely through your mouth for 6 seconds, letting your body fully relax.', 'assets/exercises/meditation.webp', '{}'::text[]),
  ('e03b4da0-1f70-5c6b-9907-294d0a476d83'::uuid, 'ex_neck_rotations', 'Neck Rotations (Gentle)', 'shoulders', 'none', 'Stand or sit tall with shoulders relaxed down and away from your ears.
Slowly and gently roll your head in a smooth circle, moving right, back, left, and forward.
Avoid forcing the range of motion; maintain slow, relaxed breathing.
Reverse directions smoothly after completing the desired repetitions.', 'assets/exercises/shoulder_rolls.webp', array['neck']::text[]),
  ('0109a7ed-1a10-527e-a622-5eb04ddd7cc3'::uuid, 'ex_standing_crunches', 'Standing Crunches', 'abs', 'none', 'Stand tall with feet shoulder-width apart, fingertips lightly resting behind your ears.
Shift weight to your left leg, brace your core, and lift your right knee diagonally across your torso.
Crunch your left elbow toward your right knee to contract your obliques and abs.
Lower your foot with control and alternate sides with each rep.', 'assets/exercises/high_knees.webp', '{}'::text[]),
  ('bf1ed4dd-c0c7-5c2a-83f4-a0a33310b91a'::uuid, 'ex_pseudo_planche_pushups', 'Pseudo Planche Push-ups', 'chest', 'none', 'Set up in a standard push-up position with fingers pointed slightly outward.
Walk your hands down toward your waist and lean your shoulders well in front of your wrists.
Maintain protraction (hollow body) and lower yourself until your chest nears the floor.
Press through your palms to return to the top while sustaining the forward shoulder lean.', 'assets/exercises/pushup.webp', array['wrist','shoulder']::text[]),
  ('3fac3af8-6946-5395-81ec-4a6c55a44e6e'::uuid, 'ex_jump_lunges', 'Jump Lunges', 'legs', 'none', 'Begin in a lunge stance with both knees bent at roughly 90 degrees.
Explode vertically upward, swinging your arms for balance and momentum.
Switch your leg positions in mid-air and land softly into the opposite lunge.
Immediately sink into the lunge to absorb the landing and transition smoothly into the next jump.', 'assets/exercises/dynamic_lunges.webp', array['knee']::text[]),
  ('d89688ae-f376-5b56-a266-7e89457fe86f'::uuid, 'ex_single_leg_squats', 'Single-Leg Squats', 'legs', 'none', 'Stand on one leg with the other leg elevated in front or bent behind you.
Reach your arms forward for balance, push your hips back, and bend your working knee.
Lower yourself down into a deep squat while keeping your heel grounded.
Drive firmly through your heel and midfoot to return to full standing lockout.', 'assets/exercises/pistol_squat.webp', array['knee']::text[]),
  ('0cd1910e-46d8-56fd-aceb-2d9c2f8d1422'::uuid, 'ex_hanging_leg_raises', 'Hanging Leg Raises', 'abs', 'pull_up_bar', 'Hang from a pull-up bar with an overhand grip and your body fully extended.
Engage your lats to prevent body swing and brace your core.
Raise your straight legs smoothly until they reach hip height (or higher).
Pause briefly, then lower your legs with strict eccentric control.', 'assets/exercises/straight_leg_raise.webp', array['shoulder','lower_back']::text[]),
  ('2eb12633-0cf3-5828-92a8-caae03953b01'::uuid, 'ex_lsit_hold', 'L-sit Hold', 'abs', 'none', 'Sit with legs straight out on the floor or parallettes, palms planted beside your hips.
Depress your scapulae firmly by pushing into the floor to elevate your torso.
Contract your hip flexors, quads, and abs to lift your straight legs parallel to the floor.
Lock your knees, point your toes, and breathe steadily for the prescribed duration.', 'assets/exercises/v_ups.webp', array['wrist','shoulder']::text[]),
  ('43c203ea-098f-5d24-a43f-ec6607dc5278'::uuid, 'ex_handstand_pushups', 'Handstand Push-up Progression', 'shoulders', 'none', 'Kick up into a wall-supported handstand (or assume an elevated pike handstand stance).
Maintain a tight hollow core with arms fully extended and shoulders shrugged up.
Slowly lower yourself by bending your elbows slightly forward, creating a tripod shape with your head and hands.
Press firmly through your palms and deltoids back to the locked-out handstand position.', 'assets/exercises/pike_pushup.webp', array['wrist','shoulder','neck']::text[]),
  ('83a2283d-b423-5d29-957c-6cffc8866157'::uuid, 'ex_overhead_triceps_stretch', 'Overhead Triceps Stretch', 'arms', 'none', 'Stand or sit tall, reach one arm straight overhead, and bend the elbow so your hand drops behind your neck.
Use your other hand to gently guide the elbow backward and down until you feel a comfortable stretch along the back of the arm.
Keep your neck relaxed, spine upright, and hold while breathing deeply.
Switch arms and repeat on the opposite side.', 'assets/exercises/overhead_triceps_ext.webp', array['shoulder']::text[])
on conflict (id) do update set
  catalog_id = excluded.catalog_id,
  name = excluded.name,
  muscle_group = excluded.muscle_group,
  equipment = excluded.equipment,
  instructions = excluded.instructions,
  animation_asset = excluded.animation_asset,
  contraindications = excluded.contraindications;

-- 3. Atomic transaction RPC for saving workout plans
create or replace function public.save_workout_plan(p_plan jsonb)
returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_plan_id uuid;
  v_plan_id_text text;
  v_title text;
  v_goal text;
  v_level text;
  v_day jsonb;
  v_day_id uuid;
  v_day_id_text text;
  v_day_number int;
  v_day_name text;
  v_ex jsonb;
  v_pe_id uuid;
  v_pe_id_text text;
  v_ex_id_text text;
  v_resolved_ex_id uuid;
  v_sort_order int;
  v_sort int;
  v_sets int;
  v_reps int;
  v_dur int;
  v_rest int;
begin
  if v_uid is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  v_plan_id_text := p_plan->>'id';
  if v_plan_id_text is not null and v_plan_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    v_plan_id := v_plan_id_text::uuid;
  else
    v_plan_id := gen_random_uuid();
  end if;

  v_title := coalesce(nullif(trim(p_plan->>'title'), ''), 'My Custom Plan');
  v_goal := p_plan->>'goal';
  v_level := p_plan->>'level';

  -- Verify ownership if plan already exists
  if exists (select 1 from public.workout_plans where id = v_plan_id) then
    if not exists (
      select 1 from public.workout_plans
      where id = v_plan_id and owner_id = v_uid and is_system = false
    ) then
      raise exception 'Forbidden: cannot modify this plan' using errcode = '42501';
    end if;
  end if;

  -- Upsert plan header
  insert into public.workout_plans (id, title, goal, level, is_system, owner_id)
  values (v_plan_id, v_title, v_goal, v_level, false, v_uid)
  on conflict (id) do update set
    title = excluded.title,
    goal = excluded.goal,
    level = excluded.level;

  -- Delete existing days for this plan (cascades to plan_exercises)
  delete from public.plan_days where plan_id = v_plan_id;

  -- Insert days and exercises
  for v_day in select * from jsonb_array_elements(coalesce(p_plan->'days', '[]'::jsonb))
  loop
    v_day_id_text := v_day->>'id';
    if v_day_id_text is not null and v_day_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      v_day_id := v_day_id_text::uuid;
    else
      v_day_id := gen_random_uuid();
    end if;

    v_day_number := coalesce((v_day->>'day_number')::int, 1);
    v_day_name := coalesce(v_day->>'name', 'Day ' || v_day_number);

    insert into public.plan_days (id, plan_id, day_number, name)
    values (v_day_id, v_plan_id, v_day_number, v_day_name);

    v_sort_order := 0;
    for v_ex in select * from jsonb_array_elements(coalesce(v_day->'exercises', '[]'::jsonb))
    loop
      v_ex_id_text := v_ex->>'exercise_id';
      if v_ex_id_text is null or length(trim(v_ex_id_text)) = 0 then
        continue;
      end if;

      v_resolved_ex_id := null;

      -- 1. Try matching by direct UUID
      if v_ex_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        select id into v_resolved_ex_id from public.exercises where id = v_ex_id_text::uuid;
      end if;

      -- 2. Try matching by catalog_id
      if v_resolved_ex_id is null then
        select id into v_resolved_ex_id from public.exercises where catalog_id = v_ex_id_text;
      end if;

      -- 3. Fallback: generate deterministic UUID v5 and ensure exercise row exists
      if v_resolved_ex_id is null then
        v_resolved_ex_id := extensions.uuid_generate_v5(extensions.uuid_ns_url(), v_ex_id_text);
        insert into public.exercises (id, catalog_id, name)
        values (v_resolved_ex_id, v_ex_id_text, coalesce(v_ex->>'name', v_ex_id_text))
        on conflict (id) do update set catalog_id = coalesce(public.exercises.catalog_id, excluded.catalog_id);
      end if;

      v_pe_id_text := v_ex->>'id';
      if v_pe_id_text is not null and v_pe_id_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
        v_pe_id := v_pe_id_text::uuid;
      else
        v_pe_id := gen_random_uuid();
      end if;

      v_sort := coalesce((v_ex->>'sort_order')::int, v_sort_order);
      v_sets := (v_ex->>'sets')::int;
      v_reps := (v_ex->>'reps')::int;
      v_dur := (v_ex->>'duration_sec')::int;
      v_rest := coalesce((v_ex->>'rest_sec')::int, 45);

      insert into public.plan_exercises (id, plan_day_id, exercise_id, sort_order, sets, reps, duration_sec, rest_sec)
      values (v_pe_id, v_day_id, v_resolved_ex_id, v_sort, v_sets, v_reps, v_dur, v_rest);

      v_sort_order := v_sort_order + 1;
    end loop;
  end loop;

  return jsonb_build_object(
    'id', v_plan_id,
    'title', v_title,
    'status', 'saved'
  );
end;
$$;

revoke all on function public.save_workout_plan(jsonb) from public, anon;
grant execute on function public.save_workout_plan(jsonb) to authenticated;
