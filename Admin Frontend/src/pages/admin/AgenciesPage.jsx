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
  approveAgency,
  rejectAgency,
  transferHostAgency
} from '../../services/modules/agencies.service';
import { formatDate, formatNumber, formatCurrency } from '../../utils/format';
import { CountryFlag } from '../../components/ui/CountryFlag';
import { getCountryShortName } from '../../constants/countries.data';
import { usePermission } from '../../hooks/usePermission';
import { useAuditLog } from '../../context/AuditLogContext';
import { MOCK_AGENCIES_LIST } from '../../mocks/hosts.mock';

export function AgenciesPage() {
  const { logAdminAction } = useAuditLog();
  const [searchParams, setSearchParams] = useSearchParams();
  const typeParam = searchParams.get('type') || 'live';

  const [activeTab, setActiveTab] = useState('activeAgencies'); // 'activeAgencies' | 'applications'
  const [agencies, setAgencies] = useState(MOCK_AGENCIES_LIST);
  const [applications, setApplications] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [selectedAgency, setSelectedAgency] = useState(null);
  
  // Modals
  const [transferModal, setTransferModal] = useState({ open: false, agency: null });
  const [transferHostName, setTransferHostName] = useState('');
  const [targetAgencyId, setTargetAgencyId] = useState('');
  const [transferReason, setTransferReason] = useState('');
  
  const [commissionModal, setCommissionModal] = useState({ open: false, agency: null, commission: '' });
  const [settlementModal, setSettlementModal] = useState({ open: false, agency: null, settlementMethod: '', taxId: '' });
  const [rosterModal, setRosterModal] = useState({ open: false, agency: null, hostId: '' });
  const [feedback, setFeedback] = useState(null);

  useEffect(() => {
    Promise.all([getActiveAgencies(), getAgencies()])
      .then(([active, apps]) => {
        setAgencies(active);
        setApplications(apps);
      })
      .finally(() => setIsLoading(false));
  }, []);

  const showFeedback = (msg) => {
    setFeedback(msg);
    setTimeout(() => setFeedback(null), 3500);
  };

  const activeCategory = typeParam === 'audio' ? 'AUDIO_AGENCY' : 'LIVE_AGENCY';

  const handleApprove = async (id) => {
    await approveAgency(id);
    setApplications((prev) =>
      prev.map((a) => (a.id === id ? { ...a, status: 'approved' } : a))
    );
    await logAdminAction({
      action: 'AGENCY_APPLICATION_APPROVED',
      module: 'Agencies',
      targetType: 'agency',
      targetId: id,
      targetName: `Agency ${id}`,
      reason: 'Approved agency onboarding application',
      riskLevel: 'HIGH',
    });
    showFeedback(`Agency application ${id} approved.`);
  };

  const handleReject = async (id) => {
    await rejectAgency(id, 'Document verification failed.');
    setApplications((prev) =>
      prev.map((a) => (a.id === id ? { ...a, status: 'rejected' } : a))
    );
    await logAdminAction({
      action: 'AGENCY_APPLICATION_REJECTED',
      module: 'Agencies',
      targetType: 'agency',
      targetId: id,
      targetName: `Agency ${id}`,
      reason: 'Rejected agency onboarding application',
      riskLevel: 'MEDIUM',
    });
    showFeedback(`Agency application ${id} rejected.`);
  };

  const handleExecuteTransfer = async (e) => {
    e.preventDefault();
    if (!transferModal.agency || !targetAgencyId || !transferHostName) return;

    const targetAgency = agencies.find((a) => a.id === targetAgencyId);

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

    setAgencies((prev) =>
      prev.map((a) => {
        if (a.id === transferModal.agency.id) {
          return { ...a, hostsCount: Math.max(0, a.hostsCount - 1) };
        }
        if (a.id === targetAgencyId) {
          return { ...a, hostsCount: a.hostsCount + 1 };
        }
        return a;
      })
    );

    showFeedback(`Host "${transferHostName}" successfully transferred.`);
    setTransferModal({ open: false, agency: null });
    setTransferHostName('');
    setTargetAgencyId('');
    setTransferReason('');
  };

  const handleSaveCommission = async () => {
    const { agency, commission } = commissionModal;
    if (!agency) return;

    setAgencies((prev) => prev.map((a) => {
      if (a.id === agency.id) {
        return { ...a, commissionPercent: Number(commission) };
      }
      return a;
    }));

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
  };

  const handleSaveSettlement = async () => {
    const { agency, settlementMethod, taxId } = settlementModal;
    if (!agency) return;

    setAgencies((prev) => prev.map((a) => {
      if (a.id === agency.id) {
        return { ...a, settlementMethod, taxId };
      }
      return a;
    }));

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
      const matchType = a.agencyType === activeCategory;
      const matchStatus = statusFilter === 'all' || a.status === statusFilter;
      const matchSearch =
        !q ||
        a.id.toLowerCase().includes(q) ||
        a.agencyName.toLowerCase().includes(q);
      return matchType && matchStatus && matchSearch;
    });
  }, [applications, activeCategory, statusFilter, search]);

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
          <p className="text-xs text-slate-400">Contact: {row.contactName} · {row.contactEmail}</p>
        </div>
      ),
    },
    {
      key: 'hostsCount',
      header: 'Proposed Talent Roster',
      render: (row) => <span className="text-xs text-sky-400 font-bold">{row.hostsCount} Creators</span>,
    },
    {
      key: 'country',
      header: 'Country',
      render: (row) => (
        <div className="flex items-center gap-1.5 text-xs font-semibold text-slate-300">
          <CountryFlag code={row.country} className="w-3.5 h-2.5 object-cover rounded-sm shrink-0" />
          <span>{getCountryShortName(row.country)}</span>
        </div>
      ),
    },
    {
      key: 'submittedAt',
      header: 'Submitted',
      render: (row) => <span className="text-xs text-slate-400">{formatDate(row.submittedAt)}</span>,
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
        row.status === 'pending' ? (
          <div className="flex gap-2">
            <Button variant="primary" size="xs" onClick={() => handleApprove(row.id)}>
              Approve
            </Button>
            <Button variant="danger" size="xs" onClick={() => handleReject(row.id)}>
              Reject
            </Button>
          </div>
        ) : (
          <span className="text-xs text-slate-500 capitalize">{row.status}</span>
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

        <div className="flex bg-slate-900 rounded-xl p-1 border border-slate-800">
          <button
            onClick={() => setSearchParams({ type: 'live' })}
            className={`px-4 py-1.5 text-xs font-bold rounded-lg transition-colors ${
              typeParam === 'live' ? 'bg-purple-600 text-white shadow shadow-purple-600/20' : 'text-slate-400 hover:text-white'
            }`}
          >
            Live Video Agencies
          </button>
          <button
            onClick={() => setSearchParams({ type: 'audio' })}
            className={`px-4 py-1.5 text-xs font-bold rounded-lg transition-colors ${
              typeParam === 'audio' ? 'bg-indigo-600 text-white shadow shadow-indigo-600/20' : 'text-slate-400 hover:text-white'
            }`}
          >
            Social Audio Agencies
          </button>
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
          onClick={() => { setActiveTab('activeAgencies'); setSearch(''); }}
          className={`pb-3 text-sm font-semibold transition-colors border-b-2 ${
            activeTab === 'activeAgencies' ? 'text-gold-400 border-gold-500' : 'text-slate-400 border-transparent hover:text-white'
          }`}
        >
          Licensed Agencies ({filteredActive.length})
        </button>
        <button
          onClick={() => { setActiveTab('applications'); setSearch(''); }}
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
    </div>
  );
}
