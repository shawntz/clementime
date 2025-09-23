import { Config } from '../types';
import { DatabaseService } from '../database';
import { loadConfig as loadBaseConfig } from './config';
import { loadStudentsFromCSV } from './csv-loader';
import { cloudStorage } from './cloud-storage';

export class ConfigLoader {
  private db: DatabaseService;

  constructor(db: DatabaseService) {
    this.db = db;
  }

  /**
   * Load config with database overrides for section mappings
   */
  async loadConfig(configPath?: string): Promise<Config> {
    // If using Cloud Storage, download config.yml first
    if (cloudStorage.isCloudStorageEnabled() && !configPath) {
      try {
        console.log('☁️  Loading config.yml from Cloud Storage...');
        const configContent = await cloudStorage.readFile('config.yml');

        // Write to temp location for parsing
        const tempConfigPath = '/tmp/config.yml';
        await cloudStorage.writeFile(tempConfigPath, configContent);
        configPath = tempConfigPath;
      } catch (error) {
        console.warn('⚠️  Could not load config from Cloud Storage, using local or default');
      }
    }

    // Load base config from YAML
    const config = loadBaseConfig(configPath);

    // Handle CSV loading from Cloud Storage for each section
    for (const section of config.sections) {
      // First check for active database mappings (highest priority)
      const activeMapping = this.db.getActiveSectionMapping(section.id);

      if (activeMapping) {
        console.log(`📊 Loading section mapping from database for ${section.id}: ${activeMapping.name}`);

        // Parse CSV content from database
        const students = this.parseCSVContent(activeMapping.csv_content);

        if (students.length > 0) {
          console.log(`  ✅ Loaded ${students.length} students from database mapping`);
          section.students = students;
        } else {
          console.log(`  ⚠️  No valid students found in database mapping, using config.yml`);
        }
      } else if (section.students_csv && cloudStorage.isCloudStorageEnabled()) {
        // Load CSV from Cloud Storage if specified in config
        console.log(`☁️  Loading CSV from Cloud Storage for ${section.id}: ${section.students_csv}`);

        try {
          const csvStudents = await this.loadStudentsFromCloudStorage(section.students_csv);
          if (csvStudents.length > 0) {
            console.log(`  ✅ Loaded ${csvStudents.length} students from Cloud Storage CSV`);
            section.students = csvStudents;
            // Remove the CSV path as it's no longer needed
            delete section.students_csv;
          } else {
            console.log(`  ⚠️  No students found in Cloud Storage CSV, keeping existing config`);
          }
        } catch (error) {
          console.error(`  ❌ Failed to load CSV from Cloud Storage: ${error}`);
          console.log(`  📋 Falling back to config.yml students`);
        }
      } else {
        console.log(`📋 Using config.yml mapping for section ${section.id} (${section.students?.length || 0} students)`);
      }
    }

    return config;
  }

  /**
   * Load students from CSV file in Cloud Storage
   */
  private async loadStudentsFromCloudStorage(csvPath: string): Promise<any[]> {
    try {
      const csvContent = await cloudStorage.readFile(csvPath);
      const csvText = csvContent.toString('utf-8');
      return this.parseCSVContent(csvText);
    } catch (error) {
      console.error(`Failed to load CSV from Cloud Storage: ${csvPath}`, error);
      return [];
    }
  }

  /**
   * Parse CSV content from database
   */
  private parseCSVContent(csvContent: string): any[] {
    const lines = csvContent.split('\n').filter(line => line.trim());
    if (lines.length < 2) return [];

    const headers = lines[0].toLowerCase().split(',').map(h => h.trim());
    const nameIndex = headers.findIndex(h => h === 'name');
    const emailIndex = headers.findIndex(h => h === 'email');
    const slackIdIndex = headers.findIndex(h => h === 'slack_id');

    if (nameIndex === -1 || emailIndex === -1) {
      console.error('CSV must have "name" and "email" columns');
      return [];
    }

    const students = [];
    for (let i = 1; i < lines.length; i++) {
      const values = lines[i].split(',').map(v => v.trim());

      if (values[nameIndex] && values[emailIndex]) {
        students.push({
          name: values[nameIndex],
          email: values[emailIndex],
          slack_id: slackIdIndex !== -1 ? values[slackIdIndex] : undefined
        });
      }
    }

    return students;
  }

  /**
   * Load and activate a section mapping from database
   */
  activateSectionMapping(mappingId: number, sectionId: string): void {
    this.db.setActiveSectionMapping(mappingId, sectionId);
    console.log(`✅ Activated mapping ${mappingId} for section ${sectionId}`);
  }

  /**
   * Get summary of current config source
   */
  async getConfigSummary(): Promise<any> {
    const config = await this.loadConfig();
    const summary = {
      sections: [] as any[]
    };

    for (const section of config.sections) {
      const activeMapping = this.db.getActiveSectionMapping(section.id);
      summary.sections.push({
        id: section.id,
        name: section.ta_name,
        studentCount: section.students.length,
        source: activeMapping ? `Database: ${activeMapping.name}` : 'config.yml',
        mappingId: activeMapping?.id || null
      });
    }

    return summary;
  }
}