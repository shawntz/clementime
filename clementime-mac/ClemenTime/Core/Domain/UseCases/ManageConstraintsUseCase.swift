//
//  ManageConstraintsUseCase.swift
//  ClemenTime
//
//  Created by Claude on 2025-12-19.
//

import Foundation

struct AddConstraintInput {
    let studentId: UUID
    let constraintType: ConstraintType
    let constraintValue: String
    let constraintDescription: String
}

struct UpdateConstraintInput {
    let constraintId: UUID
    let constraintValue: String
    let constraintDescription: String
    let isActive: Bool
}

class ManageConstraintsUseCase {
    private let constraintRepository: ConstraintRepository
    private let studentRepository: StudentRepository

    init(constraintRepository: ConstraintRepository, studentRepository: StudentRepository) {
        self.constraintRepository = constraintRepository
        self.studentRepository = studentRepository
    }

    func addConstraint(input: AddConstraintInput) async throws -> Constraint {
        // 1. Validate student exists
        guard let student = try await studentRepository.fetchStudent(id: input.studentId) else {
            throw UseCaseError.invalidInput
        }

        // 2. Validate constraint value format
        try validateConstraintValue(type: input.constraintType, value: input.constraintValue)

        // 3. Create constraint
        let constraint = Constraint(
            id: UUID(),
            studentId: student.id,
            constraintType: input.constraintType,
            constraintValue: input.constraintValue,
            constraintDescription: input.constraintDescription,
            isActive: true
        )

        return try await constraintRepository.createConstraint(constraint)
    }

    func updateConstraint(input: UpdateConstraintInput) async throws {
        // 1. Fetch existing constraint
        guard var constraint = try await constraintRepository.fetchConstraint(id: input.constraintId) else {
            throw UseCaseError.invalidInput
        }

        // 2. Validate new value format
        try validateConstraintValue(type: constraint.constraintType, value: input.constraintValue)

        // 3. Update constraint
        constraint.constraintValue = input.constraintValue
        constraint.constraintDescription = input.constraintDescription
        constraint.isActive = input.isActive

        try await constraintRepository.updateConstraint(constraint)
    }

    func deleteConstraint(constraintId: UUID) async throws {
        try await constraintRepository.deleteConstraint(id: constraintId)
    }

    func toggleConstraint(constraintId: UUID) async throws {
        try await constraintRepository.toggleConstraint(id: constraintId)
    }

    // MARK: - Private Validation

    private func validateConstraintValue(type: ConstraintType, value: String) throws {
        switch type {
        case .timeBefore, .timeAfter:
            // Validate time format (HH:MM)
            let components = value.split(separator: ":").map { Int($0) }
            guard components.count == 2,
                  let hour = components[0],
                  let minute = components[1],
                  hour >= 0, hour < 24,
                  minute >= 0, minute < 60 else {
                throw UseCaseError.invalidInput
            }

        case .specificDate, .excludeDate:
            // Validate date format (yyyy-MM-dd)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            guard formatter.date(from: value) != nil else {
                throw UseCaseError.invalidInput
            }

        case .weekPreference:
            // Validate week type (odd or even)
            guard value == "odd" || value == "even" else {
                throw UseCaseError.invalidInput
            }
        }
    }
}
