export const CURRENT_AGENCY_HOST_POLICY = {
  version: 'v3.0.0',
  effectiveDate: '2026-08-24',
  status: 'ACTIVE',
  description: 'Official 2026 Agency Host Policy. 25 configurable target levels with Basic, Host, and Agency splits, Special ID durations, and room-owner/incomplete-day rules.',
  roomOwnerRewardPercent: 5,
  incompleteDaysPayoutPercent: 50,
  rules: [
    'If users are sent to a room, the room owner receives 5% reward weekly.',
    'If host does not complete valid days, the host receives only 50% of the target reward.'
  ],
  tiers: [
    { level: 1, targetDiamonds: 25000, durationDays: 10, basicSalaryUSD: 2.00, hostSalaryUSD: 1.60, agencySalaryUSD: 0.40, specialIdDuration: '/' },
    { level: 2, targetDiamonds: 50000, durationDays: 10, basicSalaryUSD: 4.00, hostSalaryUSD: 3.20, agencySalaryUSD: 0.80, specialIdDuration: '/' },
    { level: 3, targetDiamonds: 100000, durationDays: 10, basicSalaryUSD: 8.00, hostSalaryUSD: 6.40, agencySalaryUSD: 1.60, specialIdDuration: '/' },
    { level: 4, targetDiamonds: 250000, durationDays: 10, basicSalaryUSD: 20.00, hostSalaryUSD: 16.00, agencySalaryUSD: 4.00, specialIdDuration: '/' },
    { level: 5, targetDiamonds: 500000, durationDays: 8, basicSalaryUSD: 40.00, hostSalaryUSD: 32.00, agencySalaryUSD: 8.00, specialIdDuration: '/' },
    { level: 6, targetDiamonds: 750000, durationDays: 8, basicSalaryUSD: 60.00, hostSalaryUSD: 48.00, agencySalaryUSD: 12.00, specialIdDuration: '/' },
    { level: 7, targetDiamonds: 1000000, durationDays: 8, basicSalaryUSD: 80.00, hostSalaryUSD: 64.00, agencySalaryUSD: 16.00, specialIdDuration: '/' },
    { level: 8, targetDiamonds: 1500000, durationDays: 8, basicSalaryUSD: 120.00, hostSalaryUSD: 96.00, agencySalaryUSD: 24.00, specialIdDuration: '/' },
    { level: 9, targetDiamonds: 2000000, durationDays: 8, basicSalaryUSD: 160.00, hostSalaryUSD: 128.00, agencySalaryUSD: 32.00, specialIdDuration: '/' },
    { level: 10, targetDiamonds: 2500000, durationDays: 8, basicSalaryUSD: 200.00, hostSalaryUSD: 160.00, agencySalaryUSD: 40.00, specialIdDuration: '/' },
    { level: 11, targetDiamonds: 3000000, durationDays: 5, basicSalaryUSD: 240.00, hostSalaryUSD: 192.00, agencySalaryUSD: 48.00, specialIdDuration: '3 Days' },
    { level: 12, targetDiamonds: 3500000, durationDays: 5, basicSalaryUSD: 280.00, hostSalaryUSD: 224.00, agencySalaryUSD: 56.00, specialIdDuration: '3 Days' },
    { level: 13, targetDiamonds: 4000000, durationDays: 5, basicSalaryUSD: 320.00, hostSalaryUSD: 256.00, agencySalaryUSD: 64.00, specialIdDuration: '3 Days' },
    { level: 14, targetDiamonds: 4500000, durationDays: 5, basicSalaryUSD: 360.00, hostSalaryUSD: 288.00, agencySalaryUSD: 72.00, specialIdDuration: '7 Days' },
    { level: 15, targetDiamonds: 5000000, durationDays: 5, basicSalaryUSD: 400.00, hostSalaryUSD: 320.00, agencySalaryUSD: 80.00, specialIdDuration: '15 Days' },
    { level: 16, targetDiamonds: 6000000, durationDays: 5, basicSalaryUSD: 480.00, hostSalaryUSD: 384.00, agencySalaryUSD: 96.00, specialIdDuration: '15 Days' },
    { level: 17, targetDiamonds: 7000000, durationDays: 5, basicSalaryUSD: 560.00, hostSalaryUSD: 448.00, agencySalaryUSD: 112.00, specialIdDuration: '15 Days' },
    { level: 18, targetDiamonds: 8000000, durationDays: 5, basicSalaryUSD: 640.00, hostSalaryUSD: 512.00, agencySalaryUSD: 128.00, specialIdDuration: '30 Days' },
    { level: 19, targetDiamonds: 9000000, durationDays: 5, basicSalaryUSD: 720.00, hostSalaryUSD: 576.00, agencySalaryUSD: 144.00, specialIdDuration: '30 Days' },
    { level: 20, targetDiamonds: 10000000, durationDays: 5, basicSalaryUSD: 800.00, hostSalaryUSD: 640.00, agencySalaryUSD: 160.00, specialIdDuration: '60 Days' },
    { level: 21, targetDiamonds: 15000000, durationDays: 5, basicSalaryUSD: 1200.00, hostSalaryUSD: 960.00, agencySalaryUSD: 240.00, specialIdDuration: '60 Days' },
    { level: 22, targetDiamonds: 20000000, durationDays: 5, basicSalaryUSD: 1600.00, hostSalaryUSD: 1280.00, agencySalaryUSD: 320.00, specialIdDuration: '60 Days' },
    { level: 23, targetDiamonds: 30000000, durationDays: 5, basicSalaryUSD: 2400.00, hostSalaryUSD: 1920.00, agencySalaryUSD: 480.00, specialIdDuration: '90 Days' },
    { level: 24, targetDiamonds: 40000000, durationDays: 5, basicSalaryUSD: 3200.00, hostSalaryUSD: 2560.00, agencySalaryUSD: 640.00, specialIdDuration: '90 Days' },
    { level: 25, targetDiamonds: 50000000, durationDays: 5, basicSalaryUSD: 4000.00, hostSalaryUSD: 3200.00, agencySalaryUSD: 800.00, specialIdDuration: '120 Days' }
  ]
};
