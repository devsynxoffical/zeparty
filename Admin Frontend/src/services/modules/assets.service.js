// ============================================================
// ZeParty Admin Portal — Asset Management Service (Mock)
// ============================================================

let assetsState = [
  {
    id: 'ast-gif-01',
    name: 'Dragon Flame',
    category: 'GIFTS',
    subCategory: 'Animated',
    price: 5000,
    status: 'active',
    roomAvailability: 'Both',
    thumbnail: 'https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=120&auto=format&fit=crop&q=60',
    duration: 5,
    volume: 80,
    comboSupport: true,
    comboCount: 99,
    fullScreen: true,
    priority: 1,
    startDate: '',
    endDate: '',
    assignment: 'All',
    updatedAt: '2026-08-20T10:00:00Z',
    history: [
      { timestamp: '2026-08-20T10:00:00Z', operator: 'Super Admin', action: 'Created', details: 'Initial asset release.', before: null, after: 'Active' }
    ]
  },
  {
    id: 'ast-gif-02',
    name: 'Lion Dance',
    category: 'GIFTS',
    subCategory: 'Video',
    price: 10000,
    status: 'active',
    roomAvailability: 'Both',
    thumbnail: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=120&auto=format&fit=crop&q=60',
    duration: 8,
    volume: 70,
    comboSupport: true,
    comboCount: 10,
    fullScreen: true,
    priority: 2,
    startDate: '',
    endDate: '',
    assignment: 'All',
    updatedAt: '2026-08-19T08:30:00Z',
    history: [
      { timestamp: '2026-08-19T08:30:00Z', operator: 'Super Admin', action: 'Created', details: 'Added animated video gift.', before: null, after: 'Active' }
    ]
  },
  {
    id: 'ast-frm-01',
    name: 'SVIP Level 5 Golden Ring',
    category: 'VIP_SVIP_FRAMES',
    subCategory: 'SVIP 5',
    price: 0,
    status: 'active',
    roomAvailability: 'Both',
    thumbnail: 'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=120&auto=format&fit=crop&q=60',
    duration: 0,
    volume: 0,
    comboSupport: false,
    comboCount: 1,
    fullScreen: false,
    priority: 5,
    startDate: '',
    endDate: '',
    assignment: 'SVIP 5',
    updatedAt: '2026-08-18T14:20:00Z',
    history: [
      { timestamp: '2026-08-18T14:20:00Z', operator: 'Super Admin', action: 'Created', details: 'Created exclusive SVIP level 5 avatar border.', before: null, after: 'Active' }
    ]
  },
  {
    id: 'ast-bdg-01',
    name: 'Official Merchant Badge',
    category: 'BADGES',
    subCategory: 'Merchant',
    price: 0,
    status: 'active',
    roomAvailability: 'Both',
    thumbnail: 'https://images.unsplash.com/photo-1614850523459-c2f4c699c52e?w=120&auto=format&fit=crop&q=60',
    duration: 0,
    volume: 0,
    comboSupport: false,
    comboCount: 1,
    fullScreen: false,
    priority: 10,
    startDate: '',
    endDate: '',
    assignment: 'Merchant',
    updatedAt: '2026-08-15T09:00:00Z',
    history: [
      { timestamp: '2026-08-15T09:00:00Z', operator: 'Super Admin', action: 'Created', details: 'Merchant verification badge configuration.', before: null, after: 'Active' }
    ]
  },
  {
    id: 'ast-tag-01',
    name: 'Noble Crown Tag',
    category: 'TAGS',
    subCategory: 'Noble',
    price: 0,
    status: 'active',
    roomAvailability: 'Both',
    thumbnail: 'https://images.unsplash.com/photo-1589156280159-27698a70f29e?w=120&auto=format&fit=crop&q=60',
    duration: 0,
    volume: 0,
    comboSupport: false,
    comboCount: 1,
    fullScreen: false,
    priority: 8,
    startDate: '',
    endDate: '',
    assignment: 'Noble',
    updatedAt: '2026-08-10T12:00:00Z',
    history: [
      { timestamp: '2026-08-10T12:00:00Z', operator: 'Super Admin', action: 'Created', details: 'Noble badge tag asset.', before: null, after: 'Active' }
    ]
  },
  {
    id: 'ast-bub-01',
    name: 'Neon Cyber Bubble',
    category: 'CHAT_BUBBLES',
    subCategory: 'Premium',
    price: 250,
    status: 'active',
    roomAvailability: 'Both',
    thumbnail: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?w=120&auto=format&fit=crop&q=60',
    duration: 30,
    volume: 0,
    comboSupport: false,
    comboCount: 1,
    fullScreen: false,
    priority: 12,
    startDate: '',
    endDate: '',
    assignment: 'All',
    updatedAt: '2026-08-17T11:45:00Z',
    history: [
      { timestamp: '2026-08-17T11:45:00Z', operator: 'Super Admin', action: 'Created', details: 'Premium neon bubble design.', before: null, after: 'Active' }
    ]
  },
  {
    id: 'ast-bag-01',
    name: 'Mystery Lucky Bag',
    category: 'BAGS',
    subCategory: 'Mystery',
    price: 500,
    status: 'scheduled',
    roomAvailability: 'Both',
    thumbnail: 'https://images.unsplash.com/photo-1513151233558-d860c5398176?w=120&auto=format&fit=crop&q=60',
    duration: 0,
    volume: 0,
    comboSupport: false,
    comboCount: 1,
    fullScreen: false,
    priority: 20,
    startDate: '2026-09-01',
    endDate: '2026-09-30',
    assignment: 'All',
    updatedAt: '2026-08-20T16:00:00Z',
    history: [
      { timestamp: '2026-08-20T16:00:00Z', operator: 'Super Admin', action: 'Created', details: 'Configured special holiday reward lucky bag.', before: null, after: 'Scheduled' }
    ]
  },
  {
    id: 'ast-eff-01',
    name: 'Phoenix Flight Entry',
    category: 'ENTRY_EFFECTS',
    subCategory: 'Noble',
    price: 0,
    status: 'active',
    roomAvailability: 'Audio',
    thumbnail: 'https://images.unsplash.com/photo-1541701494587-cb58502866ab?w=120&auto=format&fit=crop&q=60',
    duration: 6,
    volume: 50,
    comboSupport: false,
    comboCount: 1,
    fullScreen: true,
    priority: 3,
    startDate: '',
    endDate: '',
    assignment: 'Noble',
    updatedAt: '2026-08-12T15:10:00Z',
    history: [
      { timestamp: '2026-08-12T15:10:00Z', operator: 'Super Admin', action: 'Created', details: 'Noble tier specialized audio-room entrance transition.', before: null, after: 'Active' }
    ]
  }
];

export async function getAssets() {
  await new Promise((res) => setTimeout(res, 150));
  return [...assetsState];
}

export async function getAssetById(id) {
  await new Promise((res) => setTimeout(res, 100));
  return assetsState.find((a) => a.id === id) || null;
}

export async function addAsset(asset, operatorName = 'Super Admin') {
  await new Promise((res) => setTimeout(res, 250));
  const newAsset = {
    ...asset,
    id: asset.id || `ast-${Date.now()}`,
    updatedAt: new Date().toISOString(),
    history: [
      {
        timestamp: new Date().toISOString(),
        operator: operatorName,
        action: 'Created',
        details: 'Initial asset setup and parameters publication.',
        before: null,
        after: asset.status || 'draft'
      }
    ]
  };
  assetsState = [newAsset, ...assetsState];
  return newAsset;
}

export async function updateAsset(id, updatedFields, operatorName = 'Super Admin', changeReason = 'Updated asset settings') {
  await new Promise((res) => setTimeout(res, 250));
  let oldAsset = null;
  let newAsset = null;

  assetsState = assetsState.map((a) => {
    if (a.id === id) {
      oldAsset = { ...a };
      const historyRecord = {
        timestamp: new Date().toISOString(),
        operator: operatorName,
        action: 'Edited',
        details: changeReason,
        before: JSON.stringify(a.status),
        after: JSON.stringify(updatedFields.status || a.status)
      };
      newAsset = {
        ...a,
        ...updatedFields,
        updatedAt: new Date().toISOString(),
        history: [historyRecord, ...(a.history || [])]
      };
      return newAsset;
    }
    return a;
  });

  return newAsset;
}

export async function deleteAsset(id) {
  await new Promise((res) => setTimeout(res, 200));
  assetsState = assetsState.filter((a) => a.id !== id);
  return { success: true };
}

export async function replaceAssetFile(id, fileInfo, operatorName = 'Super Admin') {
  await new Promise((res) => setTimeout(res, 300));
  let updatedAsset = null;
  assetsState = assetsState.map((a) => {
    if (a.id === id) {
      const historyRecord = {
        timestamp: new Date().toISOString(),
        operator: operatorName,
        action: 'Replaced Asset File',
        details: `Replaced media file: ${fileInfo.fileName}`,
        before: 'Previous Media File',
        after: fileInfo.fileName
      };
      updatedAsset = {
        ...a,
        updatedAt: new Date().toISOString(),
        history: [historyRecord, ...(a.history || [])]
      };
      return updatedAsset;
    }
    return a;
  });
  return updatedAsset;
}
