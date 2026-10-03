import 'package:fitbuddy/features/health_profile/data/meal_reminder_settings.dart';
import 'package:fitbuddy/features/health_profile/data/medicine.dart';
import 'package:fitbuddy/features/health_profile/reminders/reminder_request.dart';

/// Id of the reminder for time number [index] of a medicine.
String medicineReminderId(String medicineId, int index) =>
    'medicine:$medicineId:$index';

/// Id of the reminder for a meal.
String mealReminderId(MealSlot slot) => 'meal:${slot.name}';

/// Builds one exact reminder per time of [medicine]. The text is a plain
/// reminder: no dosage and no advice.
List<ReminderRequest> buildMedicineReminders(Medicine medicine) {
  return <ReminderRequest>[
    for (var i = 0; i < medicine.reminderTimes.length; i++)
      ReminderRequest(
        id: medicineReminderId(medicine.id, i),
        kind: ReminderKind.medicine,
        title: 'Medicine reminder',
        body: 'Reminder: ${medicine.name}',
        hour: medicine.reminderTimes[i].hour,
        minute: medicine.reminderTimes[i].minute,
        exact: true,
      ),
  ];
}

/// Builds the daily reminder for one meal.
ReminderRequest buildMealReminder(MealSlot slot, MealReminder reminder) {
  return ReminderRequest(
    id: mealReminderId(slot),
    kind: ReminderKind.meal,
    title: '${slot.label} time',
    body: 'A friendly nudge to enjoy a balanced meal.',
    hour: reminder.time.hour,
    minute: reminder.time.minute,
  );
}
