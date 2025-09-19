import { addMinutes, setHours, setMinutes, addDays, format } from 'date-fns';
import { Config, Section, ScheduleSlot, Student, TA } from '../types';

export class SchedulingAlgorithm {
  private config: Config;
  private usedSlots: Map<string, Set<string>>;

  constructor(config: Config) {
    this.config = config;
    this.usedSlots = new Map();
  }

  generateSchedule(startDate: Date): Map<string, ScheduleSlot[]> {
    const scheduleBySection = new Map<string, ScheduleSlot[]>();

    for (const section of this.config.sections) {
      const sectionSchedule = this.scheduleSection(section, startDate);
      scheduleBySection.set(section.id, sectionSchedule);
    }

    return scheduleBySection;
  }

  private scheduleSection(section: Section, startDate: Date): ScheduleSlot[] {
    const schedule: ScheduleSlot[] = [];
    const shuffledStudents = this.shuffleArray([...section.students]);
    const ta: TA = {
      id: section.ta_slack_id || section.id,  // Use section ID as fallback
      name: section.ta_name,
      email: section.ta_email,
      slack_id: section.ta_slack_id || '',  // Empty string as fallback
      google_email: section.google_email || section.ta_email,  // Use regular email as fallback
    };

    const availableDays = this.getAvailableDays(section, startDate);
    let currentDayIndex = 0;
    let currentDate = availableDays[currentDayIndex];
    let currentTime = this.parseTime(this.config.scheduling.start_time, currentDate);

    for (const student of shuffledStudents) {
      const slot = this.findNextAvailableSlot(
        student,
        ta,
        section,
        currentDate,
        currentTime,
        availableDays,
        currentDayIndex
      );

      if (slot) {
        schedule.push(slot);
        currentTime = slot.end_time;

        const endTime = this.parseTime(this.config.scheduling.end_time, currentDate);
        if (currentTime >= endTime) {
          currentDayIndex = (currentDayIndex + 1) % availableDays.length;
          if (currentDayIndex < availableDays.length) {
            currentDate = availableDays[currentDayIndex];
            currentTime = this.parseTime(this.config.scheduling.start_time, currentDate);
          }
        }
      }
    }

    return schedule;
  }

  private findNextAvailableSlot(
    student: Student,
    ta: TA,
    section: Section,
    date: Date,
    startTime: Date,
    availableDays: Date[],
    dayIndex: number
  ): ScheduleSlot | null {
    const duration = this.config.scheduling.exam_duration_minutes;
    const buffer = this.config.scheduling.buffer_minutes;
    const totalDuration = duration + buffer;

    let currentDate = date;
    let currentTime = startTime;
    let currentDayIndex = dayIndex;

    while (currentDayIndex < availableDays.length) {
      const endTime = this.parseTime(this.config.scheduling.end_time, currentDate);

      while (currentTime < endTime) {
        const slotEnd = addMinutes(currentTime, duration);

        if (slotEnd <= endTime) {
          const timeKey = `${format(currentDate, 'yyyy-MM-dd')}_${format(currentTime, 'HH:mm')}`;
          const sectionSlots = this.usedSlots.get(section.id) || new Set();

          if (!sectionSlots.has(timeKey)) {
            if (!this.usedSlots.has(section.id)) {
              this.usedSlots.set(section.id, new Set());
            }
            this.usedSlots.get(section.id)!.add(timeKey);

            return {
              student,
              ta,
              section_id: section.id,
              start_time: currentTime,
              end_time: slotEnd,
              location: section.location,
            };
          }
        }

        currentTime = addMinutes(currentTime, totalDuration);
      }

      currentDayIndex++;
      if (currentDayIndex < availableDays.length) {
        currentDate = availableDays[currentDayIndex];
        currentTime = this.parseTime(this.config.scheduling.start_time, currentDate);
      }
    }

    return null;
  }

  private getAvailableDays(section: Section, startDate: Date): Date[] {
    const days: Date[] = [];
    const endDate = addDays(startDate, 7);
    let current = startDate;

    while (current < endDate) {
      const dayName = format(current, 'EEEE');

      if (
        section.preferred_days.includes(dayName) &&
        !this.config.scheduling.excluded_days.includes(dayName)
      ) {
        days.push(current);
      }

      current = addDays(current, 1);
    }

    return days;
  }

  private parseTime(timeString: string, date: Date): Date {
    const [hours, minutes] = timeString.split(':').map(Number);
    return setMinutes(setHours(date, hours), minutes);
  }

  private shuffleArray<T>(array: T[]): T[] {
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
  }

  generateRecurringSchedule(startDate: Date, weeks: number): Map<number, Map<string, ScheduleSlot[]>> {
    const allSchedules = new Map<number, Map<string, ScheduleSlot[]>>();

    for (let week = 0; week < weeks; week++) {
      const weekStart = addDays(startDate, week * this.config.scheduling.schedule_frequency_weeks * 7);
      this.usedSlots.clear();
      const weekSchedule = this.generateSchedule(weekStart);
      allSchedules.set(week, weekSchedule);
    }

    return allSchedules;
  }
}