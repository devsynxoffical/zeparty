// ============================================================
// ZeParty Admin Portal — DataTable Foundation (JSX)
// ============================================================

import React from 'react';
import { EmptyState, ErrorState, LoadingState } from '../common/States';

export function DataTable({
  columns = [],
  data = [],
  isLoading = false,
  isError = false,
  errorMessage = 'Failed to load data',
  onRetry,
  emptyTitle = 'No records found',
  emptyDescription = 'No data available for this view.',
  pagination,
  onPageChange,
  className = '',
}) {
  if (isLoading) {
    return <LoadingState message="Loading data..." />;
  }

  if (isError) {
    return <ErrorState title={errorMessage} onRetry={onRetry} />;
  }

  if (!data || data.length === 0) {
    return <EmptyState title={emptyTitle} description={emptyDescription} />;
  }

  return (
    <div className={['flex flex-col gap-4', className].join(' ')}>
      <div className="overflow-x-auto rounded-xl border border-slate-700/60 bg-slate-800/40">
        <table className="w-full text-left text-xs text-slate-300">
          <thead className="bg-slate-900/60 text-[11px] uppercase tracking-wider text-slate-400 border-b border-slate-700/60">
            <tr>
              {columns.map((col, idx) => (
                <th key={col.key || idx} className="px-3.5 py-2.5 font-semibold">
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-700/40">
            {data.map((row, rowIdx) => (
              <tr key={row.id || rowIdx} className="hover:bg-slate-700/20 transition-colors">
                {columns.map((col, colIdx) => (
                  <td key={col.key || colIdx} className="px-3.5 py-2.5 whitespace-nowrap">
                    {col.render ? col.render(row) : row[col.accessor]}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {pagination && (
        <div className="flex items-center justify-between px-2 text-xs text-slate-400">
          <span>
            Page {pagination.page} of {pagination.totalPages} ({pagination.total} total)
          </span>
          <div className="flex gap-2">
            <button
              disabled={pagination.page <= 1}
              onClick={() => onPageChange && onPageChange(pagination.page - 1)}
              className="px-3 py-1 rounded bg-slate-800 border border-slate-700 disabled:opacity-40 hover:bg-slate-700 transition-colors"
            >
              Previous
            </button>
            <button
              disabled={pagination.page >= pagination.totalPages}
              onClick={() => onPageChange && onPageChange(pagination.page + 1)}
              className="px-3 py-1 rounded bg-slate-800 border border-slate-700 disabled:opacity-40 hover:bg-slate-700 transition-colors"
            >
              Next
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
