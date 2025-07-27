import { google } from 'googleapis';
import OpenAI from 'openai';
import { api } from '../../backend/convex/_generated/api.js';

const gmail = google.gmail('v1');
const calendar = google.calendar('v3');

export const gmailWebhookHandler = async (req, res, convex) => {
  try {
    // Verify the push notification
    const message = req.body.message;
    if (!message) {
      return res.status(400).json({ error: 'No message in request body' });
    }

    // Decode the push notification data
    const data = message.data ? JSON.parse(Buffer.from(message.data, 'base64').toString()) : {};
    const historyId = data.historyId;
    const emailAddress = data.emailAddress;

    console.log(`📧 Gmail webhook received for ${emailAddress}, historyId: ${historyId}`);

    // Log the webhook
    await convex.mutation(api.webhooks.logWebhook, {
      source: 'gmail',
      payload: JSON.stringify(req.body),
      status: 'success'
    });

    // Find user by email
    const user = await convex.query(api.users.getUserByEmail, { email: emailAddress });
    if (!user) {
      console.log(`User not found for email: ${emailAddress}`);
      return res.json({ received: true, processed: false, reason: 'User not found' });
    }

    // Get user's Gmail tokens
    const tokens = await convex.query(api.auth.getGmailTokens, { userId: user._id });
    if (!tokens || !tokens.accessToken) {
      console.log(`No valid Gmail tokens for user: ${emailAddress}`);
      return res.json({ received: true, processed: false, reason: 'No valid tokens' });
    }

    // Set up OAuth2 client
    const oauth2Client = new google.auth.OAuth2(
      process.env.GOOGLE_CLIENT_ID,
      process.env.GOOGLE_CLIENT_SECRET,
      process.env.GOOGLE_REDIRECT_URI
    );
    oauth2Client.setCredentials({
      access_token: tokens.accessToken,
      refresh_token: tokens.refreshToken
    });

    // Get recent messages since the last known historyId
    const response = await gmail.users.history.list({
      auth: oauth2Client,
      userId: 'me',
      startHistoryId: historyId
    });

    const history = response.data.history || [];
    console.log(`Found ${history.length} history items to process`);

    // Process each history item
    for (const historyItem of history) {
      if (historyItem.messagesAdded) {
        for (const messageAdded of historyItem.messagesAdded) {
          await processNewMessage(messageAdded.message, user, oauth2Client, convex);
        }
      }
    }

    res.json({ 
      received: true, 
      processed: true, 
      historyItems: history.length,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Gmail webhook processing error:', error);
    
    // Log the error
    try {
      await convex.mutation(api.webhooks.logWebhook, {
        source: 'gmail',
        payload: JSON.stringify(req.body),
        status: 'error',
        errorMessage: error.message
      });
    } catch (logError) {
      console.error('Failed to log webhook error:', logError);
    }

    res.status(500).json({ error: 'Failed to process Gmail webhook' });
  }
};

async function processNewMessage(message, user, oauth2Client, convex) {
  try {
    // Get the full message details
    const messageResponse = await gmail.users.messages.get({
      auth: oauth2Client,
      userId: 'me',
      id: message.id,
      format: 'full'
    });

    const fullMessage = messageResponse.data;
    const headers = fullMessage.payload.headers;

    // Extract message details
    const subject = headers.find(h => h.name === 'Subject')?.value || '';
    const from = headers.find(h => h.name === 'From')?.value || '';
    const to = headers.find(h => h.name === 'To')?.value || '';
    const cc = headers.find(h => h.name === 'Cc')?.value || '';

    // Check if the AI assistant is CC'd
    const aiEmail = user.aiAssistantEmail;
    const isAiCCd = cc.includes(aiEmail) || to.includes(aiEmail);

    if (!isAiCCd) {
      console.log(`AI assistant ${aiEmail} not CC'd in message ${message.id}`);
      return;
    }

    console.log(`🤖 AI assistant ${aiEmail} is CC'd in message: ${subject}`);

    // Extract message body
    const messageBody = extractMessageBody(fullMessage.payload);

    // Extract participants
    const participants = extractEmailAddresses([from, to, cc].join(', '))
      .filter(email => email !== aiEmail && email !== user.email);

    // Check if this thread is already being processed
    const existingThread = await convex.query(api.emails.getThreadByMessageId, { 
      messageId: message.id 
    });

    if (existingThread) {
      console.log(`Thread already exists for message ${message.id}`);
      return;
    }

    // Save thread to database
    const threadId = await convex.mutation(api.emails.createEmailThread, {
      userId: user._id,
      threadId: fullMessage.threadId,
      messageId: message.id,
      subject,
      participants,
      status: 'pending',
      metadata: {
        originalMessage: messageBody,
      }
    });

    // Process with AI
    await processWithAI(threadId, messageBody, subject, participants, user, oauth2Client, convex);

  } catch (error) {
    console.error('Error processing message:', error);
  }
}

async function processWithAI(threadId, messageBody, subject, participants, user, oauth2Client, convex) {
  try {
    // Update status to processing
    await convex.mutation(api.emails.updateThreadStatus, {
      threadId,
      status: 'processing'
    });

    // Initialize OpenAI
    const openai = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY
    });

    // Create AI prompt for scheduling
    const prompt = `
You are ${user.aiAssistantName}, an AI scheduling assistant for ${user.name}. You have been CC'd on an email thread about scheduling a meeting.

Email Subject: ${subject}
Message Content: ${messageBody}
Participants: ${participants.join(', ')}

Your task is to:
1. Analyze if this email is about scheduling a meeting
2. Extract key information: proposed times, duration, location, meeting type
3. Suggest the best available time slot for ${user.name}
4. Draft a professional response

User's preferences:
- Timezone: ${user.preferences?.timezone || 'UTC'}
- Working hours: ${user.preferences?.workingHours?.start || '9:00'} - ${user.preferences?.workingHours?.end || '17:00'}
- Buffer time: ${user.preferences?.bufferTime || 15} minutes
- Max meeting duration: ${user.preferences?.maxMeetingDuration || 60} minutes

Please respond in JSON format:
{
  "isSchedulingRequest": boolean,
  "extractedInfo": {
    "proposedTimes": ["time1", "time2"],
    "duration": number (in minutes),
    "location": "string",
    "meetingType": "string"
  },
  "suggestedTime": "ISO datetime string",
  "response": "Email response text"
}
`;

    const completion = await openai.chat.completions.create({
      model: 'gpt-4',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.7
    });

    const aiResponse = JSON.parse(completion.choices[0].message.content);

    // Update thread with AI response
    await convex.mutation(api.emails.updateThreadWithAI, {
      threadId,
      aiResponse: JSON.stringify(aiResponse),
      status: aiResponse.isSchedulingRequest ? 'scheduled' : 'ignored',
      extractedInfo: aiResponse.extractedInfo
    });

    // If it's a scheduling request, create calendar event and send response
    if (aiResponse.isSchedulingRequest && aiResponse.suggestedTime) {
      await createCalendarEvent(aiResponse, threadId, user, participants, oauth2Client, convex);
      await sendEmailResponse(aiResponse.response, threadId, user, oauth2Client, convex);
    }

    console.log(`✅ Successfully processed message with AI for user ${user.email}`);

  } catch (error) {
    console.error('AI processing error:', error);
    await convex.mutation(api.emails.updateThreadStatus, {
      threadId,
      status: 'failed'
    });
  }
}

async function createCalendarEvent(aiResponse, threadId, user, participants, oauth2Client, convex) {
  try {
    const startTime = new Date(aiResponse.suggestedTime);
    const endTime = new Date(startTime.getTime() + (aiResponse.extractedInfo.duration || 30) * 60000);

    const event = {
      summary: `Meeting scheduled by ${user.aiAssistantName}`,
      description: `Automatically scheduled by ${user.aiAssistantName} AI assistant`,
      start: {
        dateTime: startTime.toISOString(),
        timeZone: user.preferences?.timezone || 'UTC'
      },
      end: {
        dateTime: endTime.toISOString(),
        timeZone: user.preferences?.timezone || 'UTC'
      },
      attendees: [
        { email: user.email },
        ...participants.map(email => ({ email }))
      ],
      location: aiResponse.extractedInfo.location || ''
    };

    const calendarResponse = await calendar.events.insert({
      auth: oauth2Client,
      calendarId: 'primary',
      resource: event
    });

    // Save event to database
    await convex.mutation(api.events.createScheduledEvent, {
      userId: user._id,
      threadId,
      eventId: calendarResponse.data.id,
      title: event.summary,
      startTime: startTime.getTime(),
      endTime: endTime.getTime(),
      attendees: [user.email, ...participants],
      location: event.location,
      description: event.description,
      status: 'confirmed'
    });

    console.log(`📅 Created calendar event: ${calendarResponse.data.id}`);

  } catch (error) {
    console.error('Calendar event creation error:', error);
  }
}

async function sendEmailResponse(responseText, threadId, user, oauth2Client, convex) {
  try {
    // Get original thread details
    const thread = await convex.query(api.emails.getThread, { threadId });
    
    const emailContent = `
To: ${thread.participants.join(', ')}
Subject: Re: ${thread.subject}
From: ${user.aiAssistantEmail}

${responseText}

Best regards,
${user.aiAssistantName}
AI Assistant for ${user.name}
`;

    const encodedMessage = Buffer.from(emailContent).toString('base64url');

    await gmail.users.messages.send({
      auth: oauth2Client,
      userId: 'me',
      resource: {
        raw: encodedMessage
      }
    });

    console.log(`📤 Sent email response for thread ${threadId}`);

  } catch (error) {
    console.error('Email send error:', error);
  }
}

function extractMessageBody(payload) {
  if (payload.body && payload.body.data) {
    return Buffer.from(payload.body.data, 'base64').toString();
  }
  
  if (payload.parts) {
    for (const part of payload.parts) {
      if (part.mimeType === 'text/plain' && part.body.data) {
        return Buffer.from(part.body.data, 'base64').toString();
      }
    }
  }
  
  return '';
}

function extractEmailAddresses(text) {
  const emailRegex = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
  return text.match(emailRegex) || [];
}