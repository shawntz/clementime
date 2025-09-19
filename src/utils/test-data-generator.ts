import { Student, Section } from '../types';

export class TestDataGenerator {
  static generateFakeStudents(
    count: number,
    prefix: string = 'Test Student',
    baseSlackId?: string
  ): Student[] {
    const students: Student[] = [];

    for (let i = 1; i <= count; i++) {
      students.push({
        name: `${prefix} ${i}`,
        email: `test.student.${i}@test.edu`,
        slack_id: baseSlackId // All fake students will use the same Slack ID in test mode
      });
    }

    return students;
  }

  static distributeStudentsToSections(
    students: Student[],
    sections: Section[]
  ): Section[] {
    const studentsPerSection = Math.ceil(students.length / sections.length);
    const updatedSections: Section[] = [];

    let studentIndex = 0;
    for (const section of sections) {
      const sectionStudents: Student[] = [];

      for (let i = 0; i < studentsPerSection && studentIndex < students.length; i++) {
        sectionStudents.push(students[studentIndex]);
        studentIndex++;
      }

      updatedSections.push({
        ...section,
        students: sectionStudents
      });
    }

    return updatedSections;
  }

  static createTestSections(
    originalSections: Section[],
    numberOfFakeStudents: number = 30,
    fakeStudentPrefix: string = 'Test Student',
    testSlackId?: string
  ): Section[] {
    const fakeStudents = this.generateFakeStudents(
      numberOfFakeStudents,
      fakeStudentPrefix,
      testSlackId
    );

    const updatedSections = this.distributeStudentsToSections(fakeStudents, originalSections);

    // In test mode, ensure all TAs have the test Slack ID so TA workflow can be tested
    if (testSlackId) {
      return updatedSections.map(section => ({
        ...section,
        ta_slack_id: testSlackId // Use test Slack ID for TA notifications
      }));
    }

    return updatedSections;
  }
}