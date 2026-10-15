// ============================================================
// ZeParty Admin Portal — Agency Management Page (JSX)
// 2026 Developer Specification Alignment
// ============================================================

import React, { useState, useMemo, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
  Building2, Search, Eye, CheckCircle, XCircle, ArrowRightLeft, Users, Building,
  DollarSign, ShieldCheck, Video, Mic, RefreshCw, Settings, Trash, Plus
} from 'lucide-react';
import { DataTable } from '../../components/tables/DataTable';
import { StatusBadge, Badge } from '../../components/ui/Badge';
import { Card } from '../../components/ui/Card';
import { Input } from '../../components/ui/Input';
import { Modal } from '../../components/ui/Modal';
import { Button } from '../../components/ui/Button';
import {
  getAgencies,
  getActiveAgencies,
  updateAgency,
  approveAgency,
  rejectAgency,
  transferHostAgency,
  getAgencyApplications,
  approveAgencyApplication,
  rejectAgencyApplication,
} from '../../services/modules/agencies.service';
import { formatDate, formatNumber, formatCurrency } from '../../utils/format';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';
import { usePermission } from '../../hooks/usePermission';
import { useAuditLog } from '../../context/AuditLogContext';

export function AgenciesPage() {
  const { logAdminAction } = useAuditLog();
  const [searchParams, setSearchParams] = useSearchParams();
  const typeParam = searchParams.get('type') || 'live';
  const tabParam = searchParams.get('tab') || 'activeAgencies';

  const [activeTab, setActiveTab] = useState(tabParam); // 'activeAgencies' | 'applications'
  const [agencies, setAgencies] = useState([]);
  const [applications, setApplications] = useState([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    if (tabParam && tabParam !== activeTab) {
      setActiveTab(tabParam);
    }
  }, [tabParam]);
  
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [bdCenterFilter, setBdCenterFilter] = useState('all');
  const [selectedAgency, setSelectedAgency] = useState(null);
  
  // BD Center Modal State
  const [isBDCenterModalOpen, setIsBDCenterModalOpen] = useState(false);
  const [bdCenterAssignModal, setBdCenterAssignModal] = useState({ open: false, agency: null, bdCenterId: '' });
  
  // Modals
  const [transferModal, setTransferModal] = useState({ open: false, agency: null });
  const [transferHostName, setTransferHostName] = useState('');
  const [targetAgencyId, setTargetAgencyId] = useState('');
  const [transferReason, setTransferReason] = useState('');
  
  const [commissionModal, setCommissionModal] = useState({ open: false, agency: null, commission: '' });
  const [settlementModal, setSettlementModal] = useState({ open: false, agency: null, settlementMethod: '', taxId: '' });
  const [rosterModal, setRosterModal] = useState({ open: false, agency: null, hostId: '' });
  const [rejectModal, setRejectModal] = useState({ open: false, application: null, reason: '' });
  const [selectedAppModal, setSelectedAppModal] = useState(null);
  const [feedback, setFeedback] = useState(null);

  const fetchAgenciesData = () => {
    setIsLoading(true);
    Promise.allSettled([getActiveAgencies(), getAgencyApplications()])
      .then(([activeRes, appsRes]) => {
        if (activeRes.status === 'fulfilled') {
          setAgencies(activeRes.value || []);
        } else {
          console.error('Failed to load active agencies:', activeRes.reason);
        }
        if (appsRes.status === 'fulfilled') {
          setApplications(appsRes.value || []);
        } else {
          console.error('Failed to load agency applications:', appsRes.reason);
        }
      })
      .finally(() => setIsLoading(false));
  };

  useEffect(() => {
    fetchAgenciesData();
  }, []);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const activeCategory = 'AUDIO_AGENCY';

  const handleApprove = async (id) => {
    try {
      await approveAgencyApplication(id);
      fetchAgenciesData();
      await logAdminAction({
        action: 'AGENCY_APPLICATION_APPROVED',
        module: 'Agencies',
        targetType: 'agency_application',
        targetId: id,
        targetName: `Application ${id}`,
        reason: 'Approved agency onboarding application',
        riskLevel: 'HIGH',
      });
      showFeedback(`Agency application approved. Agency activated and applicant assigned as owner.`);
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to approve agency application');
    }
  };

  const handleOpenReject = (app) => {
    setRejectModal({ open: true, application: app, reason: '' });
  };

  const handleExecuteReject = async () => {
    if (!rejectModal.application || !rejectModal.reason || rejectModal.reason.trim().length < 3) {
      showFeedback('Please provide a valid rejection reason (minimum 3 characters)');
      return;
    }
    const { application, reason } = rejectModal;
    try {
      await rejectAgencyApplication(application.id, reason.trim());
      fetchAgenciesData();
      await logAdminAction({
        action: 'AGENCY_APPLICATION_REJECTED',
        module: 'Agencies',
        targetType: 'agency_application',
        targetId: application.id,
        targetName: application.agencyName,
        reason: reason.trim(),
        riskLevel: 'MEDIUM',
      });
      showFeedback(`Agency application "${application.agencyName}" was rejected.`);
      setRejectModal({ open: false, application: null, reason: '' });
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to reject agency application');
    }
  };

  const handleExecuteTransfer = async (e) => {
    e.preventDefault();
    if (!transferModal.agency || !targetAgencyId || !transferHostName) return;

    const targetAgency = agencies.find((a) => a.id === targetAgencyId);

    try {
      await transferHostAgency(
        transferHostName,
        transferModal.agency.id,
        targetAgencyId,
        transferReason
      );

      await logAdminAction({
        action: 'HOST_AGENCY_TRANSFERRED',
        module: 'Agencies',
        targetType: 'host',
        targetId: transferHostName,
        targetName: transferHostName,
        reason: transferReason || `Transferred from ${transferModal.agency.agencyName} to ${targetAgency?.agencyName}`,
        riskLevel: 'HIGH',
      });

      fetchAgenciesData();
      showFeedback(`Host "${transferHostName}" successfully transferred.`);
      setTransferModal({ open: false, agency: null });
      setTransferHostName('');
      setTargetAgencyId('');
      setTransferReason('');
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Transfer failed');
    }
  };

  const handleSaveCommission = async () => {
    const { agency, commission } = commissionModal;
    if (!agency) return;

    try {
      await updateAgency(agency.id, { commissionRate: Number(commission) });
      fetchAgenciesData();

      await logAdminAction({
        action: 'AGENCY_COMMISSION_UPDATED',
        module: 'Agencies',
        targetType: 'agency',
        targetId: agency.id,
        targetName: agency.agencyName,
        reason: `Commission rate changed to ${commission}%`,
        riskLevel: 'HIGH',
      });

      showFeedback(`Commission rate updated to ${commission}% for ${agency.agencyName}.`);
      setCommissionModal({ open: false, agency: null, commission: '' });
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to update commission');
    }
  };

  const handleSaveSettlement = async () => {
    const { agency, settlementMethod, taxId } = settlementModal;
    if (!agency) return;

    try {
      await updateAgency(agency.id, { settlementMethod, taxId });
      fetchAgenciesData();

      await logAdminAction({
        action: 'AGENCY_SETTLEMENT_CONFIGURED',
        module: 'Agencies',
        targetType: 'agency',
        targetId: agency.id,
        targetName: agency.agencyName,
        reason: `Method: ${settlementMethod}, Tax ID: ${taxId}`,
        riskLevel: 'HIGH',
      });

      showFeedback(`Settlement configuration updated for ${agency.agencyName}.`);
      setSettlementModal({ open: false, agency: null, settlementMethod: '', taxId: '' });
    } catch (err) {
      showFeedback(err?.response?.data?.message || 'Failed to save settlement config');
    }
  };

  const handleRosterAction = async (actionType) => {
    const { agency, hostId } = rosterModal;
    if (!agency || !hostId) return;

    setAgencies((prev) => prev.map((a) => {
      if (a.id === agency.id) {
        const countMod = actionType === 'add' ? 1 : -1;
        return { ...a, hostsCount: Math.max(0, a.hostsCount + countMod) };
      }
      return a;
    }));

    await logAdminAction({
      action: actionType === 'add' ? 'AGENCY_HOST_ASSIGNED' : 'AGENCY_HOST_REMOVED',
      module: 'Agencies',
      targetType: 'agency',
      targetId: agency.id,
      targetName: agency.agencyName,
      reason: `${actionType === 'add' ? 'Assigned' : 'Removed'} host ID: ${hostId}`,
      riskLevel: 'MEDIUM',
    });

    showFeedback(`Roster modified for ${agency.agencyName}.`);
    setRosterModal({ open: false, agency: null, hostId: '' });
  };

  const filteredActive = useMemo(() => {
    const q = search.toLowerCase();
    return agencies.filter((a) => {
      const matchType = a.agencyType === activeCategory;
      const matchSearch =
        !q ||
        a.id.toLowerCase().includes(q) ||
        a.agencyName.toLowerCase().includes(q) ||
        a.contactName.toLowerCase().includes(q);
      return matchType && matchSearch;
    });
  }, [agencies, activeCategory, search]);

  const filteredApps = useMemo(() => {
    const q = search.toLowerCase();
    return applications.filter((a) => {
      const matchStatus =
        statusFilter === 'all' ||
        String(a.status || '').toLowerCase() === statusFilter.toLowerCase();
      const matchSearch =
        !q ||
        (a.id && a.id.toLowerCase().includes(q)) ||
        (a.agencyName && a.agencyName.toLowerCase().includes(q)) ||
        (a.applicantZePartyId && a.applicantZePartyId.toLowerCase().includes(q)) ||
        (a.phoneNumber && a.phoneNumber.toLowerCase().includes(q)) ||
        (a.applicant?.username && a.applicant.username.toLowerCase().includes(q)) ||
        (a.applicant?.profile?.displayName && a.applicant.profile.displayName.toLowerCase().includes(q));
      return matchStatus && matchSearch;
    });
  }, [applications, statusFilter, search]);

  const activeColumns = [
    {
      key: 'agency',
      header: 'Agency ID & Name',
      render: (row) => (
        <div>
          <div className="flex items-center gap-1.5">
            <span className="text-sm font-bold text-white">{row.agencyName}</span>
            {row.agencyType === 'AUDIO_AGENCY' ? (
              <span className="px-1.5 py-0.5 rounded bg-indigo-500/20 text-indigo-300 text-[10px] font-mono border border-indigo-500/40 flex items-center gap-0.5">
                <Mic className="h-2.5 w-2.5" /> AUDIO
              </span>
            ) : (
              <span className="px-1.5 py-0.5 rounded bg-purple-500/20 text-purple-300 text-[10px] font-mono border border-purple-500/40 flex items-center gap-0.5">
                <Video className="h-2.5 w-2.5" /> LIVE
              </span>
            )}
          </div>
          <p className="text-xs text-slate-400">ID: {row.id} · Owner: {row.contactName}</p>
        </div>
      ),
    },
    {
      key: 'country',
      header: 'Location',
      render: (row) => (
        <Badge variant="default" className="text-[10px] font-semibold flex items-center gap-1.5 px-2 py-0.5">
          <CountryFlag code={row.country} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0" />
          <span>{getCountryShortName(row.country)}</span>
        </Badge>
      ),
    },
    {
      key: 'creatorRoster',
      header: 'Hosts Count',
      render: (row) => (
        <div className="flex items-center gap-1.5 text-xs text-sky-400">
          <Users className="h-4 w-4" />
          <span className="font-bold">{row.hostsCount} Creators</span>
        </div>
      ),
    },
    {
      key: 'volume',
      header: 'Financial Volume',
      render: (row) => (
        <span className="text-xs text-emerald-400 font-bold font-mono">
          {formatCurrency(row.monthlyGrossUSD || 0)}
        </span>
      ),
    },
    {
      key: 'commission',
      header: 'Commission Split',
      render: (row) => <Badge variant="purple">{row.commissionPercent}% share</Badge>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={row.status} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) => (
        <div className="flex items-center gap-1">
          <button
            title="Inspect Details"
            onClick={() => setSelectedAgency(row)}
            className="p-1 rounded bg-slate-800 text-sky-400 hover:bg-slate-700 transition-colors"
          >
            <Eye className="h-4 w-4" />
          </button>
          <button
            title="Configure Commission"
            onClick={() => setCommissionModal({ open: true, agency: row, commission: row.commissionPercent })}
            className="p-1 rounded bg-slate-800 text-gold-400 hover:bg-slate-700 transition-colors"
          >
            <Settings className="h-4 w-4" />
          </button>
          <button
            title="Configure Settlement"
            onClick={() => setSettlementModal({ open: true, agency: row, settlementMethod: row.settlementMethod || 'Bank Wire', taxId: row.taxId || '' })}
            className="p-1 rounded bg-slate-800 text-emerald-400 hover:bg-slate-700 transition-colors"
          >
            <DollarSign className="h-4 w-4" />
          </button>
          <button
            title="Transfer Host"
            onClick={() => setTransferModal({ open: true, agency: row })}
            className="p-1 rounded bg-slate-800 text-indigo-400 hover:bg-slate-700 transition-colors"
          >
            <ArrowRightLeft className="h-4 w-4" />
          </button>
          <button
            title="Assign/Remove Hosts"
            onClick={() => setRosterModal({ open: true, agency: row, hostId: '' })}
            className="p-1 rounded bg-slate-800 text-slate-300 hover:bg-slate-700 transition-colors"
          >
            <Users className="h-4 w-4" />
          </button>
        </div>
      ),
    },
  ];

  const appColumns = [
    {
      key: 'agency',
      header: 'Agency Applicant',
      render: (row) => (
        <div>
          <p className="text-sm font-bold text-white">{row.agencyName}</p>
          <p className="text-xs text-slate-400 mt-0.5">
            @{row.applicant?.username || '—'} · ZeParty ID:{' '}
            <span className="text-sky-400 font-mono">{row.applicantZePartyId || '—'}</span>
          </p>
          {row.applicant?.profile?.displayName && (
            <p className="text-xs text-slate-500">{row.applicant.profile.displayName}</p>
          )}
        </div>
      ),
    },
    {
      key: 'phone',
      header: 'Phone',
      render: (row) => <span className="text-xs font-mono text-slate-300">{row.phoneNumber || '—'}</span>,
    },
    {
      key: 'hostRefs',
      header: 'External Host IDs',
      render: (row) => (
        <div className="flex flex-col gap-0.5">
          {[row.hostRef1, row.hostRef2, row.hostRef3, row.hostRef4, row.hostRef5].map((ref, i) => (
            <span key={i} className="text-xs font-mono text-cyan-400 truncate max-w-[120px]" title={ref}>
              {ref ? `${i + 1}: ${ref}` : `${i + 1}: —`}
            </span>
          ))}
        </div>
      ),
    },
    {
      key: 'submittedAt',
      header: 'Submitted',
      render: (row) => <span className="text-xs text-slate-400">{formatDate(row.createdAt || row.submittedAt)}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      render: (row) => <StatusBadge status={row.status} />,
    },
    {
      key: 'actions',
      header: 'Actions',
      render: (row) =>
        row.status === 'PENDING' ? (
          <div className="flex gap-2 flex-wrap">
            <Button variant="primary" size="xs" onClick={() => setSelectedAppModal(row)}>
              View
            </Button>
            <Button variant="success" size="xs" onClick={() => handleApprove(row.id)}>
              Approve
            </Button>
            <Button variant="danger" size="xs" onClick={() => handleOpenReject(row)}>
              Reject
            </Button>
          </div>
        ) : (
          <div className="flex gap-2">
            <Button variant="ghost" size="xs" onClick={() => setSelectedAppModal(row)}>
              View
            </Button>
            <span className={`text-xs font-semibold capitalize ${row.status === 'APPROVED' ? 'text-emerald-400' : 'text-rose-400'}`}>
              {row.status}
            </span>
          </div>
        ),
    },
  ];

  return (
    <div className="flex flex-col gap-6">
      {/* Header with Type selector */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white flex items-center gap-2">
            <Building2 className="h-7 w-7 text-blue-400" />
            Agency Registry & Settlements
          </h1>
          <p className="text-sm text-slate-400 mt-0.5">
            Manage agency classifications, approve licenses, and configure creator commission settlement splits.
          </p>
        </div>

        <div className="flex items-center gap-2 bg-indigo-950/60 border border-indigo-800/60 rounded-xl px-4 py-2 text-xs font-bold text-indigo-300">
          <Mic className="h-4 w-4 text-indigo-400" />
          Social Audio Agencies Only
        </div>
      </div>

      {feedback && (
        <div className="p-3 rounded bg-emerald-500/20 border border-emerald-500/40 text-emerald-400 text-xs font-bold flex items-center gap-2">
          <CheckCircle className="h-4 w-4 shrink-0" />
          <span>{feedback}</span>
        </div>
      )}

      {/* Tabs */}
      <div className="flex gap-6 border-b border-slate-800">
        <button
          onClick={() => {
            setActiveTab('activeAgencies');
            setSearch('');
            setSearchParams((prev) => {
              const n = new URLSearchParams(prev);
              n.set('tab', 'activeAgencies');
              return n;
            });
          }}
          className={`pb-3 text-sm font-semibold transition-colors border-b-2 ${
            activeTab === 'activeAgencies' ? 'text-gold-400 border-gold-500' : 'text-slate-400 border-transparent hover:text-white'
          }`}
        >
          Licensed Agencies ({filteredActive.length})
        </button>
        <button
          onClick={() => {
            setActiveTab('applications');
            setSearch('');
            setSearchParams((prev) => {
              const n = new URLSearchParams(prev);
              n.set('tab', 'applications');
              return n;
            });
          }}
          className={`pb-3 text-sm font-semibold transition-colors border-b-2 ${
            activeTab === 'applications' ? 'text-gold-400 border-gold-500' : 'text-slate-400 border-transparent hover:text-white'
          }`}
        >
          License Requests ({filteredApps.length})
        </button>
      </div>

      {/* Filter controls */}
      <Card className="p-4 flex flex-col md:flex-row gap-3 items-stretch md:items-center justify-between">
        <Input
          placeholder="Search by agency ID, name, owner..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          leftIcon={Search}
          containerClassName="flex-1 max-w-md"
        />

        <div className="flex items-center gap-2">
          {activeTab === 'applications' && (
            <div className="flex items-center gap-2">
              <span className="text-xs text-slate-500 font-bold">Status:</span>
              {['all', 'pending', 'approved', 'rejected'].map((st) => (
                <button
                  key={st}
                  onClick={() => setStatusFilter(st)}
                  className={`px-2 py-1 rounded text-xs font-medium uppercase border ${
                    statusFilter === st ? 'bg-indigo-500/20 border-indigo-500/50 text-indigo-400' : 'bg-slate-800 border-slate-700 text-slate-400 hover:text-white'
                  }`}
                >
                  {st}
                </button>
              ))}
            </div>
          )}
        </div>
      </Card>

      {/* Table */}
      {activeTab === 'activeAgencies' ? (
        <DataTable
          columns={activeColumns}
          data={filteredActive}
          isLoading={false}
          emptyTitle="No Active Agencies Found"
          emptyDescription={`No ${typeParam === 'audio' ? 'Audio' : 'Live'} agencies match the search.`}
        />
      ) : (
        <DataTable
          columns={appColumns}
          data={filteredApps}
          isLoading={isLoading}
          emptyTitle="No License Requests"
          emptyDescription="There are no pending applications for this classification."
        />
      )}

      {/* Details Modal */}
      {selectedAgency && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedAgency(null)}
          title={`Agency Profile: ${selectedAgency.agencyName}`}
          size="lg"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 flex justify-between items-center">
              <div>
                <p className="text-base font-bold text-white">{selectedAgency.agencyName}</p>
                <p className="text-slate-400">Owner: {selectedAgency.contactName} · Email: {selectedAgency.contactEmail}</p>
              </div>
              <Badge variant={selectedAgency.agencyType === 'AUDIO_AGENCY' ? 'purple' : 'primary'}>
                {selectedAgency.agencyType === 'AUDIO_AGENCY' ? 'Social Audio Syndicate' : 'Live Video Agency'}
              </Badge>
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Total Talent Roster</p>
                <p className="text-sm font-bold text-white mt-0.5">{selectedAgency.hostsCount} Creators</p>
              </Card>
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Monthly gross volume</p>
                <p className="text-sm font-bold text-emerald-400 mt-0.5">{formatCurrency(selectedAgency.monthlyGrossUSD || 0)}</p>
              </Card>
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Commission split</p>
                <p className="text-sm font-bold text-purple-400 mt-0.5">{selectedAgency.commissionPercent}% share</p>
              </Card>
              <Card className="p-3 bg-slate-800/40">
                <p className="text-slate-400">Joined Platform</p>
                <p className="text-sm font-bold text-sky-400 mt-0.5">{selectedAgency.joinedAt}</p>
              </Card>
            </div>

            <div className="p-3.5 rounded-xl bg-slate-800/50 border border-slate-800 space-y-2">
              <span className="font-bold text-white flex items-center gap-1.5">
                <Building className="h-4 w-4 text-gold-400" />
                Settlement Details & Commission Routing
              </span>
              <div className="grid grid-cols-2 gap-4 bg-slate-900 p-3 rounded border border-slate-800">
                <div>
                  <p className="text-slate-400">Payment Gateway Method</p>
                  <p className="font-bold text-slate-200 mt-0.5">{selectedAgency.settlementMethod || 'Bank Wire Transfer'}</p>
                </div>
                <div>
                  <p className="text-slate-400">Tax ID / Incorporation ID</p>
                  <p className="font-bold text-slate-200 mt-0.5 font-mono">{selectedAgency.taxId || 'TAX-99812-XX'}</p>
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-slate-700">
              <Button variant="ghost" size="sm" onClick={() => setSelectedAgency(null)}>
                Close Details
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Transfer Host Modal */}
      {transferModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setTransferModal({ open: false, agency: null })}
          title={`Transfer Host from ${transferModal.agency.agencyName}`}
          size="sm"
        >
          <form onSubmit={handleExecuteTransfer} className="space-y-4 text-xs text-slate-300">
            <Input
              label="Host Creator Username / ID"
              value={transferHostName}
              onChange={(e) => setTransferHostName(e.target.value)}
              placeholder="e.g. luna_star"
              required
            />
            <Input
              label="Target Agency ID"
              value={targetAgencyId}
              onChange={(e) => setTargetAgencyId(e.target.value)}
              placeholder="e.g. agency-004"
              required
            />
            <Input
              label="Transfer Reason"
              value={transferReason}
              onChange={(e) => setTransferReason(e.target.value)}
              placeholder="e.g. Contract expiration & re-binding"
              required
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setTransferModal({ open: false, agency: null })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" type="submit">
                Execute Contract Transfer
              </Button>
            </div>
          </form>
        </Modal>
      )}

      {/* Commission Split Modal */}
      {commissionModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setCommissionModal({ open: false, agency: null, commission: '' })}
          title={`Configure Commission: ${commissionModal.agency?.agencyName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Commission share percentage (%)"
              type="number"
              value={commissionModal.commission}
              onChange={(e) => setCommissionModal({ ...commissionModal, commission: e.target.value })}
              placeholder="e.g. 15"
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setCommissionModal({ open: false, agency: null, commission: '' })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveCommission}>
                Update Commission Split
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Settlement Config Modal */}
      {settlementModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setSettlementModal({ open: false, agency: null, settlementMethod: '', taxId: '' })}
          title={`Configure Settlement: ${settlementModal.agency?.agencyName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Preferred Settlement Method"
              value={settlementModal.settlementMethod}
              onChange={(e) => setSettlementModal({ ...settlementModal, settlementMethod: e.target.value })}
              placeholder="Bank Wire, PayPal, USDT"
            />
            <Input
              label="Tax ID / Registration Number"
              value={settlementModal.taxId}
              onChange={(e) => setSettlementModal({ ...settlementModal, taxId: e.target.value })}
              placeholder="TAX-XXXX"
            />
            <div className="flex justify-end gap-2 pt-2">
              <Button variant="ghost" size="sm" onClick={() => setSettlementModal({ open: false, agency: null, settlementMethod: '', taxId: '' })}>
                Cancel
              </Button>
              <Button variant="primary" size="sm" onClick={handleSaveSettlement}>
                Save Configuration
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Assign/Remove Roster Modal */}
      {rosterModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setRosterModal({ open: false, agency: null, hostId: '' })}
          title={`Roster Management: ${rosterModal.agency?.agencyName}`}
          size="sm"
        >
          <div className="space-y-4 text-xs text-slate-300">
            <Input
              label="Creator Host ID"
              value={rosterModal.hostId}
              onChange={(e) => setRosterModal({ ...rosterModal, hostId: e.target.value })}
              placeholder="e.g. hst-101"
            />
            <div className="flex gap-2 justify-end pt-2">
              <Button variant="danger" size="sm" onClick={() => handleRosterAction('remove')}>
                Remove from Agency
              </Button>
              <Button variant="primary" size="sm" onClick={() => handleRosterAction('add')}>
                Bind to Agency
              </Button>
            </div>
          </div>
        </Modal>
      )}

      {/* Application Detail Modal */}
      {selectedAppModal && (
        <Modal
          isOpen={true}
          onClose={() => setSelectedAppModal(null)}
          title={`Application Details: ${selectedAppModal.agencyName}`}
          size="lg"
        >
          <div className="space-y-4 text-sm text-slate-300">
            <div className="p-4 rounded-xl bg-slate-900 border border-slate-800 grid grid-cols-2 gap-3">
              <div>
                <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Agency Name</p>
                <p className="font-semibold text-white">{selectedAppModal.agencyName}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">ZeParty ID</p>
                <p className="font-mono text-sky-400">{selectedAppModal.applicantZePartyId || '—'}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Applicant Username</p>
                <p>@{selectedAppModal.applicant?.username || '—'}</p>
              </div>
              <div>
                <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Phone Number</p>
                <p className="font-mono">{selectedAppModal.phoneNumber || '—'}</p>
              </div>
              <div className="col-span-2">
                <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Invitation / Motivation</p>
                <p className="text-slate-300 whitespace-pre-line">{selectedAppModal.description || '—'}</p>
              </div>
              <div className="col-span-2">
                <p className="text-xs text-slate-500 uppercase font-bold mb-1">External Host Reference IDs</p>
                <div className="flex flex-wrap gap-2">
                  {[selectedAppModal.hostRef1, selectedAppModal.hostRef2, selectedAppModal.hostRef3, selectedAppModal.hostRef4, selectedAppModal.hostRef5]
                    .filter(Boolean)
                    .map((ref, i) => (
                      <span key={i} className="px-2 py-0.5 bg-cyan-900/30 border border-cyan-700/40 text-cyan-400 text-xs font-mono rounded">
                        {ref}
                      </span>
                    ))}
                  {![selectedAppModal.hostRef1, selectedAppModal.hostRef2, selectedAppModal.hostRef3, selectedAppModal.hostRef4, selectedAppModal.hostRef5].some(Boolean) && (
                    <span className="text-slate-500 text-xs">None provided</span>
                  )}
                </div>
              </div>
              <div>
                <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Status</p>
                <StatusBadge status={selectedAppModal.status} />
              </div>
              <div>
                <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Submitted At</p>
                <p className="text-slate-400 text-xs">{formatDate(selectedAppModal.createdAt)}</p>
              </div>
              {selectedAppModal.reviewedAt && (
                <>
                  <div>
                    <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Reviewed At</p>
                    <p className="text-slate-400 text-xs">{formatDate(selectedAppModal.reviewedAt)}</p>
                  </div>
                  <div>
                    <p className="text-xs text-slate-500 uppercase font-bold mb-0.5">Reviewed By</p>
                    <p className="text-slate-400">{selectedAppModal.reviewedBy || '—'}</p>
                  </div>
                </>
              )}
              {selectedAppModal.rejectionReason && (
                <div className="col-span-2">
                  <p className="text-xs text-rose-500 uppercase font-bold mb-0.5">Rejection Reason</p>
                  <p className="text-rose-300">{selectedAppModal.rejectionReason}</p>
                </div>
              )}
            </div>
            {selectedAppModal.status === 'PENDING' && (
              <div className="flex gap-2 justify-end pt-1">
                <Button variant="success" size="sm" onClick={() => { handleApprove(selectedAppModal.id); setSelectedAppModal(null); }}>
                  Approve Application
                </Button>
                <Button variant="danger" size="sm" onClick={() => { handleOpenReject(selectedAppModal); setSelectedAppModal(null); }}>
                  Reject Application
                </Button>
              </div>
            )}
          </div>
        </Modal>
      )}

      {/* Reject Application Modal */}
      {rejectModal.open && (
        <Modal
          isOpen={true}
          onClose={() => setRejectModal({ open: false, application: null, reason: '' })}
          title={`Reject Application: ${rejectModal.application?.agencyName}`}
          size="sm"
        >
          <div className="space-y-4 text-sm text-slate-300">
            <p className="text-xs text-slate-400">
              The rejection reason will be stored in the application record and can be referenced by the applicant in future contact.
            </p>
            <Input
              label="Rejection Reason *"
              value={rejectModal.reason}
              onChange={(e) => setRejectModal({ ...rejectModal, reason: e.target.value })}
              placeholder="e.g. Insufficient host roster, incomplete information..."
            />
            <div className="flex gap-2 justify-end pt-1">
              <Button variant="ghost" size="sm" onClick={() => setRejectModal({ open: false, application: null, reason: '' })}>
                Cancel
              </Button>
              <Button
                variant="danger"
                size="sm"
                onClick={handleExecuteReject}
                disabled={!rejectModal.reason || rejectModal.reason.trim().length < 3}
              >
                Confirm Rejection
              </Button>
            </div>
          </div>
        </Modal>
      )}
    </div>
  );
}
