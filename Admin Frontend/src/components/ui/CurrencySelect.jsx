// ============================================================
// ZeParty Admin Portal — Searchable Currency Select Component
// ============================================================

import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Search, ChevronDown, Check, X, DollarSign } from 'lucide-react';
import { WORLD_CURRENCIES } from '../../constants/currencies.data';
import { CountryFlag } from './CountryFlag';

export function CurrencySelect({
  value = 'USD',
  onChange,
  label,
  className = '',
  containerClassName = '',
  placeholder = 'Select Currency'
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [dropUp, setDropUp] = useState(false);
  const containerRef = useRef(null);
  const searchInputRef = useRef(null);

  useEffect(() => {
    function handleClickOutside(event) {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleToggle = () => {
    if (!isOpen && containerRef.current) {
      const rect = containerRef.current.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      setDropUp(spaceBelow < 230 && rect.top > 220);
    }
    setIsOpen(!isOpen);
  };

  useEffect(() => {
    if (isOpen && searchInputRef.current) {
      searchInputRef.current.focus();
    }
  }, [isOpen]);

  const selectedOption = useMemo(() => {
    const val = (value || 'USD').toUpperCase();
    const found = WORLD_CURRENCIES.find((c) => c.code === val);
    return found || { code: val, name: val, symbol: '$', defaultCountry: 'US' };
  }, [value]);

  const filteredCurrencies = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return WORLD_CURRENCIES;

    return WORLD_CURRENCIES.filter(
      (c) =>
        c.code.toLowerCase().includes(q) ||
        c.name.toLowerCase().includes(q) ||
        (c.defaultCountry && c.defaultCountry.toLowerCase().includes(q))
    );
  }, [searchQuery]);

  const handleSelect = (currCode) => {
    if (onChange) {
      onChange(currCode);
    }
    setIsOpen(false);
    setSearchQuery('');
  };

  return (
    <div className={`flex flex-col gap-1.5 ${containerClassName}`}>
      {label && (
        <label className="text-xs font-medium text-slate-300">
          {label}
        </label>
      )}

      <div ref={containerRef} className="relative w-full">
        <button
          type="button"
          onClick={handleToggle}
          className={`w-full h-9 bg-slate-800 border border-slate-700 hover:border-slate-600 focus:border-gold-500 focus:ring-2 focus:ring-gold-500/30 text-xs font-semibold text-white rounded-lg px-3 py-1.5 flex items-center justify-between gap-2 transition-all focus:outline-none ${className}`}
        >
          <div className="flex items-center gap-2 truncate">
            {selectedOption.defaultCountry && (
              <CountryFlag code={selectedOption.defaultCountry} className="w-4 h-3 object-cover rounded-sm shrink-0" />
            )}
            <span className="font-mono text-purple-300 font-bold">{selectedOption.code}</span>
            <span className="text-slate-400 truncate text-[11px]">— {selectedOption.name}</span>
          </div>
          <ChevronDown className={`h-3.5 w-3.5 text-slate-400 shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
        </button>

        {isOpen && (
          <div
            className={`absolute left-0 w-full min-w-[240px] bg-slate-900 border border-slate-700/80 shadow-2xl rounded-xl z-50 overflow-hidden flex flex-col animate-in fade-in zoom-in-95 duration-100 ${
              dropUp ? 'bottom-full mb-1.5' : 'top-full mt-1.5'
            }`}
          >
            <div className="p-2 border-b border-slate-800 bg-slate-950/70 flex items-center gap-2">
              <Search className="h-3.5 w-3.5 text-slate-400 shrink-0 ml-1" />
              <input
                ref={searchInputRef}
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search currency code or name..."
                className="w-full bg-transparent text-xs text-white placeholder-slate-500 focus:outline-none py-0.5"
              />
              {searchQuery && (
                <button
                  type="button"
                  onClick={() => setSearchQuery('')}
                  className="p-0.5 text-slate-400 hover:text-white shrink-0"
                >
                  <X className="h-3.5 w-3.5" />
                </button>
              )}
            </div>

            <div className="max-h-48 overflow-y-auto p-1 divide-y divide-slate-800/40 custom-scrollbar">
              {filteredCurrencies.length === 0 ? (
                <div className="px-3 py-3 text-center text-xs text-slate-500">
                  No currencies found for "{searchQuery}"
                </div>
              ) : (
                filteredCurrencies.map((c) => {
                  const isSelected = c.code === selectedOption.code;
                  return (
                    <button
                      key={c.code}
                      type="button"
                      onClick={() => handleSelect(c.code)}
                      className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-lg text-xs transition-colors ${
                        isSelected
                          ? 'bg-purple-500/20 text-purple-300 font-bold'
                          : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                      }`}
                    >
                      <div className="flex items-center gap-2 truncate">
                        {c.defaultCountry && (
                          <CountryFlag code={c.defaultCountry} className="w-4 h-3 object-cover rounded-sm shrink-0" />
                        )}
                        <span className="font-mono font-bold text-white">{c.code}</span>
                        <span className="text-slate-400 truncate text-[11px]">{c.name}</span>
                      </div>
                      {isSelected && <Check className="h-3.5 w-3.5 text-purple-400 shrink-0 ml-2" />}
                    </button>
                  );
                })
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default CurrencySelect;
