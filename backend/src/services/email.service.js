/**
 * ZeParty Central Email & Notification Dispatcher
 * Handles transactional emails (Host verification, Security, System notices)
 */

import prisma from '../config/database.js';

export async function sendEmail({ to, subject, html, text }) {
  try {
    if (!to || !to.includes('@')) {
      console.warn('[EmailService] Invalid recipient email address:', to);
      return { success: false, reason: 'INVALID_EMAIL' };
    }

    // If SMTP environment variables are configured, attempt real dispatch.
    // Otherwise, simulate and log the transaction safely.
    const smtpHost = process.env.SMTP_HOST;
    const smtpUser = process.env.SMTP_USER;
    const smtpPass = process.env.SMTP_PASS;

    if (smtpHost && smtpUser && smtpPass) {
      // Dynamic import to avoid hard crash if nodemailer is not installed
      try {
        const nodemailer = await import('nodemailer');
        const transporter = nodemailer.default.createTransport({
          host: smtpHost,
          port: Number(process.env.SMTP_PORT) || 587,
          secure: process.env.SMTP_SECURE === 'true',
          auth: {
            user: smtpUser,
            pass: smtpPass,
          },
        });

        const info = await transporter.sendMail({
          from: process.env.EMAIL_FROM || '"ZeParty Live" <noreply@zeparty.com>',
          to,
          subject,
          text: text || subject,
          html,
        });

        console.log(`[EmailService] Email successfully delivered to ${to} (MessageID: ${info.messageId})`);
        return { success: true, messageId: info.messageId };
      } catch (nodemailerErr) {
        console.warn('[EmailService] SMTP dispatch failed, fallback to system log:', nodemailerErr.message);
      }
    }

    // Graceful simulated delivery (logged for development / audit)
    console.log(`\n================== [EMAIL DISPATCHED] ==================`);
    console.log(`To: ${to}`);
    console.log(`Subject: ${subject}`);
    console.log(`Content:\n${text || 'HTML Template Rendered'}`);
    console.log(`========================================================\n`);

    return { success: true, simulated: true };
  } catch (err) {
    console.error('[EmailService] Unhandled email error:', err);
    return { success: false, error: err.message };
  }
}

/**
 * Sends Host Application Approval Email
 */
export async function sendHostApprovalEmail({ userEmail, username, hostType }) {
  if (!userEmail) return;

  const readableType =
    hostType === 'BOTH'
      ? 'Live Video & Social Audio Host'
      : hostType === 'AUDIO_HOST'
      ? 'Social Audio Party Host'
      : 'Live Video Host';

  const subject = '🎉 Congratulations! Your ZeParty Host Application is Approved';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0f0d1b; color: #ffffff; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: #1a162b; border: 1px solid #382d5a; border-radius: 16px; padding: 32px; }
        .header { text-align: center; border-bottom: 1px solid #382d5a; padding-bottom: 20px; margin-bottom: 24px; }
        .logo { font-size: 26px; font-weight: bold; background: linear-gradient(135deg, #a855f7, #ec4899); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .badge { display: inline-block; background: #22c55e22; border: 1px solid #22c55e; color: #4ade80; padding: 6px 16px; border-radius: 20px; font-size: 13px; font-weight: bold; margin: 16px 0; }
        .content { font-size: 15px; line-height: 1.6; color: #cbd5e1; }
        .highlight-box { background: #241d3d; border-radius: 12px; padding: 20px; margin: 20px 0; border-left: 4px solid #a855f7; }
        .cta-btn { display: inline-block; background: linear-gradient(135deg, #9333ea, #c026d3); color: #ffffff; text-decoration: none; padding: 14px 28px; border-radius: 12px; font-weight: bold; margin-top: 20px; }
        .footer { margin-top: 32px; font-size: 12px; color: #64748b; text-align: center; border-top: 1px solid #2a2245; padding-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">ZeParty Live</div>
          <div class="badge">APPLICATION APPROVED</div>
          <h2>Welcome to the Host Creator Program!</h2>
        </div>
        <div class="content">
          <p>Hello <strong>@${username}</strong>,</p>
          <p>We are thrilled to inform you that your verification application to become a <strong>${readableType}</strong> has been officially approved by the ZeParty Admin Team.</p>
          
          <div class="highlight-box">
            <h4 style="margin-top:0; color:#e2e8f0;">What this means for your account:</h4>
            <ul style="margin-bottom:0; padding-left: 20px;">
              <li>You can now start Live Video broadcasts and host Audio Party rooms directly.</li>
              <li>Compete in PK Battles and challenge other hosts.</li>
              <li>Earn Diamonds from viewers and cash out bi-monthly with 0% platform deductions.</li>
              <li>Access the <strong>Live Host Center</strong> directly from your profile.</li>
            </ul>
          </div>

          <p>Open the ZeParty mobile app to start your first broadcast today!</p>
        </div>
        <div class="footer">
          <p>&copy; ${new Date().getFullYear()} ZeParty Inc. All rights reserved.</p>
          <p>This is an automated operational notification regarding your host verification request.</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `Hello @${username}!\n\nCongratulations! Your application to become a ${readableType} on ZeParty has been APPROVED by the admin team.\n\nYou can now go live, host audio parties, and compete in PK battles from the mobile app.\n\nBest regards,\nZeParty Admin Team`;

  await sendEmail({ to: userEmail, subject, html, text });
}

/**
 * Sends Host Application Rejection Email
 */
export async function sendHostRejectionEmail({ userEmail, username, hostType, reason }) {
  if (!userEmail) return;

  const readableType =
    hostType === 'BOTH'
      ? 'Live Video & Social Audio Host'
      : hostType === 'AUDIO_HOST'
      ? 'Social Audio Party Host'
      : 'Live Video Host';

  const subject = 'Update regarding your ZeParty Host Application';

  const html = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0f0d1b; color: #ffffff; margin: 0; padding: 20px; }
        .container { max-width: 600px; margin: 0 auto; background: #1a162b; border: 1px solid #382d5a; border-radius: 16px; padding: 32px; }
        .header { text-align: center; border-bottom: 1px solid #382d5a; padding-bottom: 20px; margin-bottom: 24px; }
        .logo { font-size: 26px; font-weight: bold; background: linear-gradient(135deg, #a855f7, #ec4899); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
        .badge { display: inline-block; background: #ef444422; border: 1px solid #ef4444; color: #f87171; padding: 6px 16px; border-radius: 20px; font-size: 13px; font-weight: bold; margin: 16px 0; }
        .content { font-size: 15px; line-height: 1.6; color: #cbd5e1; }
        .reason-box { background: #2b1824; border-radius: 12px; padding: 20px; margin: 20px 0; border-left: 4px solid #ef4444; }
        .footer { margin-top: 32px; font-size: 12px; color: #64748b; text-align: center; border-top: 1px solid #2a2245; padding-top: 20px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">ZeParty Live</div>
          <div class="badge">APPLICATION NOT APPROVED</div>
          <h2>Host Verification Status Update</h2>
        </div>
        <div class="content">
          <p>Hello <strong>@${username}</strong>,</p>
          <p>Thank you for your interest in becoming a <strong>${readableType}</strong> on ZeParty.</p>
          <p>After careful review by our compliance and moderation team, we regret to inform you that your application was not approved at this time.</p>
          
          <div class="reason-box">
            <strong style="color: #fca5a5;">Reviewer Feedback:</strong>
            <p style="margin: 8px 0 0 0; color: #fecdd3;">${reason || 'The submitted identification or video sample did not meet community standards.'}</p>
          </div>

          <p>You may re-apply with updated identity verification details directly through the ZeParty mobile app.</p>
        </div>
        <div class="footer">
          <p>&copy; ${new Date().getFullYear()} ZeParty Inc. All rights reserved.</p>
          <p>This is an automated operational notification regarding your host verification request.</p>
        </div>
      </div>
    </body>
    </html>
  `;

  const text = `Hello @${username},\n\nThank you for applying to become a ${readableType} on ZeParty.\n\nYour application was reviewed and not approved at this time.\nReason: ${reason || 'Application did not meet compliance requirements.'}\n\nYou may re-apply from the ZeParty mobile app.\n\nBest regards,\nZeParty Admin Team`;

  await sendEmail({ to: userEmail, subject, html, text });
}

export default {
  sendEmail,
  sendHostApprovalEmail,
  sendHostRejectionEmail,
};
