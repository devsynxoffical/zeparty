// ============================================================
// ZeParty Admin Portal — Searchable Country Select Component
// ============================================================

import React, { useState, useRef, useEffect, useMemo } from 'react';
import { Search, ChevronDown, Check, X } from 'lucide-react';
import { ALL_COUNTRIES, GLOBAL_COUNTRY_OPTION } from '../../constants/countries.data';
import { CountryFlag } from './CountryFlag';

export function CountrySelect({
  value = 'All',
  onChange,
  label,
  className = '',
  containerClassName = '',
  placeholder = 'Select Country'
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [dropUp, setDropUp] = useState(false);
  const containerRef = useRef(null);
  const searchInputRef = useRef(null);

  // Close dropdown on click outside
  useEffect(() => {
    function handleClickOutside(event) {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    }
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  // Determine drop direction (up or down) based on position in window
  const handleToggle = () => {
    if (!isOpen && containerRef.current) {
      const rect = containerRef.current.getBoundingClientRect();
      const spaceBelow = window.innerHeight - rect.bottom;
      setDropUp(spaceBelow < 230 && rect.top > 220);
    }
    setIsOpen(!isOpen);
  };

  // Auto-focus search input when opened
  useEffect(() => {
    if (isOpen && searchInputRef.current) {
      searchInputRef.current.focus();
    }
  }, [isOpen]);

  // Find currently selected object
  const selectedOption = useMemo(() => {
    if (!value || value === 'All' || value === 'GLOBAL' || value === 'Global') {
      return GLOBAL_COUNTRY_OPTION;
    }
    const found = ALL_COUNTRIES.find(
      (c) => c.code.toLowerCase() === value.toLowerCase() || c.name.toLowerCase() === value.toLowerCase()
    );
    return found || { code: value, name: value };
  }, [value]);

  // Filter country list by search query
  const filteredCountries = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return ALL_COUNTRIES;

    return ALL_COUNTRIES.filter((c) => {
      if (c.code === 'All') {
        return 'global'.includes(q) || 'all'.includes(q);
      }
      return (
        c.name.toLowerCase().includes(q) ||
        c.code.toLowerCase().includes(q)
      );
    });
  }, [searchQuery]);

  const handleSelect = (countryCode) => {
    if (onChange) {
      onChange(countryCode);
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
        {/* Trigger Button */}
        <button
          type="button"
          onClick={handleToggle}
          className={`w-full h-9 bg-slate-800 border border-slate-700 hover:border-slate-600 focus:border-gold-500 focus:ring-2 focus:ring-gold-500/30 text-xs font-semibold text-white rounded-lg px-3 py-1.5 flex items-center justify-between gap-2 transition-all focus:outline-none ${className}`}
        >
          <div className="flex items-center gap-2 truncate">
            <CountryFlag code={selectedOption.code} className="w-4 h-3 object-cover rounded-sm shrink-0" />
            <span className="truncate">{selectedOption.name}</span>
          </div>
          <ChevronDown className={`h-3.5 w-3.5 text-slate-400 shrink-0 transition-transform ${isOpen ? 'rotate-180' : ''}`} />
        </button>

        {/* Popover Menu */}
        {isOpen && (
          <div
            className={`absolute left-0 w-full min-w-[210px] bg-slate-900 border border-slate-700/80 shadow-2xl rounded-xl z-50 overflow-hidden flex flex-col animate-in fade-in zoom-in-95 duration-100 ${
              dropUp ? 'bottom-full mb-1.5' : 'top-full mt-1.5'
            }`}
          >
            {/* Search Box */}
            <div className="p-2 border-b border-slate-800 bg-slate-950/70 flex items-center gap-2">
              <Search className="h-3.5 w-3.5 text-slate-400 shrink-0 ml-1" />
              <input
                ref={searchInputRef}
                type="text"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                placeholder="Search country..."
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

            {/* Options List */}
            <div className="max-h-44 overflow-y-auto p-1 divide-y divide-slate-800/40 custom-scrollbar">
              {filteredCountries.length === 0 ? (
                <div className="px-3 py-3 text-center text-xs text-slate-500">
                  No countries found for "{searchQuery}"
                </div>
              ) : (
                filteredCountries.map((cnt) => {
                  const isSelected =
                    (cnt.code === 'All' && (selectedOption.code === 'All' || selectedOption.code === 'GLOBAL')) ||
                    cnt.code.toLowerCase() === selectedOption.code.toLowerCase();

                  return (
                    <button
                      key={cnt.code}
                      type="button"
                      onClick={() => handleSelect(cnt.code)}
                      className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-lg text-xs transition-colors ${
                        isSelected
                          ? 'bg-red-500/20 text-red-400 font-bold'
                          : 'text-slate-300 hover:bg-slate-800 hover:text-white'
                      }`}
                    >
                      <div className="flex items-center gap-2 truncate">
                        <CountryFlag code={cnt.code} className="w-4 h-3 object-cover rounded-sm shrink-0" />
                        <span className="truncate">{cnt.name}</span>
                      </div>

                      {isSelected && <Check className="h-3.5 w-3.5 text-red-400 shrink-0 ml-2" />}
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
