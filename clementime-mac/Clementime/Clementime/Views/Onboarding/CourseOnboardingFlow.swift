//
//  CourseOnboardingFlow.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/20/25.
//

import SwiftUI

struct CourseOnboardingFlow: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var currentStep: OnboardingStep
    
    init(initialStep: OnboardingStep = .courseInfo) {
        _currentStep = State(initialValue: initialStep)
    }

    enum OnboardingStep: Int, CaseIterable {
        case courseInfo = 0
        case addTAs = 1
        case uploadRoster = 2
        case matching = 3
        case createCohorts = 4
        case scheduleStructure = 5

        var title: String {
            switch self {
            case .courseInfo: return "Course\nDetails"
            case .addTAs: return "Add\nTAs"
            case .uploadRoster: return "Import\nStudents"
            case .matching: return "Validate\nStudents"
            case .createCohorts: return "Create\nCohorts"
            case .scheduleStructure: return "Schedule\nSetup"
            }
        }

        func icon(viewModel: OnboardingViewModel) -> String {
            switch self {
            case .courseInfo: return "book.fill"
            case .addTAs: return "person.3.fill"
            case .uploadRoster: return "person.crop.circle.badge.plus"
            case .matching: return "sparkles"
            case .createCohorts: return "square.grid.3x3.fill"
            case .scheduleStructure: return "calendar.badge.clock"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with progress
            headerView

            Divider()

            // Content area
            ZStack {
                Color(NSColor.textBackgroundColor)

                switch currentStep {
                case .courseInfo:
                    CourseInfoStep(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .addTAs:
                    AddTAsStep(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .uploadRoster:
                    UploadRosterStep(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .matching:
                    MatchingAnimationStep(viewModel: viewModel, onComplete: {
                        withAnimation(.spring(duration: 0.5)) {
                            currentStep = .createCohorts
                        }
                    })
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .createCohorts:
                    CreateCohortsStep(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                case .scheduleStructure:
                    ScheduleStructureStep(viewModel: viewModel)
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }

            Divider()

            // Footer navigation
            footerView
        }
        .frame(width: 700, height: 600)
        .onAppear {
            viewModel.setupObservers()
        }
    }

    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Create New Course")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: 32, height: 32)

                            Image(systemName: step.icon(viewModel: viewModel))
                                .font(.caption)
                                .foregroundColor(step.rawValue <= currentStep.rawValue ? .white : .secondary)
                        }

                        Text(step.title)
                            .font(.caption2)
                            .foregroundColor(step == currentStep ? .primary : .secondary)
                            .multilineTextAlignment(.center)
                            .frame(width: 80)
                    }

                    if step != OnboardingStep.allCases.last {
                        Rectangle()
                            .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var footerView: some View {
        HStack(spacing: 12) {
            if currentStep != .courseInfo {
                Button("Back") {
                    withAnimation(.spring(duration: 0.5)) {
                        if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                            currentStep = previousStep
                        }
                    }
                }
                .keyboardShortcut(.cancelAction)
            }

            Spacer()

            if currentStep == .scheduleStructure {
                Button("Finish") {
                    Task {
                        await viewModel.createCourse()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canFinish)
            } else if currentStep != .matching {
                Button("Continue") {
                    withAnimation(.spring(duration: 0.5)) {
                        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                            currentStep = nextStep
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!viewModel.canContinue(from: currentStep))
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Step 1: Course Info

struct CourseInfoStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
              Spacer()

                Text("Let's create your course!")
                    .font(.title2)
                    .fontWeight(.semibold)

              VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 0) {
                        Text("Course Icon")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(width: 100, alignment: .leading)

                        Button(action: { viewModel.showIconPicker.toggle() }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 50, height: 50)

                                Image(systemName: viewModel.selectedIcon)
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $viewModel.showIconPicker) {
                            IconPickerPopover(
                                selectedIcon: $viewModel.selectedIcon,
                                iconOptions: viewModel.iconOptions,
                                onSelect: { viewModel.showIconPicker = false }
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Course Name")
                        .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextField("e.g., PSYCH 10 / STATS 60", text: $viewModel.courseName)
                        .textFieldStyle(.automatic)
                            .font(.body)
                            .fontWeight(.thin)
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Term")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextField("e.g., Fall 2025", text: $viewModel.term)
                        .textFieldStyle(.automatic)
                            .font(.body)
                            .fontWeight(.thin)
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        TextEditor(text: $viewModel.courseDescription)
                            .font(.body)
                            .fontWeight(.thin)
                            .frame(height: 60)
                            .padding(6)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Step 2: Add TAs

struct AddTAsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 20)

                Text("Add your teaching assistants")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("How many TAs will help with this course?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // TA Count Picker
                HStack(spacing: 20) {
                    Button(action: {
                        if viewModel.taCount > 0 {
                            viewModel.taCount -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(viewModel.taCount > 0 ? .accentColor : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.taCount == 0)

                    Text("\(viewModel.taCount)")
                        .font(.system(size: 48, weight: .bold))
                        .frame(width: 80)

                    Button(action: {
                        if viewModel.taCount < 20 {
                            viewModel.taCount += 1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(viewModel.taCount < 20 ? .accentColor : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.taCount >= 20)
                }
                .padding()

                if viewModel.taCount > 0 {
                    Divider()
                        .padding(.horizontal, 40)

                    Text("Enter TA information")
                        .font(.headline)
                        .padding(.top, 10)

                    VStack(spacing: 16) {
                        ForEach(0..<viewModel.taCount, id: \.self) { index in
                            TAFormRow(viewModel: viewModel, index: index)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct TAFormRow: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.accentColor)
                Text("TA #\(index + 1)")
                    .font(.headline)
            }

            HStack(spacing: 12) {
                TextField("First Name", text: binding(for: index, keyPath: \.firstName))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)

                TextField("Last Name", text: binding(for: index, keyPath: \.lastName))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }

            TextField("Email", text: binding(for: index, keyPath: \.email))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func binding(for index: Int, keyPath: WritableKeyPath<OnboardingViewModel.TAInfo, String>) -> Binding<String> {
        Binding(
            get: { viewModel.tas[safe: index]?[keyPath: keyPath] ?? "" },
            set: {
                if viewModel.tas.indices.contains(index) {
                    viewModel.tas[index][keyPath: keyPath] = $0
                }
            }
        )
    }
}

// MARK: - Step 3: Upload Roster

struct UploadRosterStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Import your student roster")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Upload a CSV file from Canvas or use sample data for testing")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
          
          if !viewModel.rosterLoaded {
            HStack(spacing: 20) {
              // Upload option
              Button(action: {
                viewModel.selectRosterFile()
              }) {
                ZStack {
                  RoundedRectangle(cornerRadius: 12)
                    .fill(isDragging ? Color.accentColor.opacity(0.2) : Color.accentColor.opacity(0.1))
                    .frame(width: 200, height: 150)
                  
                  VStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc.fill")
                      .font(.system(size: 40))
                      .foregroundColor(.accentColor)
                    
                    Text("Upload CSV")
                      .font(.headline)
                    
                    Text("From Canvas")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
              }
              .buttonStyle(.plain)
              .onDrop(of: ["public.file-url"], isTargeted: $isDragging) { providers in
                return viewModel.handleRosterDrop(providers)
              }
              
              // Sample data option
              Button(action: {
                viewModel.useSampleRoster()
              }) {
                ZStack {
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 200, height: 150)
                  
                  VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                      .font(.system(size: 40))
                      .foregroundColor(.green)
                    
                    Text("Use Sample Data")
                      .font(.headline)
                    
                    Text("For testing")
                      .font(.caption)
                      .foregroundColor(.secondary)
                  }
                }
              }
              .buttonStyle(.plain)
            }
            .fixedSize()
          }

            

            if viewModel.rosterLoaded {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Loaded \(viewModel.studentCount) students")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Step 4: Matching Animation

struct MatchingAnimationStep: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let onComplete: () -> Void
    @State private var progress: Double = 0
    @State private var currentMessage = "Analyzing student data..."

    let messages = [
        "Analyzing student data...",
        "Matching students with TAs...",
        "Optimizing assignments...",
        "Finalizing matches..."
    ]

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }
            .animation(.easeInOut(duration: 0.3), value: progress)

            Text(currentMessage)
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(Int(progress * 100))%")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        var messageIndex = 0

        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { timer in
            if progress < 1.0 {
                progress += 0.25

                if messageIndex < messages.count {
                    currentMessage = messages[messageIndex]
                    messageIndex += 1
                }
            } else {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Step 5: Create Cohorts

struct CreateCohortsStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 20)

                Text("Create cohort structure")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Cohorts divide students into groups for different exam weeks")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Text("Note: An \"All Students\" cohort will be created automatically")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)

                // Cohort Count Picker
                HStack(spacing: 20) {
                    Button(action: {
                        if viewModel.cohortCount > 1 {
                            viewModel.cohortCount -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(viewModel.cohortCount > 1 ? .accentColor : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.cohortCount <= 1)

                    VStack(spacing: 4) {
                        Text("\(viewModel.cohortCount)")
                            .font(.system(size: 48, weight: .bold))
                        Text("cohorts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 120)

                    Button(action: {
                        if viewModel.cohortCount < 10 {
                            viewModel.cohortCount += 1
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(viewModel.cohortCount < 10 ? .accentColor : .secondary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.cohortCount >= 10)
                }
                .padding()

                if viewModel.cohortCount > 0 {
                    Divider()
                        .padding(.horizontal, 40)

                    VStack(spacing: 16) {
                        ForEach(0..<viewModel.cohortCount, id: \.self) { index in
                            CohortFormRow(viewModel: viewModel, index: index)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct CohortFormRow: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ColorPicker("", selection: binding(for: index, keyPath: \.color))
                .labelsHidden()
                .frame(width: 40)

            TextField("Cohort Name (e.g., A, B, C)", text: binding(for: index, keyPath: \.name))
            .textFieldStyle(.automatic)
            .fontWeight(.thin)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private func binding(for index: Int, keyPath: WritableKeyPath<OnboardingViewModel.CohortInfo, String>) -> Binding<String> {
        Binding(
            get: { 
                guard let cohort = viewModel.cohorts[safe: index] else { return "" }
                let value = cohort[keyPath: keyPath]
                return value.isEmpty ? "" : value
            },
            set: {
                if viewModel.cohorts.indices.contains(index) {
                    viewModel.cohorts[index][keyPath: keyPath] = $0
                }
            }
        )
    }

    private func binding(for index: Int, keyPath: WritableKeyPath<OnboardingViewModel.CohortInfo, Color>) -> Binding<Color> {
        Binding(
            get: { viewModel.cohorts[safe: index]?[keyPath: keyPath] ?? .blue },
            set: {
                if viewModel.cohorts.indices.contains(index) {
                    viewModel.cohorts[index][keyPath: keyPath] = $0
                }
            }
        )
    }
}

// MARK: - Step 6: Schedule Structure

struct ScheduleStructureStep: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.top, 20)

                Text("Set up your exam schedule")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quarter Start Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        DatePicker("", selection: $viewModel.quarterStartDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quarter End Date")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        DatePicker("", selection: $viewModel.quarterEndDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Number of Exams")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Stepper("\(viewModel.totalExams) exams", value: $viewModel.totalExams, in: 1...20)
                    }

                    Divider()

                    Text("Exam sessions will be automatically generated based on the quarter dates. You can configure specific times and durations for each exam session later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Helper Extension

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
  CourseOnboardingFlow(initialStep: .matching)
}

