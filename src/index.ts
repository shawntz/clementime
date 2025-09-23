#!/usr/bin/env node

import * as dotenv from 'dotenv';
import { Command } from 'commander';
import { loadConfigSync, loadConfig } from './utils/config';
import { SchedulingAlgorithm } from './scheduler/algorithm';
import { OrchestrationService } from './services/orchestration';
import { WebServer } from './web/server';
import { format, addWeeks } from 'date-fns';

dotenv.config({ override: true });

const program = new Command();

program
  .name('clementime')
  .description('Smart scheduling automation platform with Slack and Google Meet integration')
  .version('1.0.0');

program
  .command('generate')
  .description('Generate schedules')
  .option('-w, --weeks <number>', 'Number of weeks to schedule', '4')
  .option('-s, --start-date <date>', 'Start date (YYYY-MM-DD)', format(new Date(), 'yyyy-MM-dd'))
  .option('-c, --config <path>', 'Configuration file path', 'config.yml')
  .action(async (options) => {
    try {
      const config = loadConfigSync(options.config);
      const algorithm = new SchedulingAlgorithm(config);

      const startDate = new Date(options.startDate);
      const weeks = parseInt(options.weeks);

      console.log(`📅 Generating schedules for ${weeks} weeks starting ${format(startDate, 'PPP')}\n`);

      const schedules = algorithm.generateRecurringSchedule(startDate, weeks);

      for (const [weekNum, weekSchedule] of schedules) {
        const weekStart = addWeeks(startDate, weekNum * config.scheduling.schedule_frequency_weeks);
        console.log(`\n📊 Week ${weekNum + 1} (${format(weekStart, 'PPP')}):`);

        for (const [sectionId, slots] of weekSchedule) {
          console.log(`\n  📚 Section ${sectionId}:`);
          slots.forEach(slot => {
            console.log(
              `    ${slot.student.name}: ${format(slot.start_time, 'EEE MMM d, h:mm a')} - ${format(slot.end_time, 'h:mm a')}`
            );
          });
        }
      }

      console.log(`\n✅ Successfully generated schedules for ${weeks} weeks`);
    } catch (error) {
      console.error('❌ Failed to generate schedule:', error);
      process.exit(1);
    }
  });

program
  .command('run')
  .description('Run full automation workflow')
  .option('-w, --weeks <number>', 'Number of weeks to schedule', '4')
  .option('-s, --start-date <date>', 'Start date (YYYY-MM-DD)', format(new Date(), 'yyyy-MM-dd'))
  .option('-c, --config <path>', 'Configuration file path', 'config.yml')
  .option('--dry-run', 'Simulate without creating meetings or sending notifications')
  .action(async (options) => {
    try {
      const config = loadConfigSync(options.config);
      const orchestration = new OrchestrationService(config);

      const startDate = new Date(options.startDate);
      const weeks = parseInt(options.weeks);

      console.log(`🚀 Starting automation workflow for ${weeks} weeks`);

      if (options.dryRun) {
        console.log('🔍 DRY RUN MODE - No actual meetings or notifications will be sent\n');
      }

      await orchestration.runFullWorkflow(startDate, weeks, options.dryRun);

      console.log('\n✅ Automation workflow completed successfully');
    } catch (error) {
      console.error('❌ Automation workflow failed:', error);
      process.exit(1);
    }
  });

program
  .command('notify')
  .description('Send notifications for existing schedules')
  .option('-c, --config <path>', 'Configuration file path', 'config.yml')
  .option('-t, --type <type>', 'Notification type (student|ta|reminder)', 'student')
  .action(async (options) => {
    try {
      loadConfigSync(options.config);

      console.log(`📬 Sending ${options.type} notifications...`);

      // This would typically load schedules from a database or file
      console.log('⚠️ This command requires existing schedule data');
      console.log('💡 Use the web interface or database integration for notification management');
    } catch (error) {
      console.error('❌ Failed to send notifications:', error);
      process.exit(1);
    }
  });

program
  .command('web')
  .description('Start web interface')
  .option('-p, --port <number>', 'Port number')
  .option('-c, --config <path>', 'Configuration file path', 'config.yml')
  .action(async (options) => {
    try {
      // Load basic config first for initialization
      const initialConfig = loadConfigSync(options.config);
      const webServer = new WebServer(initialConfig);

      const port = parseInt(options.port || process.env.PORT || '3000');

      // Start the server which will properly initialize with Cloud Storage
      await webServer.start(port);

      console.log(`🌐 Web interface available at http://localhost:${port}`);
      console.log('Press Ctrl+C to stop the server');
    } catch (error) {
      console.error('❌ Failed to start web server:', error);
      process.exit(1);
    }
  });

program
  .command('auth')
  .description('Authenticate with external services')
  .option('-s, --service <service>', 'Service to authenticate (google|meet|slack)', 'google')
  .action(async (options) => {
    try {
      const config = loadConfigSync();

      switch (options.service) {
        case 'google':
          console.log('🔧 Google authentication is configured via environment variables');
          console.log('📝 Please ensure GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, and GOOGLE_REFRESH_TOKEN are set');
          break;

        case 'meet':
          console.log('🔧 Google Meet authentication is configured via environment variables');
          console.log('📝 Please ensure GOOGLE_MEET_CLIENT_ID, GOOGLE_MEET_CLIENT_SECRET, and GOOGLE_MEET_REFRESH_TOKEN are set');
          break;

        case 'slack':
          console.log('🔧 Slack authentication is configured via environment variables');
          console.log('📝 Please ensure SLACK_BOT_TOKEN, SLACK_APP_TOKEN, and SLACK_SIGNING_SECRET are set');
          break;

        default:
          console.error('❌ Unknown service. Available services: google, meet, slack');
          process.exit(1);
      }
    } catch (error) {
      console.error('❌ Authentication failed:', error);
      process.exit(1);
    }
  });

program
  .command('validate')
  .description('Validate configuration file')
  .option('-c, --config <path>', 'Configuration file path', 'config.yml')
  .option('--check-csv', 'Also validate CSV files', false)
  .option('--skip-missing', 'Skip validation if config file is missing', false)
  .action(async (options) => {
    try {
      // Check if config file exists
      const fs = require('fs');
      if (!fs.existsSync(options.config)) {
        if (options.skipMissing) {
          console.log('⚠️  Configuration file not found, skipping validation (--skip-missing enabled)');
          console.log(`📁 Expected location: ${options.config}`);
          console.log('✅ Validation skipped successfully');
          return;
        } else {
          console.error(`❌ Configuration file not found at: ${options.config}`);
          console.log('💡 Use --skip-missing to skip validation when config is missing');
          process.exit(1);
        }
      }

      const config = loadConfigSync(options.config);
      console.log('✅ Configuration file is valid');
      console.log(`📊 Course: ${config.course.name} (${config.course.term})`);
      console.log(`👥 Students: ${config.course.total_students}`);
      console.log(`📚 Sections: ${config.sections.length}`);
      console.log(`⏱️ Session duration: ${config.scheduling.exam_duration_minutes} minutes`);

      // Check CSV validation if requested
      if (options.checkCsv) {
        console.log('\n📋 Validating CSV files...');
        const { validateCSV } = require('./utils/csv-loader');
        let hasErrors = false;

        for (const section of config.sections) {
          if (section.students_csv) {
            const validation = validateCSV(section.students_csv);
            if (!validation.valid) {
              hasErrors = true;
              console.error(`❌ Section ${section.id} CSV issues:`, validation.errors);
            } else {
              console.log(`✅ Section ${section.id} CSV is valid`);
            }
          }
        }

        if (hasErrors) {
          process.exit(1);
        }
      }

      // Check for environment variables
      console.log('\n🔐 Environment variables:');
      const envVars = [
        'SLACK_BOT_TOKEN',
        'GOOGLE_MEET_CLIENT_ID',
        'GOOGLE_CLIENT_ID'
      ];

      for (const varName of envVars) {
        if (process.env[varName]) {
          console.log(`  ✅ ${varName} is set`);
        } else {
          console.log(`  ⚠️  ${varName} is not set`);
        }
      }
    } catch (error) {
      console.error('❌ Configuration validation failed:', error);
      process.exit(1);
    }
  });

if (require.main === module) {
  program.parse();
}