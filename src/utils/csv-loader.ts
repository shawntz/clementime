import * as fs from 'fs';
import * as path from 'path';
import { parse } from 'csv-parse/sync';
import { Student } from '../types';
import { cloudStorage } from './cloud-storage';

export interface CSVStudent {
  name: string;
  email: string;
  slack_id?: string;
  [key: string]: any; // Allow additional fields
}

/**
 * Load students from a CSV file
 * Expected CSV format: name, email, slack_id (optional)
 */
export function loadStudentsFromCSV(csvPath: string): Student[] {
  try {
    let fileContent: string;
    console.log(`🔍 Loading CSV: ${csvPath}`);

    // If Cloud Storage is enabled, try to read from there first
    if (cloudStorage.isCloudStorageEnabled()) {
      try {
        // Try to read synchronously from cloud storage
        const buffer = cloudStorage.readFileSync(csvPath);
        fileContent = buffer.toString('utf-8');
        console.log(`✅ Successfully loaded CSV from Cloud Storage: ${csvPath}`);
      } catch (cloudError) {
        console.warn(`⚠️  Could not load CSV from Cloud Storage: ${csvPath}`, cloudError);
        return [];
      }
    } else {
      // Local filesystem only
      const resolvedPath = path.isAbsolute(csvPath)
        ? csvPath
        : path.resolve(process.cwd(), csvPath);

      if (!fs.existsSync(resolvedPath)) {
        console.warn(`CSV file not found: ${resolvedPath}`);
        return [];
      }

      fileContent = fs.readFileSync(resolvedPath, 'utf-8');
      console.log(`📁 Loaded CSV from local filesystem: ${resolvedPath}`);
    }

    // Parse CSV with headers
    const records = parse(fileContent, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
      // Handle common CSV formats
      bom: true,
      // Allow for flexible column naming
      cast: (value, context) => {
        // Trim whitespace from all values
        return typeof value === 'string' ? value.trim() : value;
      }
    }) as CSVStudent[];

    // Map CSV records to Student objects
    return records.map(record => {
      // Handle various column name variations
      const name = record.name || record.Name || record.student_name || record['Student Name'] || '';
      const email = record.email || record.Email || record.student_email || record['Student Email'] || '';
      const slack_id = record.slack_id || record['Slack ID'] || record.slack || record.Slack || undefined;

      return {
        name,
        email,
        slack_id
      };
    }).filter(student => student.name && student.email); // Filter out invalid entries

  } catch (error) {
    console.error(`Error loading CSV file ${csvPath}:`, error);
    return [];
  }
}

/**
 * Create a sample CSV file for reference
 */
export function createSampleCSV(outputPath: string, sectionId: string): void {
  const sampleContent = `name,email,slack_id
John Doe,john.doe@university.edu,U12345678
Jane Smith,jane.smith@university.edu,U23456789
Bob Johnson,bob.johnson@university.edu,U34567890
Alice Brown,alice.brown@university.edu,U45678901
Charlie Wilson,charlie.wilson@university.edu,U56789012`;

  const filename = `students_${sectionId}_sample.csv`;
  const filepath = path.join(outputPath, filename);

  fs.writeFileSync(filepath, sampleContent, 'utf-8');
  console.log(`Sample CSV created: ${filepath}`);
}

/**
 * Validate CSV format
 */
export function validateCSV(csvPath: string): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  try {
    const resolvedPath = path.isAbsolute(csvPath)
      ? csvPath
      : path.resolve(process.cwd(), csvPath);

    if (!fs.existsSync(resolvedPath)) {
      return { valid: false, errors: [`File not found: ${csvPath}`] };
    }

    const fileContent = fs.readFileSync(resolvedPath, 'utf-8');
    const records = parse(fileContent, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
      bom: true
    }) as CSVStudent[];

    if (records.length === 0) {
      errors.push('CSV file is empty');
    }

    // Check for required columns
    if (records.length > 0) {
      const firstRecord = records[0];
      const hasName = 'name' in firstRecord || 'Name' in firstRecord ||
                      'student_name' in firstRecord || 'Student Name' in firstRecord;
      const hasEmail = 'email' in firstRecord || 'Email' in firstRecord ||
                       'student_email' in firstRecord || 'Student Email' in firstRecord;

      if (!hasName) {
        errors.push('Missing required column: name (or Name, student_name, Student Name)');
      }
      if (!hasEmail) {
        errors.push('Missing required column: email (or Email, student_email, Student Email)');
      }
    }

    // Check for duplicate emails
    const emails = new Set<string>();
    const duplicates = new Set<string>();

    records.forEach((record, index) => {
      const email = record.email || record.Email || record.student_email || record['Student Email'] || '';
      if (email) {
        if (emails.has(email.toLowerCase())) {
          duplicates.add(email);
        }
        emails.add(email.toLowerCase());
      }
    });

    if (duplicates.size > 0) {
      errors.push(`Duplicate emails found: ${Array.from(duplicates).join(', ')}`);
    }

  } catch (error) {
    errors.push(`Failed to parse CSV: ${error}`);
  }

  return {
    valid: errors.length === 0,
    errors
  };
}