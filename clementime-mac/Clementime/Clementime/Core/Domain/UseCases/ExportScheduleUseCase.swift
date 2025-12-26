//
//  ExportScheduleUseCase.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import Foundation

struct ExportScheduleInput {
    let courseId: UUID
    let examNumber: Int?  // nil = export all exams
    let includeUnscheduled: Bool
}

struct ExportScheduleOutput {
    let csvURL: URL
    let rowCount: Int
}

class ExportScheduleUseCase {
    private let courseRepository: CourseRepository
    private let studentRepository: StudentRepository
    private let sectionRepository: SectionRepository
    private let scheduleRepository: ScheduleRepository
    private let examSessionRepository: ExamSessionRepository

    init(
        courseRepository: CourseRepository,
        studentRepository: StudentRepository,
        sectionRepository: SectionRepository,
        scheduleRepository: ScheduleRepository,
        examSessionRepository: ExamSessionRepository
    ) {
        self.courseRepository = courseRepository
        self.studentRepository = studentRepository
        self.sectionRepository = sectionRepository
        self.scheduleRepository = scheduleRepository
        self.examSessionRepository = examSessionRepository
    }

    func execute(input: ExportScheduleInput) async throws -> ExportScheduleOutput {
        // 1. Load course
        guard let course = try await courseRepository.fetchCourse(id: input.courseId) else {
            throw UseCaseError.courseNotFound
        }

        // 2. Load exam slots
        let examSlots: [ExamSlot]
        if let examNumber = input.examNumber {
            examSlots = try await scheduleRepository.fetchExamSlots(
                courseId: input.courseId,
                examNumber: examNumber
            )
        } else {
            examSlots = try await scheduleRepository.fetchExamSlots(courseId: input.courseId)
        }

        // 3. Filter unscheduled if needed
        let filteredSlots = input.includeUnscheduled
            ? examSlots
            : examSlots.filter { $0.isScheduled }

        // 4. Load students and sections
        let students = try await studentRepository.fetchStudents(courseId: input.courseId)
        let sections = try await sectionRepository.fetchSections(courseId: input.courseId)
        let examSessions = try await examSessionRepository.fetchExamSessions(courseId: input.courseId)

        // Create lookup dictionaries
        let studentLookup = Dictionary(uniqueKeysWithValues: students.map { ($0.id, $0) })
        let sectionLookup = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0) })
        let examSessionLookup = Dictionary(uniqueKeysWithValues: examSessions.map { ($0.id, $0) })

        // 5. Generate CSV
        var csvRows: [String] = []

        // Header row
        csvRows.append("Student Name,Student Email,SIS ID,Section,Exam Number,Date,Start Time,End Time,Status,Locked,Notes")

        // Data rows
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        for slot in filteredSlots.sorted(by: { $0.date < $1.date || ($0.date == $1.date && $0.startTime < $1.startTime) }) {
            guard let student = studentLookup[slot.studentId],
                  let section = sectionLookup[slot.sectionId],
                  let examSession = examSessionLookup[slot.examSessionId] else {
                continue
            }

            let row = [
                escapeCsvField(student.fullName),
                escapeCsvField(student.email),
                escapeCsvField(student.sisUserId),
                escapeCsvField(section.code),
                "\(examSession.examNumber)",
                slot.isScheduled ? dateFormatter.string(from: slot.date) : "",
                slot.isScheduled ? timeFormatter.string(from: slot.startTime) : "",
                slot.isScheduled ? timeFormatter.string(from: slot.endTime) : "",
                slot.isScheduled ? "Scheduled" : "Unscheduled",
                slot.isLocked ? "Yes" : "No",
                escapeCsvField(slot.notes ?? "")
            ].joined(separator: ",")

            csvRows.append(row)
        }

        // 6. Write to temporary file
        let csvContent = csvRows.joined(separator: "\n")
        let fileName = input.examNumber != nil
            ? "\(sanitizeFileName(course.name))_Exam\(input.examNumber!)_Schedule.csv"
            : "\(sanitizeFileName(course.name))_All_Exams_Schedule.csv"

        let temporaryDirectory = FileManager.default.temporaryDirectory
        let fileURL = temporaryDirectory.appendingPathComponent(fileName)

        try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)

        return ExportScheduleOutput(csvURL: fileURL, rowCount: csvRows.count - 1) // Exclude header
    }

    // MARK: - Helper Methods

    private func escapeCsvField(_ field: String) -> String {
        // Escape quotes and wrap in quotes if contains comma, quote, or newline
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    private func sanitizeFileName(_ name: String) -> String {
        // Remove invalid filename characters
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
}
