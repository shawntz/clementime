//
//  PDFGenerator.swift
//  Clementime
//
//  Created by Shawn Schwartz on 12/23/25.
//

import Foundation
import PDFKit
import AppKit

// MARK: - Roster PDF Generator

class RosterPDFGenerator {
    static func generatePDF(
        course: Course,
        students: [Student],
        sections: [Section],
        cohorts: [Cohort],
        examSlots: [ExamSlot],
        options: RosterExportOptions
    ) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Clementime",
            kCGPDFContextAuthor: "Clementime Roster Export",
            kCGPDFContextTitle: "\(course.name) - Student Roster"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { (context) in
            context.beginPage()

            let margin: CGFloat = 72
            var yPosition: CGFloat = pageHeight - margin // Start from top

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 24),
                .foregroundColor: NSColor.black
            ]
            let title = "\(course.name) - Student Roster"
            let titleSize = title.size(withAttributes: titleAttributes)
            yPosition -= titleSize.height
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition -= 40

            // Subtitle
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14),
                .foregroundColor: NSColor.darkGray
            ]
            let subtitle = "Generated on \(Date().formatted(date: .long, time: .shortened))"
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            yPosition -= subtitleSize.height
            subtitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: subtitleAttributes)
            yPosition -= 30

            // Filter and sort students
            let filteredStudents = students.filter { options.shouldInclude($0, cohorts: cohorts) }

            // Sort students using the sortedStudents method
            let sortedStudents = options.sortedStudents(filteredStudents)

            // Render students
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]

            for student in sortedStudents {
                if yPosition < margin + 20 {
                    context.beginPage()
                    yPosition = pageHeight - margin
                }

                var text = student.fullName

                if options.includeEmail {
                    text += " - \(student.email)"
                }

                if options.includeSection, let section = sections.first(where: { $0.id == student.sectionId }) {
                    text += " (\(section.name))"
                }

                if options.includeCohort, let cohort = cohorts.first(where: { $0.id == student.cohortId }) {
                    text += " [\(cohort.name)]"
                }

                if options.includeExamSlot, let slot = examSlots.first(where: { $0.studentId == student.id }) {
                    text += " - Exam: \(slot.startTime.formatted(date: .abbreviated, time: .shortened))"
                }

                let textSize = text.size(withAttributes: textAttributes)
                yPosition -= textSize.height
                text.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: textAttributes)
                yPosition -= 20
            }
        }

        return data.isEmpty ? nil : data
    }
}

// MARK: - Schedule PDF Generator

class SchedulePDFGenerator {

    // MARK: - Bulk Export by Section

    func generateSectionPDFs(
        course: Course,
        examNumber: Int,
        slots: [ExamSlot],
        students: [Student],
        sections: [Section],
        baseOptions: ScheduleExportOptions = ScheduleExportOptions()
    ) -> [(section: Section, pdf: PDFDocument)] {
        var results: [(Section, PDFDocument)] = []

        for section in sections {
            // Create options for this specific section
            var sectionOptions = baseOptions
            sectionOptions.filterBySection = section.id

            // Generate PDF for this section (even if empty - will show a message)
            if let pdf = generateSchedulePDF(
                course: course,
                examNumber: examNumber,
                slots: slots,
                students: students,
                sections: [section],
                options: sectionOptions,
                allowEmpty: true
            ) {
                results.append((section, pdf))
            }
        }

        return results
    }

    func generateSchedulePDF(
        course: Course,
        examNumber: Int,
        slots: [ExamSlot],
        students: [Student],
        sections: [Section],
        options: ScheduleExportOptions = ScheduleExportOptions(),
        allowEmpty: Bool = false
    ) -> PDFDocument? {
        // Filter slots based on options
        let filteredSlots = slots.filter { options.shouldInclude($0) }

        // Create PDF context
        let pdfMetadata = [
            kCGPDFContextTitle: "Exam Schedule - \(course.name)",
            kCGPDFContextAuthor: "Clementime",
            kCGPDFContextCreator: "Clementime"
        ]

        let format = NSMutableData()
        guard let consumer = CGDataConsumer(data: format as CFMutableData) else { return nil }

        var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter size

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, pdfMetadata as CFDictionary) else {
            return nil
        }

        // Set up NSGraphicsContext for text drawing
        let graphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
        NSGraphicsContext.current = graphicsContext

        // Draw content with pagination support
        drawPDFContentWithPagination(
            pdfContext: pdfContext,
            mediaBox: mediaBox,
            course: course,
            examNumber: examNumber,
            slots: filteredSlots,
            students: students,
            sections: sections,
            options: options,
            allowEmpty: allowEmpty
        )

        pdfContext.closePDF()

        // Clean up graphics context
        NSGraphicsContext.current = nil

        // Create PDFDocument from data
        return PDFDocument(data: format as Data)
    }

    // MARK: - Pagination Support

    private func drawPDFContentWithPagination(
        pdfContext: CGContext,
        mediaBox: CGRect,
        course: Course,
        examNumber: Int,
        slots: [ExamSlot],
        students: [Student],
        sections: [Section],
        options: ScheduleExportOptions,
        allowEmpty: Bool = false
    ) {
        let margin: CGFloat = 30
        let bottomMargin: CGFloat = 50

        // Start first page
        pdfContext.beginPDFPage(nil)
        var yPosition: CGFloat = mediaBox.height - margin
        var currentPage = 1

        // Draw logo and header (if enabled) - only on first page
        if options.includeLogo {
            yPosition = drawHeader(in: pdfContext, at: yPosition, width: mediaBox.width - (margin * 2), course: course, layoutStyle: options.layoutStyle)
            yPosition -= (options.layoutStyle == .compact ? 20 : 30)
        }

        // Draw exam title - only on first page
        yPosition = drawExamTitle(in: pdfContext, at: yPosition, examNumber: examNumber, course: course, layoutStyle: options.layoutStyle)
        yPosition -= (options.layoutStyle == .compact ? 10 : 20)

        // Draw section title if filtering by a specific section - only on first page
        if let sectionId = options.filterBySection, let section = sections.first(where: { $0.id == sectionId }) {
            yPosition = drawSectionTitle(in: pdfContext, at: yPosition, section: section, layoutStyle: options.layoutStyle)
            yPosition -= (options.layoutStyle == .compact ? 15 : 25)
        }

        // Check if there are any slots to display
        if slots.isEmpty && allowEmpty {
            // Draw empty state message
            yPosition = drawEmptyStateMessage(
                in: pdfContext,
                at: yPosition,
                width: mediaBox.width - (margin * 2),
                margin: margin,
                section: options.filterBySection != nil ? sections.first : nil
            )
        } else {
            // Draw metadata (if enabled) - only on first page
            if options.includeStatistics {
                yPosition = drawMetadata(in: pdfContext, at: yPosition, width: mediaBox.width - (margin * 2), slots: slots, options: options)
                yPosition -= (options.layoutStyle == .compact ? 20 : 30)
            }

            // Draw schedule table with pagination
            drawScheduleTableWithPagination(
                pdfContext: pdfContext,
                mediaBox: mediaBox,
                startingY: yPosition,
                margin: margin,
                bottomMargin: bottomMargin,
                slots: slots,
                students: students,
                sections: sections,
                options: options,
                currentPage: &currentPage
            )
        }

        // Draw footer on last page
        drawFooter(in: pdfContext, at: 30, width: mediaBox.width - (margin * 2), margin: margin, pageNumber: currentPage)

        pdfContext.endPDFPage()
    }

    private func drawPDFContent(
        in context: CGContext,
        mediaBox: CGRect,
        course: Course,
        examNumber: Int,
        slots: [ExamSlot],
        students: [Student],
        sections: [Section],
        options: ScheduleExportOptions,
        allowEmpty: Bool = false
    ) {
        let margin: CGFloat = 30
        var yPosition: CGFloat = mediaBox.height - margin

        // Draw logo and header (if enabled)
        if options.includeLogo {
            yPosition = drawHeader(in: context, at: yPosition, width: mediaBox.width - (margin * 2), course: course, layoutStyle: options.layoutStyle)
            yPosition -= (options.layoutStyle == .compact ? 20 : 30)
        }

        // Draw exam title
        yPosition = drawExamTitle(in: context, at: yPosition, examNumber: examNumber, course: course, layoutStyle: options.layoutStyle)
        yPosition -= (options.layoutStyle == .compact ? 10 : 20)

        // Draw section title if filtering by a specific section
        if let sectionId = options.filterBySection, let section = sections.first(where: { $0.id == sectionId }) {
            yPosition = drawSectionTitle(in: context, at: yPosition, section: section, layoutStyle: options.layoutStyle)
            yPosition -= (options.layoutStyle == .compact ? 15 : 25)
        }

        // Check if there are any slots to display
        if slots.isEmpty && allowEmpty {
            // Draw empty state message
            yPosition = drawEmptyStateMessage(
                in: context,
                at: yPosition,
                width: mediaBox.width - (margin * 2),
                margin: margin,
                section: options.filterBySection != nil ? sections.first : nil
            )
        } else {
            // Draw metadata (if enabled)
            if options.includeStatistics {
                yPosition = drawMetadata(in: context, at: yPosition, width: mediaBox.width - (margin * 2), slots: slots, options: options)
                yPosition -= (options.layoutStyle == .compact ? 20 : 30)
            }

            // Draw schedule table
            drawScheduleTable(
                in: context,
                at: yPosition,
                width: mediaBox.width - (margin * 2),
                margin: margin,
                slots: slots,
                students: students,
                sections: sections,
                options: options
            )
        }

        // Draw footer
        drawFooter(in: context, at: 30, width: mediaBox.width - (margin * 2), margin: margin)
    }

    // MARK: - Header

    private func drawHeader(in context: CGContext, at yPosition: CGFloat, width: CGFloat, course: Course, layoutStyle: PDFLayoutStyle) -> CGFloat {
        var currentY = yPosition
        let margin: CGFloat = 30

        // Try to load and draw logo
        if let logoPath = Bundle.main.path(forResource: "clementime-app-logo", ofType: "png"),
           let logoImage = NSImage(contentsOfFile: logoPath) {
            let logoSize: CGFloat = 50
            let logoRect = CGRect(x: margin, y: currentY - logoSize, width: logoSize, height: logoSize)

            if let cgImage = logoImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.saveGState()
                context.translateBy(x: 0, y: logoRect.origin.y + logoRect.size.height)
                context.scaleBy(x: 1.0, y: -1.0)
                context.draw(cgImage, in: CGRect(x: logoRect.origin.x, y: 0, width: logoRect.width, height: logoRect.height))

                context.restoreGState()
            }

            // Draw Clementime text next to logo
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            let title = "Clementime"
            let titleSize = title.size(withAttributes: titleAttributes)
            drawText(title, in: context, at: CGPoint(x: margin + logoSize + 20, y: currentY - titleSize.height / 2 - logoSize / 2), withAttributes: titleAttributes)

            currentY -= logoSize
        } else {
            // Just draw text if no logo
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: NSColor.black
            ]
            let title = "Clementime"
            let titleSize = title.size(withAttributes: titleAttributes)
            drawText(title, in: context, at: CGPoint(x: margin, y: currentY - titleSize.height), withAttributes: titleAttributes)
            currentY -= titleSize.height
        }

        currentY -= 15

        // Draw course name
        let courseAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: NSColor.darkGray
        ]
        let courseName = "\(course.name) - \(course.term)"
        let courseSize = courseName.size(withAttributes: courseAttributes)
        drawText(courseName, in: context, at: CGPoint(x: margin, y: currentY - courseSize.height), withAttributes: courseAttributes)
        currentY -= courseSize.height

        currentY -= 10

        // Draw horizontal line
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: margin, y: currentY))
        context.addLine(to: CGPoint(x: margin + width, y: currentY))
        context.strokePath()
        context.restoreGState()

        return currentY
    }

    // MARK: - Empty State

    private func drawEmptyStateMessage(
        in context: CGContext,
        at yPosition: CGFloat,
        width: CGFloat,
        margin: CGFloat,
        section: Section?
    ) -> CGFloat {
        var currentY = yPosition

        // Draw info box background
        let boxHeight: CGFloat = 200
        let boxRect = CGRect(x: margin, y: currentY - boxHeight, width: width, height: boxHeight)

        context.saveGState()
        context.setFillColor(NSColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0).cgColor)
        let path = CGPath(roundedRect: boxRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        // Draw border
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.3).cgColor)
        context.setLineWidth(2)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()

        // Draw icon
        let iconSize: CGFloat = 48
        let iconY = currentY - 80
        let iconAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: iconSize),
            .foregroundColor: NSColor.systemBlue.withAlphaComponent(0.5)
        ]
        let icon = "📋"
        let iconRect = icon.size(withAttributes: iconAttributes)
        drawText(icon, in: context, at: CGPoint(x: margin + (width - iconRect.width) / 2, y: iconY), withAttributes: iconAttributes)

        // Draw title
        currentY -= 120
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: NSColor.darkGray
        ]
        let title = "No Schedule Data Available"
        let titleSize = title.size(withAttributes: titleAttributes)
        drawText(title, in: context, at: CGPoint(x: margin + (width - titleSize.width) / 2, y: currentY), withAttributes: titleAttributes)

        // Draw message
        currentY -= 35
        let messageAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.gray
        ]

        let message: String
        if let section = section {
            message = "No students have been scheduled for \(section.name) yet.\nPlease generate a schedule or add students to this section."
        } else {
            message = "No exam slots have been generated yet.\nPlease configure exam sessions and generate a schedule."
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4

        var messageAttrs = messageAttributes
        messageAttrs[.paragraphStyle] = paragraphStyle

        let messageRect = CGRect(x: margin + 40, y: currentY - 40, width: width - 80, height: 60)
        message.draw(in: messageRect, withAttributes: messageAttrs)

        return currentY - boxHeight
    }

    // MARK: - Exam Title

    private func drawExamTitle(in context: CGContext, at yPosition: CGFloat, examNumber: Int, course: Course, layoutStyle: PDFLayoutStyle) -> CGFloat {
        let margin: CGFloat = 30
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        let title = "Exam \(examNumber) Schedule"
        let titleSize = title.size(withAttributes: titleAttributes)
        drawText(title, in: context, at: CGPoint(x: margin, y: yPosition - titleSize.height), withAttributes: titleAttributes)

        return yPosition - titleSize.height
    }

    private func drawSectionTitle(in context: CGContext, at yPosition: CGFloat, section: Section, layoutStyle: PDFLayoutStyle) -> CGFloat {
        var currentY = yPosition
        let margin: CGFloat = 30

        // Section name in large, bold text
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .bold),
            .foregroundColor: NSColor.systemBlue
        ]
        let title = "Section: \(section.name)"
        let titleSize = title.size(withAttributes: titleAttributes)
        drawText(title, in: context, at: CGPoint(x: margin, y: currentY - titleSize.height), withAttributes: titleAttributes)
        currentY -= titleSize.height + 5

        // Instructions for students
        let instructionsAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.darkGray
        ]
        let instructions = "Find your name below to see your scheduled exam time"
        let instructionsSize = instructions.size(withAttributes: instructionsAttributes)
        drawText(instructions, in: context, at: CGPoint(x: margin, y: currentY - instructionsSize.height), withAttributes: instructionsAttributes)
        currentY -= instructionsSize.height

        return currentY
    }

    // MARK: - Metadata

    private func drawMetadata(in context: CGContext, at yPosition: CGFloat, width: CGFloat, slots: [ExamSlot], options: ScheduleExportOptions) -> CGFloat {
        var currentY = yPosition
        let margin: CGFloat = 30

        let metadataAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.darkGray
        ]

        // Generated date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let generatedText = "Generated: \(dateFormatter.string(from: Date()))"
        let generatedSize = generatedText.size(withAttributes: metadataAttributes)
        drawText(generatedText, in: context, at: CGPoint(x: margin, y: currentY - generatedSize.height), withAttributes: metadataAttributes)
        currentY -= generatedSize.height + 5

        // Stats
        let scheduledCount = slots.filter { $0.isScheduled }.count
        let totalCount = slots.count
        let statsText = "Total Slots: \(totalCount) | Scheduled: \(scheduledCount) | Unscheduled: \(totalCount - scheduledCount)"
        let statsSize = statsText.size(withAttributes: metadataAttributes)
        drawText(statsText, in: context, at: CGPoint(x: margin, y: currentY - statsSize.height), withAttributes: metadataAttributes)
        currentY -= statsSize.height

        return currentY
    }

    // MARK: - Schedule Table

    private func drawScheduleTable(
        in context: CGContext,
        at yPosition: CGFloat,
        width: CGFloat,
        margin: CGFloat,
        slots: [ExamSlot],
        students: [Student],
        sections: [Section],
        options: ScheduleExportOptions
    ) {
        var currentY = yPosition

        // Table configuration - adjust for layout style
        let rowHeight: CGFloat = options.layoutStyle == .compact ? 35 : 45

        // Calculate column widths to fit within page width
        let columnWidths: [CGFloat] = options.includeNotes
            ? [width * 0.20, width * 0.35, width * 0.20, width * 0.15, width * 0.10] // Date/Time, Student, Section, Status, Notes
            : [width * 0.22, width * 0.42, width * 0.20, width * 0.16] // Date/Time, Student, Section, Status (no notes)

        // Sort slots by scheduled date and time
        let sortedSlots = slots.sorted { slot1, slot2 in
            if slot1.isScheduled && slot2.isScheduled {
                if slot1.date == slot2.date {
                    return slot1.startTime < slot2.startTime
                }
                return slot1.date < slot2.date
            }
            return slot1.isScheduled && !slot2.isScheduled
        }

        // Draw table rows
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.black
        ]

        for (index, slot) in sortedSlots.enumerated() {
            // Calculate row positions
            let rowBottom = currentY - rowHeight

            // Alternate row background
            if index % 2 == 0 {
                context.saveGState()
                context.setFillColor(NSColor(white: 0.95, alpha: 1.0).cgColor)
                context.fill(CGRect(x: margin, y: rowBottom, width: width, height: rowHeight))
                context.restoreGState()
            }

            var xPosition = margin + 5

            // Date/Time column
            let dateTimeText = slot.isScheduled ? "\(slot.formattedDate)\n\(slot.formattedTimeRange)" : "Not Scheduled"
            drawCell(text: dateTimeText, in: context, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[0] - 10, height: rowHeight, attributes: cellAttributes)
            xPosition += columnWidths[0]

            // Student column
            if let student = students.first(where: { $0.id == slot.studentId }) {
                drawCell(text: student.fullName, in: context, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[1] - 10, height: rowHeight, attributes: cellAttributes)
            } else {
                drawCell(text: "-", in: context, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[1] - 10, height: rowHeight, attributes: cellAttributes)
            }
            xPosition += columnWidths[1]

            // Section column
            if let section = sections.first(where: { $0.id == slot.sectionId }) {
                drawCell(text: section.name, in: context, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[2] - 10, height: rowHeight, attributes: cellAttributes)
            } else {
                drawCell(text: "-", in: context, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[2] - 10, height: rowHeight, attributes: cellAttributes)
            }
            xPosition += columnWidths[2]

            // Status column
            let statusText = slot.isScheduled ? "✓ Scheduled" : "○ Pending"
            let statusColor = slot.isScheduled ? NSColor.systemGreen : NSColor.systemOrange
            let statusAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: statusColor
            ]
            drawCell(text: statusText, in: context, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[3] - 10, height: rowHeight, attributes: statusAttributes)
            xPosition += columnWidths[3]

            // Notes column (if enabled)
            if options.includeNotes {
                let notesText = slot.isLocked ? "🔒" : ""
                drawCell(text: notesText, in: context, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[4] - 10, height: rowHeight, attributes: cellAttributes)
            }

            // Draw row border
            context.saveGState()
            context.setStrokeColor(NSColor.lightGray.cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: margin, y: rowBottom))
            context.addLine(to: CGPoint(x: margin + width, y: rowBottom))
            context.strokePath()
            context.restoreGState()

            currentY -= rowHeight
        }
    }

    // MARK: - Schedule Table with Pagination

    private func drawScheduleTableWithPagination(
        pdfContext: CGContext,
        mediaBox: CGRect,
        startingY: CGFloat,
        margin: CGFloat,
        bottomMargin: CGFloat,
        slots: [ExamSlot],
        students: [Student],
        sections: [Section],
        options: ScheduleExportOptions,
        currentPage: inout Int
    ) {
        var currentY = startingY

        // Table configuration - adjust for layout style
        let rowHeight: CGFloat = options.layoutStyle == .compact ? 35 : 45
        let headerHeight: CGFloat = options.layoutStyle == .compact ? 30 : 40

        // Calculate column widths to fit within page width
        let availableWidth = mediaBox.width - (margin * 2)
        let columnWidths: [CGFloat] = options.includeNotes
            ? [availableWidth * 0.20, availableWidth * 0.35, availableWidth * 0.20, availableWidth * 0.15, availableWidth * 0.10] // Date/Time, Student, Section, Status, Notes
            : [availableWidth * 0.22, availableWidth * 0.42, availableWidth * 0.20, availableWidth * 0.16] // Date/Time, Student, Section, Status (no notes)

        // Sort slots by scheduled date and time
        let sortedSlots = slots.sorted { slot1, slot2 in
            if slot1.isScheduled && slot2.isScheduled {
                if slot1.date == slot2.date {
                    return slot1.startTime < slot2.startTime
                }
                return slot1.date < slot2.date
            }
            return slot1.isScheduled && !slot2.isScheduled
        }

        // Draw table header on first page
        currentY = drawTableHeader(in: pdfContext, at: currentY, margin: margin, columnWidths: columnWidths, height: headerHeight, includeNotes: options.includeNotes)

        // Draw table rows
        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.black
        ]

        for (index, slot) in sortedSlots.enumerated() {
            // Check if we need a new page (need space for row + footer)
            if currentY - rowHeight < bottomMargin + 30 {
                // Draw footer on current page before starting new page
                drawFooter(in: pdfContext, at: 30, width: mediaBox.width - (margin * 2), margin: margin, pageNumber: currentPage)

                // Start new page
                pdfContext.endPDFPage()
                pdfContext.beginPDFPage(nil)
                currentPage += 1

                // Reset Y position for new page
                currentY = mediaBox.height - margin

                // Redraw table header on new page
                currentY = drawTableHeader(in: pdfContext, at: currentY, margin: margin, columnWidths: columnWidths, height: headerHeight, includeNotes: options.includeNotes)
            }

            // Calculate row positions
            let rowBottom = currentY - rowHeight
            let width = mediaBox.width - (margin * 2)

            // Alternate row background
            if index % 2 == 0 {
                pdfContext.saveGState()
                pdfContext.setFillColor(NSColor(white: 0.95, alpha: 1.0).cgColor)
                pdfContext.fill(CGRect(x: margin, y: rowBottom, width: width, height: rowHeight))
                pdfContext.restoreGState()
            }

            var xPosition = margin + 5

            // Date/Time column
            let dateTimeText = slot.isScheduled ? "\(slot.formattedDate)\n\(slot.formattedTimeRange)" : "Not Scheduled"
            drawCell(text: dateTimeText, in: pdfContext, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[0] - 10, height: rowHeight, attributes: cellAttributes)
            xPosition += columnWidths[0]

            // Student column
            if let student = students.first(where: { $0.id == slot.studentId }) {
                drawCell(text: student.fullName, in: pdfContext, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[1] - 10, height: rowHeight, attributes: cellAttributes)
            } else {
                drawCell(text: "-", in: pdfContext, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[1] - 10, height: rowHeight, attributes: cellAttributes)
            }
            xPosition += columnWidths[1]

            // Section column
            if let section = sections.first(where: { $0.id == slot.sectionId }) {
                drawCell(text: section.name, in: pdfContext, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[2] - 10, height: rowHeight, attributes: cellAttributes)
            } else {
                drawCell(text: "-", in: pdfContext, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[2] - 10, height: rowHeight, attributes: cellAttributes)
            }
            xPosition += columnWidths[2]

            // Status column
            let statusText = slot.isScheduled ? "✓ Scheduled" : "○ Pending"
            let statusColor = slot.isScheduled ? NSColor.systemGreen : NSColor.systemOrange
            let statusAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: statusColor
            ]
            drawCell(text: statusText, in: pdfContext, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[3] - 10, height: rowHeight, attributes: statusAttributes)
            xPosition += columnWidths[3]

            // Notes column (if enabled)
            if options.includeNotes {
                let notesText = slot.isLocked ? "🔒" : ""
                drawCell(text: notesText, in: pdfContext, at: CGPoint(x: xPosition, y: rowBottom), width: columnWidths[4] - 10, height: rowHeight, attributes: cellAttributes)
            }

            // Draw row border
            pdfContext.saveGState()
            pdfContext.setStrokeColor(NSColor.lightGray.cgColor)
            pdfContext.setLineWidth(0.5)
            pdfContext.move(to: CGPoint(x: margin, y: rowBottom))
            pdfContext.addLine(to: CGPoint(x: margin + width, y: rowBottom))
            pdfContext.strokePath()
            pdfContext.restoreGState()

            currentY -= rowHeight
        }
    }

    private func drawTableHeader(in context: CGContext, at yPosition: CGFloat, margin: CGFloat, columnWidths: [CGFloat], height: CGFloat, includeNotes: Bool = true) -> CGFloat {
        let currentY = yPosition
        let totalWidth = columnWidths.reduce(0, +)

        // Draw header background
        context.saveGState()
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fill(CGRect(x: margin, y: currentY - height, width: totalWidth, height: height))
        context.restoreGState()

        // Draw header text with visible white color
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.clear
        ]

        let headers = includeNotes ? ["Date & Time", "Student", "Section", "Status", "Notes"] : ["Date & Time", "Student", "Section", "Status"]
        var xPosition = margin + 5

        for (index, header) in headers.enumerated() {
            if index < columnWidths.count {
                let textPoint = CGPoint(x: xPosition, y: currentY - height + 10)
                drawText(header, in: context, at: textPoint, withAttributes: headerAttributes)
                xPosition += columnWidths[index]
            }
        }

        return currentY - height
    }

    private func drawCell(text: String, in context: CGContext, at point: CGPoint, width: CGFloat, height: CGFloat = 50, attributes: [NSAttributedString.Key: Any]) {
        guard !text.isEmpty else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail

        var finalAttributes = attributes
        finalAttributes[.paragraphStyle] = paragraphStyle

        // Calculate text size to determine vertical centering offset
        let textSize = text.boundingRect(
            with: CGSize(width: max(1, width), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: finalAttributes
        )

        // Calculate vertical offset to center the text
        let yOffset = (height - textSize.height) / 2

        // Create bounding rect with full height and centered y position
        let boundingRect = CGRect(
            x: point.x,
            y: point.y + yOffset,
            width: max(1, width),
            height: textSize.height
        )

        // Draw text directly - NSGraphicsContext handles the coordinate system
        text.draw(in: boundingRect, withAttributes: finalAttributes)
    }

    /// Helper method to draw text at a point with proper coordinate system handling
    private func drawText(_ text: String, in context: CGContext, at point: CGPoint, withAttributes attributes: [NSAttributedString.Key: Any]) {
        guard !text.isEmpty else { return }

        // Draw text directly - NSGraphicsContext handles the coordinate system
        text.draw(at: point, withAttributes: attributes)
    }

    // MARK: - Summary View

    private func drawSummaryView(
        in context: CGContext,
        at yPosition: CGFloat,
        width: CGFloat,
        margin: CGFloat,
        slots: [ExamSlot],
        students: [Student],
        sections: [Section]
    ) {
        var currentY = yPosition

        // Group slots by section
        let slotsBySection = Dictionary(grouping: slots) { $0.sectionId }

        // Summary card style
        let cardWidth: CGFloat = (width - 40) / 2
        let cardHeight: CGFloat = 120
        var xPosition = margin

        // Overall statistics card
        drawSummaryCard(
            in: context,
            at: CGPoint(x: xPosition, y: currentY - cardHeight),
            width: cardWidth,
            height: cardHeight,
            title: "Overall Statistics",
            stats: [
                ("Total Slots", "\(slots.count)"),
                ("Scheduled", "\(slots.filter { $0.isScheduled }.count)"),
                ("Unscheduled", "\(slots.filter { !$0.isScheduled }.count)"),
                ("Locked", "\(slots.filter { $0.isLocked }.count)")
            ]
        )

        xPosition += cardWidth + 20

        // By section card
        drawSummaryCard(
            in: context,
            at: CGPoint(x: xPosition, y: currentY - cardHeight),
            width: cardWidth,
            height: cardHeight,
            title: "By Section",
            stats: slotsBySection.map { sectionId, sectionSlots in
                let sectionName = sections.first(where: { $0.id == sectionId })?.name ?? "Unknown"
                return (sectionName, "\(sectionSlots.count) slots")
            }
        )

        currentY -= cardHeight + 30

        // Date distribution
        let slotsByDate = Dictionary(grouping: slots.filter { $0.isScheduled }) { slot -> String in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: slot.date)
        }

        if !slotsByDate.isEmpty {
            drawSummaryCard(
                in: context,
                at: CGPoint(x: margin, y: currentY - cardHeight),
                width: width,
                height: cardHeight,
                title: "Schedule Distribution",
                stats: slotsByDate.sorted { $0.key < $1.key }.map { date, dateSlots in
                    (date, "\(dateSlots.count) exams")
                }
            )
        }
    }

    private func drawSummaryCard(
        in context: CGContext,
        at origin: CGPoint,
        width: CGFloat,
        height: CGFloat,
        title: String,
        stats: [(String, String)]
    ) {
        // Draw card background
        context.saveGState()
        context.setFillColor(NSColor(white: 0.95, alpha: 1.0).cgColor)
        let cardRect = CGRect(x: origin.x, y: origin.y, width: width, height: height)
        let path = CGPath(roundedRect: cardRect, cornerWidth: 8, cornerHeight: 8, transform: nil)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        // Draw border
        context.saveGState()
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()

        // Draw title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.black
        ]
        drawText(title, in: context, at: CGPoint(x: origin.x + 15, y: origin.y + height - 30), withAttributes: titleAttributes)

        // Draw stats
        let statsAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.darkGray
        ]

        var yPos = origin.y + height - 55
        for (label, value) in stats.prefix(4) {
            let statText = "\(label): \(value)"
            drawText(statText, in: context, at: CGPoint(x: origin.x + 15, y: yPos), withAttributes: statsAttributes)
            yPos -= 18
        }
    }

    // MARK: - Footer

    private func drawFooter(in context: CGContext, at yPosition: CGFloat, width: CGFloat, margin: CGFloat, pageNumber: Int? = nil) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.gray
        ]

        let centerText = "Generated by Clementime • Oral Examination Scheduling System"
        let centerTextSize = centerText.size(withAttributes: footerAttributes)
        let centerX = margin + (width - centerTextSize.width) / 2
        drawText(centerText, in: context, at: CGPoint(x: centerX, y: yPosition), withAttributes: footerAttributes)

        // Draw page number on the right if provided
        if let pageNumber = pageNumber {
            let pageText = "Page \(pageNumber)"
            let pageTextSize = pageText.size(withAttributes: footerAttributes)
            let pageX = margin + width - pageTextSize.width
            drawText(pageText, in: context, at: CGPoint(x: pageX, y: yPosition), withAttributes: footerAttributes)
        }

        // Draw horizontal line above footer
        context.saveGState()
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: margin, y: yPosition + centerTextSize.height + 5))
        context.addLine(to: CGPoint(x: margin + width, y: yPosition + centerTextSize.height + 5))
        context.strokePath()
        context.restoreGState()
    }
}

// MARK: - TA List PDF Generator

class TAListPDFGenerator {

    func generateTAListPDF(
        course: Course,
        taUsers: [TAUser],
        options: TAListExportOptions = TAListExportOptions()
    ) -> PDFDocument? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Clementime",
            kCGPDFContextAuthor: "Clementime TA Export",
            kCGPDFContextTitle: "\(course.name) - TA List"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { (context) in
            context.beginPage()

            let margin: CGFloat = 72
            var yPos: CGFloat = margin

            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: 24),
                .foregroundColor: NSColor.black
            ]
            let title = "\(course.name) - Teaching Staff"
            title.draw(at: CGPoint(x: margin, y: yPos), withAttributes: titleAttributes)
            yPos += 40

            // Filter and sort TAs
            let filteredTAs = taUsers.filter { options.shouldInclude($0) }
            let sortedTAs = options.sortedTAUsers(filteredTAs)

            // TA list
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]

            for ta in sortedTAs {
                if yPos > pageHeight - margin - 20 {
                    context.beginPage()
                    yPos = margin
                }

                var text = "\(ta.fullName) - \(ta.role.displayName)"
                if options.includeContactInfo {
                    text += " (\(ta.email))"
                }
                text.draw(at: CGPoint(x: margin, y: yPos), withAttributes: textAttributes)
                yPos += 20
            }
        }

        return data.isEmpty ? nil : PDFDocument(data: data)
    }
}

// MARK: - UIGraphicsPDFRenderer Compatibility

#if os(macOS)
class UIGraphicsPDFRenderer {
    let bounds: CGRect
    let format: UIGraphicsPDFRendererFormat

    init(bounds: CGRect, format: UIGraphicsPDFRendererFormat) {
        self.bounds = bounds
        self.format = format
    }

    func pdfData(actions: (UIGraphicsPDFRendererContext) -> Void) -> Data {
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
            return Data()
        }

        var mediaBox = bounds

        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, format.documentInfo as CFDictionary?) else {
            return Data()
        }

        let context = UIGraphicsPDFRendererContext(cgContext: pdfContext, bounds: bounds)
        actions(context)
        context.finalize() // End any open pages before closing PDF
        pdfContext.closePDF()

        return data as Data
    }
}

class UIGraphicsPDFRendererFormat {
    var documentInfo: [String: Any] = [:]
}

class UIGraphicsPDFRendererContext {
    let cgContext: CGContext
    let bounds: CGRect
    private var pageStarted = false

    init(cgContext: CGContext, bounds: CGRect) {
        self.cgContext = cgContext
        self.bounds = bounds
    }

    func beginPage() {
        if pageStarted {
            cgContext.endPDFPage()
        }
        cgContext.beginPDFPage(nil)
        pageStarted = true
    }

    func endPage() {
        if pageStarted {
            cgContext.endPDFPage()
            pageStarted = false
        }
    }

    fileprivate func finalize() {
        if pageStarted {
            cgContext.endPDFPage()
            pageStarted = false
        }
    }
}
#endif
