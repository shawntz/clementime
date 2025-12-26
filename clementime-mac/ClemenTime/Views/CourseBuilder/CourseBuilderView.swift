//
//  CourseBuilderView.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/19/25.
//

import SwiftUI

// MARK: - Helper for Current User ID
private extension UserDefaults {
    var currentUserId: UUID {
        let key = "com.shawnschwartz.clementime.currentUserId"
        if let uuidString = string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        let newId = UUID()
        set(newId.uuidString, forKey: key)
        return newId
    }
}

struct CourseBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @State private var courseName = ""
    @State private var term = ""
    @State private var courseDescription = ""
    @State private var selectedIcon = "book.fill"
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showIconPicker = false

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

    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 16) {
                // Icon Picker
                HStack(spacing: 0) {
                    Text("")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
//                        .frame(width: 80, alignment: .leading)

                    Button(action: {
                        showIconPicker.toggle()
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 50, height: 50)

                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showIconPicker, arrowEdge: .bottom) {
                        IconPickerPopover(selectedIcon: $selectedIcon, iconOptions: iconOptions, onSelect: {
                            showIconPicker = false
                        })
                    }

                    Spacer()
                  
                  // Course Name
                  VStack(alignment: .leading, spacing: 6) {
                    Text(" Course Name")
                      .font(.headline)
                      .fontWeight(.medium)
                      .foregroundColor(.secondary)
                    
                    TextField("PSYCH 10", text: $courseName)
                      .textFieldStyle(.plain)
                      .font(.body)
                      .padding(10)
                      .background(Color(NSColor.controlBackgroundColor))
                      .cornerRadius(6)
                  }
                  
                  Spacer()
                  
                  // Term
                  VStack(alignment: .leading, spacing: 6) {
                    Text("Term")
                      .font(.headline)
                      .fontWeight(.medium)
                      .foregroundColor(.secondary)
                    
                    TextField("Fall 2025", text: $term)
                      .textFieldStyle(.plain)
                      .font(.body)
                      .padding(10)
                      .background(Color(NSColor.controlBackgroundColor))
                      .cornerRadius(6)
                  }
                }

                

                

                // Description
                VStack(alignment: .leading, spacing: 6) {
                    Text("Description (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    TextEditor(text: $courseDescription)
                        .font(.body)
                        .frame(height: 50)
                        .padding(6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Footer
            HStack {
              Button("Cancel", role: .destructive) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

              Spacer()
              
              Button(
                "Create Course",
                systemImage: "checkmark.circle",
                action: createCourse
              )
              .keyboardShortcut(.defaultAction)
              .disabled(!isValid || isCreating)
              .buttonStyle(.borderedProminent)
              .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 460)
    }

    private var isValid: Bool {
        !courseName.isEmpty && !term.isEmpty
    }

    private func createCourse() {
        guard !courseName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a course name"
            return
        }

        guard !term.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter a term"
            return
        }

        isCreating = true
        errorMessage = nil

        Task {
            do {
                // Create course with default settings
                let settings = CourseSettings(
                    balancedTAScheduling: false
                )

                // Store icon and description in metadata
                var metadata: [String: String] = [
                    "icon": selectedIcon
                ]
                if !courseDescription.isEmpty {
                    metadata["description"] = courseDescription
                }

                let course = Course(
                    id: UUID(),
                    name: courseName.trimmingCharacters(in: .whitespaces),
                    term: term.trimmingCharacters(in: .whitespaces),
                    quarterStartDate: Date(), // Default to today
                    quarterEndDate: Calendar.current.date(byAdding: .day, value: 70, to: Date()) ?? Date(), // Default to ~10 weeks
                    totalExams: 5, // Default to 5 exams
                    isActive: true,
                    createdBy: UserDefaults.standard.currentUserId,
                    settings: settings,
                    metadata: metadata
                )

                // Save course directly via repository (simplified creation - user will configure details later)
                _ = try await PersistenceController.shared.courseRepository.createCourse(course)

                isCreating = false
                dismiss()
            } catch {
                isCreating = false
                errorMessage = "Failed to create course: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Icon Picker Popover

struct IconPickerPopover: View {
    @Binding var selectedIcon: String
    let iconOptions: [String]
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose An Icon")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Icon Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6), spacing: 8) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            onSelect()
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                                    .frame(width: 44, height: 44)

                                Image(systemName: icon)
                                    .font(.title3)
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
            }
            .frame(height: 200)
        }
        .frame(width: 320)
    }
}

#Preview {
    CourseBuilderView()
}
