import { ScannedDocument } from '../types';

const STORAGE_KEY = 'writescan_ai_documents_v1';
const SETTINGS_KEY = 'writescan_ai_settings_v1';

export interface AppSettings {
  defaultLanguage: string;
  imageRetention: 'keep_all' | 'keep_thumbnail' | 'none';
  theme: 'light' | 'dark' | 'system';
  viewMode: 'phone' | 'full';
  autoCopyOnScan: boolean;
}

export const DEFAULT_SETTINGS: AppSettings = {
  defaultLanguage: 'auto',
  imageRetention: 'keep_thumbnail',
  theme: 'light',
  viewMode: 'full',
  autoCopyOnScan: false,
};

export function getSavedDocuments(): ScannedDocument[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw);
  } catch (err) {
    console.error('Failed to load documents from localStorage:', err);
    return [];
  }
}

export function saveDocument(doc: ScannedDocument): void {
  try {
    const docs = getSavedDocuments();
    const existingIdx = docs.findIndex((d) => d.id === doc.id);
    if (existingIdx >= 0) {
      docs[existingIdx] = doc;
    } else {
      docs.unshift(doc);
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(docs));
  } catch (err) {
    console.error('Failed to save document:', err);
  }
}

export function deleteDocument(id: string): void {
  try {
    const docs = getSavedDocuments().filter((d) => d.id !== id);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(docs));
  } catch (err) {
    console.error('Failed to delete document:', err);
  }
}

export function duplicateDocument(id: string): ScannedDocument | null {
  try {
    const docs = getSavedDocuments();
    const orig = docs.find((d) => d.id === id);
    if (!orig) return null;

    const copy: ScannedDocument = {
      ...orig,
      id: 'doc_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      title: `${orig.title} (Copy)`,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    docs.unshift(copy);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(docs));
    return copy;
  } catch (err) {
    console.error('Failed to duplicate document:', err);
    return null;
  }
}

export function clearAllDocuments(): void {
  try {
    localStorage.removeItem(STORAGE_KEY);
  } catch (err) {
    console.error('Failed to clear documents:', err);
  }
}

export function getAppSettings(): AppSettings {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return DEFAULT_SETTINGS;
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function saveAppSettings(settings: Partial<AppSettings>): AppSettings {
  try {
    const current = getAppSettings();
    const updated = { ...current, ...settings };
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(updated));
    return updated;
  } catch {
    return DEFAULT_SETTINGS;
  }
}
