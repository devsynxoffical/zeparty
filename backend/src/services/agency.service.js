import prisma from '../config/database.js';
import agencyRepository from '../repositories/agency.repository.js';
import hostRepository from '../repositories/host.repository.js';

async function logAudit({ adminId, adminName, action, targetEntity, targetEntityId, beforeStateJson, afterStateJson, reason, ipAddress }, db = prisma) {
  try {
    await db.auditLog.create({
      data: {
        adminId: adminId || 'SYSTEM',
        adminName: adminName || 'System',
        action,
        targetEntity,
        targetEntityId: targetEntityId || null,
        beforeStateJson: beforeStateJson ? JSON.parse(JSON.stringify(beforeStateJson)) : null,
        afterStateJson: afterStateJson ? JSON.parse(JSON.stringify(afterStateJson)) : null,
        reason: reason || null,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });
  } catch (err) {
    console.error('Failed to write audit log in agency.service:', err);
  }
}

export async function createAgency(data, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const existingCode = await agencyRepository.findAgencyByCode(data.agencyCode, db);
  if (existingCode) {
    const error = new Error(`Agency code "${data.agencyCode}" is already in use`);
    error.statusCode = 409;
    error.code = 'AGENCY_CODE_ALREADY_EXISTS';
    throw error;
  }

  const agency = await agencyRepository.createAgency(data, db);

  await logAudit({
    adminId,
    adminName,
    action: 'AGENCY_CREATED',
    targetEntity: 'Agency',
    targetEntityId: agency.id,
    afterStateJson: {
      agencyName: agency.agencyName,
      agencyCode: agency.agencyCode,
      ownerUserId: agency.ownerUserId,
      commissionRate: agency.commissionRate,
    },
    ipAddress,
  }, db);

  return agency;
}

export async function updateAgency(id, updates, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const agency = await agencyRepository.findAgencyById(id, db);
  if (!agency) {
    const error = new Error('Agency not found');
    error.statusCode = 404;
    error.code = 'AGENCY_NOT_FOUND';
    throw error;
  }

  const updatedAgency = await agencyRepository.updateAgency(id, updates, db);

  await logAudit({
    adminId,
    adminName,
    action: 'AGENCY_UPDATED',
    targetEntity: 'Agency',
    targetEntityId: id,
    beforeStateJson: {
      agencyName: agency.agencyName,
      commissionRate: agency.commissionRate,
      status: agency.status,
    },
    afterStateJson: updates,
    ipAddress,
  }, db);

  return updatedAgency;
}

export async function getAgencyDetails(id, db = prisma) {
  const agency = await agencyRepository.findAgencyById(id, db);
  if (!agency) {
    const error = new Error('Agency not found');
    error.statusCode = 404;
    error.code = 'AGENCY_NOT_FOUND';
    throw error;
  }
  return agency;
}

export async function bindHostToAgency({ agencyId, hostProfileId }, { adminId, adminName, ipAddress } = {}, db = prisma) {
  const agency = await agencyRepository.findAgencyById(agencyId, db);
  if (!agency) {
    const error = new Error('Agency not found');
    error.statusCode = 404;
    error.code = 'AGENCY_NOT_FOUND';
    throw error;
  }

  if (agency.status !== 'ACTIVE') {
    const error = new Error('Cannot bind host to an inactive/suspended agency');
    error.statusCode = 400;
    error.code = 'AGENCY_NOT_ACTIVE';
    throw error;
  }

  const host = await hostRepository.findHostProfileById(hostProfileId, db);
  if (!host) {
    const error = new Error('Host profile not found');
    error.statusCode = 404;
    error.code = 'HOST_NOT_FOUND';
    throw error;
  }

  const existingMember = await agencyRepository.findMember(agencyId, host.userId, db);
  if (existingMember) {
    const error = new Error('Host is already a member of this agency');
    error.statusCode = 409;
    error.code = 'ALREADY_AGENCY_MEMBER';
    throw error;
  }

  const member = await db.$transaction(async (tx) => {
    const newMember = await agencyRepository.addMember({
      agencyId,
      userId: host.userId,
      hostProfileId,
    }, tx);

    await hostRepository.updateHostProfile(hostProfileId, { agencyId }, tx);
    return newMember;
  });

  await logAudit({
    adminId,
    adminName,
    action: 'AGENCY_MEMBER_BOUND',
    targetEntity: 'AgencyMember',
    targetEntityId: member.id,
    afterStateJson: { agencyId, hostProfileId, userId: host.userId },
    ipAddress,
  }, db);

  return member;
}

export async function transferHostBetweenAgencies(
  { hostProfileId, fromAgencyId, toAgencyId, reason },
  { adminId, adminName, ipAddress } = {},
  db = prisma
) {
  if (fromAgencyId === toAgencyId) {
    const error = new Error('Source agency and destination agency cannot be the same');
    error.statusCode = 400;
    error.code = 'SAME_AGENCY_TRANSFER';
    throw error;
  }

  const destAgency = await agencyRepository.findAgencyById(toAgencyId, db);
  if (!destAgency || destAgency.status !== 'ACTIVE') {
    const error = new Error('Destination agency does not exist or is not active');
    error.statusCode = 404;
    error.code = 'INVALID_DESTINATION_AGENCY';
    throw error;
  }

  const host = await hostRepository.findHostProfileById(hostProfileId, db);
  if (!host) {
    const error = new Error('Host profile not found');
    error.statusCode = 404;
    error.code = 'HOST_NOT_FOUND';
    throw error;
  }

  const transferredMember = await db.$transaction(async (tx) => {
    return await agencyRepository.transferHostMembership(
      hostProfileId,
      fromAgencyId,
      toAgencyId,
      host.userId,
      tx
    );
  });

  await logAudit({
    adminId,
    adminName,
    action: 'AGENCY_MEMBER_TRANSFERRED',
    targetEntity: 'HostProfile',
    targetEntityId: hostProfileId,
    beforeStateJson: { agencyId: fromAgencyId },
    afterStateJson: { agencyId: toAgencyId },
    reason,
    ipAddress,
  }, db);

  return transferredMember;
}

/**
 * Agency Center -> Agency Wallet
 * Contains only the agency owner's earned commission.
 * Individual host salaries are credited to each host personal wallet.
 */
export async function getAgencyWallet(agencyId, userId, db = prisma) {
  const agency = await db.agency.findUnique({
    where: { id: agencyId },
    include: {
      owner: {
        select: { id: true, username: true, countryCode: true, profile: true },
      },
    },
  });

  if (!agency) {
    const error = new Error('Agency not found');
    error.statusCode = 404;
    error.code = 'AGENCY_NOT_FOUND';
    throw error;
  }

  // Only agency owner can access the Agency Wallet
  if (agency.ownerUserId !== userId) {
    const error = new Error('Access denied. Agency Wallet is exclusively accessible to the agency owner.');
    error.statusCode = 403;
    error.code = 'NOT_AGENCY_OWNER';
    throw error;
  }

  // Query actual commission records from SettlementRecord for this agency
  const commissionRecords = await db.settlementRecord.findMany({
    where: {
      recipientId: agencyId,
      recipientType: 'AGENCY',
    },
    orderBy: { createdAt: 'desc' },
  });

  // Query withdrawal requests submitted by the agency owner for this wallet
  const withdrawalRequests = await db.withdrawalRequest.findMany({
    where: {
      userId,
      accountDetails: {
        path: ['channel'],
        equals: 'AGENCY_COMMISSION_WALLET',
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  const confirmedCommission = commissionRecords
    .filter(r => r.status === 'PAID')
    .reduce((sum, r) => sum + Number(r.netPayableUSD), 0);

  const pendingCommission = commissionRecords
    .filter(r => r.status === 'CALCULATED' || r.status === 'APPROVED')
    .reduce((sum, r) => sum + Number(r.netPayableUSD), 0);

  const pendingWithdrawalsUSD = withdrawalRequests
    .filter(w => w.status === 'PENDING')
    .reduce((sum, w) => sum + Number(w.amountUSD), 0);

  const totalWithdrawnUSD = withdrawalRequests
    .filter(w => w.status === 'APPROVED')
    .reduce((sum, w) => sum + Number(w.amountUSD), 0);

  const availableEarningsUSD = Math.max(0, confirmedCommission - pendingWithdrawalsUSD - totalWithdrawnUSD);

  const history = [
    ...commissionRecords.map(r => ({
      id: r.id,
      type: 'COMMISSION_ACCRUAL',
      title: 'Agency Commission Split',
      cycle: r.settlementPeriodId || 'Bi-Weekly Cycle',
      amountUSD: Number(r.netPayableUSD),
      date: r.createdAt,
      status: r.status,
    })),
    ...withdrawalRequests.map(w => ({
      id: w.id,
      type: 'COMMISSION_WITHDRAWAL',
      title: 'Commission Withdrawal',
      recipientName: w.accountDetails?.recipientName || 'Authorized Recipient',
      recipientId: w.accountDetails?.recipientId || '',
      amountUSD: Number(w.amountUSD),
      date: w.createdAt,
      status: w.status,
    })),
  ].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  return {
    agencyId,
    agencyName: agency.agencyName,
    ownerUserId: agency.ownerUserId,
    ownerCountryCode: agency.owner?.countryCode || 'GLOBAL',
    noticeText: 'Agency Wallet receives only the agency owner commission. Individual host salaries are credited to each host personal wallet.',
    ledgerHeading: 'Commission History',
    availableEarningsUSD: Number(availableEarningsUSD.toFixed(2)),
    pendingEarningsUSD: Number(pendingCommission.toFixed(2)),
    totalWithdrawnUSD: Number(totalWithdrawnUSD.toFixed(2)),
    commissionHistory: history,
    hasCommissionRecords: history.length > 0,
  };
}

/**
 * Submit Agency Commission Withdrawal
 * Allows agency owner to withdraw available commission only to authorized
 * recipients registered in the same country as the agency owner.
 */
export async function withdrawAgencyCommission({ agencyId, userId, amountUSD, recipientId, recipientRole = 'COIN_SELLER', ipAddress }, db = prisma) {
  const parsedAmount = Number(amountUSD);
  if (!parsedAmount || isNaN(parsedAmount) || parsedAmount <= 0) {
    const error = new Error('Please enter a valid withdrawal amount greater than $0.00');
    error.statusCode = 400;
    error.code = 'INVALID_AMOUNT';
    throw error;
  }

  const walletInfo = await getAgencyWallet(agencyId, userId, db);

  if (walletInfo.availableEarningsUSD < parsedAmount) {
    const error = new Error(`Insufficient available commission. Available: $${walletInfo.availableEarningsUSD.toFixed(2)}, Requested: $${parsedAmount.toFixed(2)}`);
    error.statusCode = 400;
    error.code = 'INSUFFICIENT_COMMISSION';
    throw error;
  }

  const ownerCountry = walletInfo.ownerCountryCode.trim().toUpperCase();

  // Validate recipient country matches agency owner ID country
  const normalizedRole = String(recipientRole).toUpperCase();
  let recipientUser = null;
  let recipientName = '';

  if (normalizedRole === 'MERCHANT') {
    const merchant = await db.merchant.findFirst({
      where: {
        OR: [{ id: recipientId }, { userId: recipientId }],
        status: 'ACTIVE',
      },
      include: { user: true },
    });

    if (!merchant) {
      const error = new Error('Selected Merchant is not active or authorized');
      error.statusCode = 404;
      error.code = 'RECIPIENT_NOT_FOUND';
      throw error;
    }

    if (merchant.user?.countryCode?.toUpperCase() !== ownerCountry) {
      const error = new Error(`Cross-country commission withdrawal is forbidden. Your owner account is registered in ${ownerCountry}, while recipient is in ${merchant.user?.countryCode || 'another country'}.`);
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_WITHDRAWAL_FORBIDDEN';
      throw error;
    }

    recipientUser = merchant.user;
    recipientName = merchant.companyName || merchant.user.username;
  } else {
    // COIN_SELLER
    const seller = await db.coinSeller.findFirst({
      where: {
        OR: [{ id: recipientId }, { userId: recipientId }],
        sellerStatus: 'ACTIVE',
      },
      include: { user: true },
    });

    if (!seller) {
      const error = new Error('Selected Coin Seller is not active or authorized');
      error.statusCode = 404;
      error.code = 'RECIPIENT_NOT_FOUND';
      throw error;
    }

    if (seller.user?.countryCode?.toUpperCase() !== ownerCountry) {
      const error = new Error(`Cross-country commission withdrawal is forbidden. Your owner account is registered in ${ownerCountry}, while recipient is in ${seller.user?.countryCode || 'another country'}.`);
      error.statusCode = 403;
      error.code = 'CROSS_COUNTRY_WITHDRAWAL_FORBIDDEN';
      throw error;
    }

    recipientUser = seller.user;
    recipientName = seller.businessName || seller.user.username;
  }

  return await db.$transaction(async (tx) => {
    const withdrawal = await tx.withdrawalRequest.create({
      data: {
        userId,
        amountUSD: parsedAmount,
        diamondsDebited: BigInt(0), // Commission is tracked in USD, host diamonds unchanged
        payoutMethod: normalizedRole,
        accountDetails: {
          channel: 'AGENCY_COMMISSION_WALLET',
          agencyId,
          agencyName: walletInfo.agencyName,
          recipientId,
          recipientUserId: recipientUser.id,
          recipientName,
          recipientRole: normalizedRole,
          country: ownerCountry,
          submittedAt: new Date().toISOString(),
        },
        status: 'PENDING',
      },
    });

    await tx.auditLog.create({
      data: {
        adminId: 'SYSTEM',
        adminName: 'Agency Commission Engine',
        action: 'AGENCY_COMMISSION_WITHDRAWAL_REQUESTED',
        targetEntity: 'WithdrawalRequest',
        targetEntityId: withdrawal.id,
        afterStateJson: {
          agencyId,
          ownerUserId: userId,
          amountUSD: parsedAmount,
          recipientId,
          recipientName,
          recipientRole: normalizedRole,
          country: ownerCountry,
        },
        reason: `Agency owner requested commission withdrawal of $${parsedAmount} to ${normalizedRole} (${recipientName}) in ${ownerCountry}`,
        ipAddress: ipAddress || '127.0.0.1',
      },
    });

    return {
      success: true,
      message: `Commission withdrawal request of $${parsedAmount.toFixed(2)} submitted successfully.`,
      withdrawal,
    };
  });
}

export default {
  createAgency,
  updateAgency,
  getAgencyDetails,
  bindHostToAgency,
  transferHostBetweenAgencies,
  getAgencyWallet,
  withdrawAgencyCommission,
};

