//
//  OnboardingViewModel.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/20/25.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
class OnboardingViewModel: ObservableObject {
    // Course Info
    @Published var courseName = ""
    @Published var term = ""
    @Published var courseDescription = ""
    @Published var selectedIcon = "book.fill"
    @Published var showIconPicker = false

    // TAs
    @Published var taCount = 0
    @Published var tas: [TAInfo] = []

    // Roster
    @Published var rosterLoaded = false
    @Published var studentCount = 0
    @Published var rosterFilePath: URL?
    private var parsedStudents: [ParsedStudent] = []

    struct ParsedStudent {
        let fullName: String
        let sisUserId: String
        let email: String
        let sectionNames: [String]
    }

    // Cohorts
    @Published var cohortCount = 2
    @Published var cohorts: [CohortInfo] = []

    // Schedule
    @Published var quarterStartDate = Date()
    @Published var quarterEndDate = Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date() // Default to ~10 weeks
    @Published var totalExams = 5

    let iconOptions = [
        "book.fill", "graduationcap.fill", "brain.head.profile",
        "function", "chart.bar.fill", "network",
        "atom", "flask.fill", "cross.case.fill",
        "doc.text.fill", "folder.fill", "calendar",
        "pencil", "lightbulb.fill", "star.fill",
        "checkmark.circle.fill", "bell.fill", "flag.fill",
        "music.note", "paintbrush.fill", "photo.fill",
        "hammer.fill", "wrench.fill", "cpu",
        "gamecontroller.fill", "sportscourt.fill", "leaf.fill"
    ]

    private lazy var courseRepository: CourseRepository = PersistenceController.shared.courseRepository
    private lazy var taUserRepository: TAUserRepository = PersistenceController.shared.taUserRepository
    private lazy var cohortRepository: CohortRepository = PersistenceController.shared.cohortRepository
    private lazy var studentRepository: StudentRepository = PersistenceController.shared.studentRepository
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Repositories will be lazily initialized on first access
    }

    func setupObservers() {
        // Observe TA count changes
        $taCount
            .sink { [weak self] count in
                self?.updateTAList(count: count)
            }
            .store(in: &cancellables)

        // Observe cohort count changes
        $cohortCount
            .sink { [weak self] count in
                self?.updateCohortList(count: count)
            }
            .store(in: &cancellables)

        // Initialize with 2 cohorts by default
        updateCohortList(count: 2)
    }

    // MARK: - TA Info

    struct TAInfo: Identifiable {
        let id = UUID()
        var firstName = ""
        var lastName = ""
        var email = ""
    }

    private func updateTAList(count: Int) {
        if count > tas.count {
            // Add new TAs
            tas.append(contentsOf: (tas.count..<count).map { _ in TAInfo() })
        } else if count < tas.count {
            // Remove excess TAs
            tas = Array(tas.prefix(count))
        }
    }

    // MARK: - Cohort Info

    struct CohortInfo: Identifiable {
        let id = UUID()
        var name = ""
        var color: Color = .blue
    }

    private func updateCohortList(count: Int) {
        let defaultColors: [Color] = [.blue, .green, .orange, .purple, .red, .pink, .cyan, .indigo, .mint, .teal]

        if count > cohorts.count {
            // Add new cohorts with empty names
            var newCohorts: [CohortInfo] = []
            for index in cohorts.count..<count {
                let color = index < defaultColors.count ? defaultColors[index] : Color.blue
                newCohorts.append(CohortInfo(name: "", color: color))
            }
            cohorts.append(contentsOf: newCohorts)
        } else if count < cohorts.count {
            // Remove excess cohorts
            cohorts = Array(cohorts.prefix(count))
        }
    }

    // MARK: - Roster Upload

    func selectRosterFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            if let url = panel.url {
                processRosterFile(url)
            }
        }
    }

    func handleRosterDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

            DispatchQueue.main.async {
                self?.processRosterFile(url)
            }
        }

        return true
    }

    private func processRosterFile(_ url: URL) {
        // Start accessing security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource")
            return
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            parsedStudents = parseCSV(csvContent)
            studentCount = parsedStudents.count

            rosterFilePath = url
            rosterLoaded = true

            print("✅ Successfully loaded roster with \(studentCount) students")
        } catch {
            print("❌ Error reading CSV file: \(error.localizedDescription)")
            rosterLoaded = false
        }
    }

    private func parseCSV(_ csvContent: String) -> [ParsedStudent] {
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard lines.count > 1 else { return [] } // Need at least header + 1 data row

        var students: [ParsedStudent] = []

        // Skip header row (first line)
        for line in lines.dropFirst() {
            // Parse CSV line handling quoted fields
            let fields = parseCSVLine(line)

            // CSV structure: Student Name, Student ID, Student SIS ID, Email, Section Name
            guard fields.count >= 5 else {
                print("⚠️ Skipping invalid line: \(line)")
                continue
            }

            let fullName = fields[0].trimmingCharacters(in: .whitespaces)
            let sisUserId = fields[2].trimmingCharacters(in: .whitespaces)
            let email = fields[3].trimmingCharacters(in: .whitespaces)
            let sectionNamesRaw = fields[4].trimmingCharacters(in: .whitespaces)

            // Parse section names (can be comma-separated)
            let sectionNames = sectionNamesRaw
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            students.append(ParsedStudent(
                fullName: fullName,
                sisUserId: sisUserId,
                email: email,
                sectionNames: sectionNames
            ))
        }

        return students
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Add the last field
        fields.append(currentField)

        return fields
    }

    func useSampleRoster() {
        // Generate realistic sample data based on CSV structure
        let sampleNames = [
            "Alice Johnson", "Bob Smith", "Carol Williams", "David Brown",
            "Emma Davis", "Frank Miller", "Grace Wilson", "Henry Moore",
            "Isabella Taylor", "Jack Anderson", "Katherine Thomas", "Liam Jackson",
            "Mia White", "Noah Harris", "Olivia Martin", "Peter Thompson",
            "Quinn Garcia", "Rachel Martinez", "Sam Robinson", "Tara Clark",
            "Uma Rodriguez", "Victor Lewis", "Wendy Lee", "Xavier Walker", "Yara Hall"
        ]

        parsedStudents = sampleNames.enumerated().map { index, name in
            let firstName = name.components(separatedBy: " ").first ?? ""
            let lastName = name.components(separatedBy: " ").last ?? ""
            let email = "\(firstName.lowercased())\(lastName.lowercased())@stanford.edu"
            let sisId = String(format: "%08d", 10000000 + index)

            return ParsedStudent(
                fullName: name,
                sisUserId: sisId,
                email: email,
                sectionNames: ["F25-PSYCH-10-01", "F25-PSYCH-10-09"]
            )
        }

        studentCount = parsedStudents.count
        rosterLoaded = true

        print("✅ Generated \(studentCount) sample students")
    }

    // MARK: - Validation

    func canContinue(from step: CourseOnboardingFlow.OnboardingStep) -> Bool {
        switch step {
        case .courseInfo:
            return !courseName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !term.trimmingCharacters(in: .whitespaces).isEmpty

        case .addTAs:
            guard taCount > 0 else { return false }
            return tas.allSatisfy { !$0.firstName.isEmpty && !$0.lastName.isEmpty && !$0.email.isEmpty }

        case .uploadRoster:
            return rosterLoaded

        case .matching:
            return true // Animation auto-advances

        case .createCohorts:
            guard cohortCount > 0 else { return false }
            return cohorts.allSatisfy { !$0.name.isEmpty }

        case .scheduleStructure:
            return true
        }
    }

    var canFinish: Bool {
        canContinue(from: .scheduleStructure)
    }

    // MARK: - Create Course

    func createCourse() async {
        guard !courseName.isEmpty, !term.isEmpty else { return }

        do {
            // Create course settings
            let settings = CourseSettings(
                balancedTAScheduling: false
            )

            // Store icon and description in metadata
            var metadata: [String: String] = ["icon": selectedIcon]
            if !courseDescription.isEmpty {
                metadata["description"] = courseDescription
            }

            // Create course
            let course = Course(
                id: UUID(),
                name: courseName.trimmingCharacters(in: .whitespaces),
                term: term.trimmingCharacters(in: .whitespaces),
                quarterStartDate: quarterStartDate,
                quarterEndDate: quarterEndDate,
                totalExams: totalExams,
                isActive: true,
                createdBy: UUID(),
                settings: settings,
                metadata: metadata
            )

            let createdCourse = try await courseRepository.createCourse(course)

            // Create TAs
            for ta in tas where !ta.firstName.isEmpty && !ta.lastName.isEmpty {
                let taUser = TAUser(
                    courseId: createdCourse.id,
                    firstName: ta.firstName,
                    lastName: ta.lastName,
                    email: ta.email,
                    username: ta.email.components(separatedBy: "@").first ?? ta.email,
                    role: .ta,
                    customPermissions: Permission.defaultTAPermissions()
                )
                _ = try await taUserRepository.createTAUser(taUser)
            }

            // Create default "All Students" cohort
            let allStudentsCohort = Cohort(
                courseId: createdCourse.id,
                name: "All Students",
                colorHex: "#6B7280", // Gray color
                sortOrder: -1,
                isDefault: true
            )
            _ = try await cohortRepository.createCohort(allStudentsCohort)

            // Create user-defined cohorts and store them
            var createdCohorts: [Cohort] = []
            for (index, cohortInfo) in cohorts.enumerated() where !cohortInfo.name.isEmpty {
                let cohort = Cohort(
                    courseId: createdCourse.id,
                    name: cohortInfo.name,
                    colorHex: cohortInfo.color.toHex(),
                    sortOrder: index,
                    isDefault: false
                )
                let created = try await cohortRepository.createCohort(cohort)
                createdCohorts.append(created)
            }

            // Import students from roster
            if !parsedStudents.isEmpty {
                // Use the default "All Students" cohort for now
                let defaultCohortId = allStudentsCohort.id
                // Use a placeholder section ID (UUID zero) - students will be assigned to sections later
                let placeholderSectionId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

                for parsedStudent in parsedStudents {
                    let student = Student(
                        courseId: createdCourse.id,
                        sectionId: placeholderSectionId,
                        sisUserId: parsedStudent.sisUserId,
                        email: parsedStudent.email,
                        fullName: parsedStudent.fullName,
                        cohortId: defaultCohortId,
                        isActive: true
                    )
                    _ = try await studentRepository.createStudent(student)
                }

                print("✅ Imported \(parsedStudents.count) students from roster")
            }

            print("✅ Course created successfully with \(tas.count) TAs, \(cohorts.count + 1) cohorts, and \(parsedStudents.count) students")
        } catch {
            print("❌ Error creating course: \(error)")
        }
    }
}
