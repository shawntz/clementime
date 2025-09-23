#!/usr/bin/env tsx

import { google } from 'googleapis';
import { OAuth2Client } from 'google-auth-library';
import * as http from 'http';
import * as url from 'url';
import * as open from 'open';

// OAuth credentials - you'll need to set these up in Google Cloud Console
const CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET;
const REDIRECT_URI = 'http://localhost:3000/auth/google/callback';

async function createSimpleCalendarEvent() {
  if (!CLIENT_ID || !CLIENT_SECRET) {
    console.error('❌ Missing GOOGLE_CLIENT_ID or GOOGLE_CLIENT_SECRET environment variables');
    console.log('\n📋 Setup required:');
    console.log('1. Go to Google Cloud Console (console.cloud.google.com)');
    console.log('2. Enable Calendar API');
    console.log('3. Create OAuth 2.0 credentials');
    console.log('4. Set environment variables:');
    console.log('   export GOOGLE_CLIENT_ID="your-client-id"');
    console.log('   export GOOGLE_CLIENT_SECRET="your-client-secret"');
    return;
  }

  const oauth2Client = new OAuth2Client(CLIENT_ID, CLIENT_SECRET, REDIRECT_URI);

  // Generate the url that will be used for authorization
  const authorizeUrl = oauth2Client.generateAuthUrl({
    access_type: 'offline',
    scope: ['https://www.googleapis.com/auth/calendar'],
    response_type: 'code',
  });

  console.log('🔐 Authorize this app by visiting this url:', authorizeUrl);

  // Open the authorization URL automatically
  try {
    await open(authorizeUrl);
    console.log('📂 Browser opened automatically');
  } catch (err) {
    console.log('⚠️  Please open the URL manually in your browser');
  }

  // Start a server to handle the OAuth callback
  const server = http.createServer(async (req, res) => {
    if (req.url?.includes('/auth/google/callback')) {
      const qs = new url.URL(req.url, 'http://localhost:3000').searchParams;
      const code = qs.get('code');

      if (code) {
        try {
          const { tokens } = await oauth2Client.getToken(code);
          oauth2Client.setCredentials(tokens);

          res.end('✅ Authentication successful! You can close this window.');
          server.close();

          // Now create the calendar event
          await createEvent(oauth2Client);

        } catch (error) {
          console.error('❌ Error retrieving access token:', error);
          res.end('❌ Authentication failed');
          server.close();
        }
      } else {
        res.end('❌ No authorization code received');
        server.close();
      }
    }
  });

  server.listen(3000, () => {
    console.log('🌐 Server listening on port 3000 for OAuth callback...');
  });
}

async function createEvent(auth: OAuth2Client) {
  const calendar = google.calendar({ version: 'v3', auth });

  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(14, 0, 0, 0); // 2:00 PM tomorrow

  const endTime = new Date(tomorrow);
  endTime.setMinutes(endTime.getMinutes() + 30); // 30 minute demo

  const event = {
    summary: '30-Minute Demo - Simple Calendar Test',
    description: `Simple calendar event created with OAuth authentication.

This event was created using basic Google Calendar API without domain delegation.

Time: ${tomorrow.toLocaleString()} - ${endTime.toLocaleString()}`,
    start: {
      dateTime: tomorrow.toISOString(),
      timeZone: 'America/Los_Angeles',
    },
    end: {
      dateTime: endTime.toISOString(),
      timeZone: 'America/Los_Angeles',
    },
    attendees: [
      { email: 'fred@fireflies.ai' }
    ],
    conferenceData: {
      createRequest: {
        requestId: `meet-${Date.now()}`,
        conferenceSolutionKey: {
          type: 'hangoutsMeet'
        }
      }
    },
    reminders: {
      useDefault: false,
      overrides: [
        { method: 'email', minutes: 30 },
        { method: 'popup', minutes: 10 },
      ],
    },
  };

  try {
    console.log('\n📅 Creating calendar event...');

    const response = await calendar.events.insert({
      calendarId: 'primary',
      resource: event,
      conferenceDataVersion: 1,
      sendUpdates: 'all',
    });

    const createdEvent = response.data;

    console.log('\n🎉 SUCCESS! Calendar event created!');
    console.log('=' .repeat(50));
    console.log(`📅 DATE: ${new Date(createdEvent.start!.dateTime!).toLocaleDateString('en-US', {
      weekday: 'long',
      year: 'numeric',
      month: 'long',
      day: 'numeric'
    })}`);
    console.log(`🕐 TIME: ${new Date(createdEvent.start!.dateTime!).toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      timeZoneName: 'short'
    })} - ${new Date(createdEvent.end!.dateTime!).toLocaleTimeString('en-US', {
      hour: 'numeric',
      minute: '2-digit',
      timeZoneName: 'short'
    })}`);
    console.log(`📝 TITLE: ${createdEvent.summary}`);
    console.log(`🆔 EVENT ID: ${createdEvent.id}`);
    console.log(`📎 CALENDAR LINK: ${createdEvent.htmlLink}`);
    if (createdEvent.attendees && createdEvent.attendees.length > 0) {
      console.log(`👥 ATTENDEES: ${createdEvent.attendees.map(a => a.email).join(', ')}`);
    }
    if (createdEvent.conferenceData?.entryPoints) {
      const meetLink = createdEvent.conferenceData.entryPoints.find(ep => ep.entryPointType === 'video');
      if (meetLink) {
        console.log(`📹 GOOGLE MEET: ${meetLink.uri}`);
      }
    }
    console.log('=' .repeat(50));

    console.log('\n✅ Check your Google Calendar - the event should be visible!');

  } catch (error: any) {
    console.error('❌ Failed to create calendar event:', error.message);
  }

  process.exit(0);
}

// Run the script
createSimpleCalendarEvent().catch(console.error);