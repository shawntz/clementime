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

  private scheduleSectionForWeek(section: Section, startDate: Date, weekNumber: number): ScheduleSlot[] {
    // Check if student splitting is enabled for this section
    if (!section.student_split?.enabled) {
      // No splitting, but still add variation for time slots across weeks
      const studentsWithVariation = this.addTimeSlotVariation([...section.students], weekNumber);
      const tempSection: Section = {
        ...section,
        students: studentsWithVariation
      };
      return this.scheduleSection(tempSection, startDate);
    }

    const splitConfig = section.student_split;
    // Use a deterministic shuffle based on section ID and CYCLE (not week) to ensure consistency within a split cycle
    const splitCycleLength = splitConfig.weeks_between_splits * 2;
    const cycleNumber = Math.floor(weekNumber / splitCycleLength);
    const students = this.getDeterministicShuffledStudents(section.students, section.id, cycleNumber);

    // Calculate which students should be scheduled in this week
    const studentsForThisWeek = this.getStudentsForWeek(students, weekNumber, splitConfig);

    if (studentsForThisWeek.length === 0) {
      // No students to schedule for this week
      return [];
    }

    // Add time slot variation to prevent students from always getting the same time
    const studentsWithVariation = this.addTimeSlotVariation(studentsForThisWeek, weekNumber);

    // Create a temporary section with only the students for this week
    const tempSection: Section = {
      ...section,
      students: studentsWithVariation
    };

    return this.scheduleSection(tempSection, startDate);
  }

  private getDeterministicShuffledStudents(students: Student[], sectionId: string, weekNumber: number): Student[] {
    // Create a deterministic shuffle based on section ID and week number
    const seed = this.hashCode(sectionId) + weekNumber;
    return this.seededShuffle([...students], seed);
  }

  private addTimeSlotVariation(students: Student[], weekNumber: number): Student[] {
    // Rotate the student order based on week number to vary time slot assignments
    const rotationOffset = weekNumber % students.length;
    return this.rotateArray(students, rotationOffset);
  }

  private hashCode(str: string): number {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      const char = str.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash);
  }

  private seededShuffle<T>(array: T[], seed: number): T[] {
    const shuffled = [...array];
    let currentSeed = seed;

    for (let i = shuffled.length - 1; i > 0; i--) {
      // Simple linear congruential generator for deterministic randomness
      currentSeed = (currentSeed * 1664525 + 1013904223) % Math.pow(2, 32);
      const j = Math.floor((currentSeed / Math.pow(2, 32)) * (i + 1));
      [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }

    return shuffled;
  }

  private getStudentsForWeek(students: Student[], weekNumber: number, splitConfig: NonNullable<Section['student_split']>): Student[] {
    const totalStudents = students.length;
    const weeksBetweenSplits = splitConfig.weeks_between_splits;

    // Simple split: divide students in half
    const middleIndex = Math.ceil(totalStudents / 2);

    // Determine which split cycle we're in and which part of the cycle
    const splitCycleLength = weeksBetweenSplits * 2;
    const positionInCycle = weekNumber % splitCycleLength;

    console.log(`🔍 Student Split Debug for Week ${weekNumber}:`);
    console.log(`  Total students: ${totalStudents}`);
    console.log(`  Middle index: ${middleIndex}`);
    console.log(`  Position in cycle: ${positionInCycle}`);
    console.log(`  Weeks between splits: ${weeksBetweenSplits}`);

    if (positionInCycle < weeksBetweenSplits) {
      // First part of the cycle - schedule first half of students
      const selectedStudents = students.slice(0, middleIndex);
      console.log(`  → Selecting FIRST half (${selectedStudents.length} students): ${selectedStudents.map(s => s.name).join(', ')}`);
      return selectedStudents;
    } else {
      // Second part of the cycle - schedule second half of students
      const selectedStudents = students.slice(middleIndex);
      console.log(`  → Selecting SECOND half (${selectedStudents.length} students): ${selectedStudents.map(s => s.name).join(', ')}`);
      return selectedStudents;
    }
  }

  private rotateArray<T>(array: T[], positions: number): T[] {
    const normalizedPositions = positions % array.length;
    return [...array.slice(normalizedPositions), ...array.slice(0, normalizedPositions)];
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
      const weekSchedule = this.generateScheduleForWeek(weekStart, week);
      allSchedules.set(week, weekSchedule);
    }

    return allSchedules;
  }

  generateScheduleForWeek(startDate: Date, weekNumber: number): Map<string, ScheduleSlot[]> {
    const scheduleBySection = new Map<string, ScheduleSlot[]>();

    for (const section of this.config.sections) {
      const sectionSchedule = this.scheduleSectionForWeek(section, startDate, weekNumber);
      scheduleBySection.set(section.id, sectionSchedule);
    }

    return scheduleBySection;
  }
}