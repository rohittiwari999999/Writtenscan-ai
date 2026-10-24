import React, { useState } from 'react';
import {
  Settings,
  Shield,
  Trash2,
  CheckCircle2,
  AlertTriangle,
  RefreshCw,
  Globe,
  Database,
  Info,
  Server,
  Key,
} from 'lucide-react';
import { BackendHealth } from '../types';
import { LANGUAGES } from '../constants/languages';
import { AppSettings } from '../services/storage';

interface SettingsTabProps {
  health: BackendHealth | null;
  onRefreshHealth: () => void;
  settings: AppSettings;
  onUpdateSettings: (settings: Partial<AppSettings>) => void;
  onClearHistory: () => void;
}

export const SettingsTab: React.FC<SettingsTabProps> = ({
  health,
  onRefreshHealth,
  settings,
  onUpdateSettings,
  onClearHistory,
}) => {
  const [clearedNotice, setClearedNotice] = useState(false);

  const handleClear = () => {
    if (window.confirm('Are you sure you want to delete all saved scan history? This action cannot be undone.')) {
      onClearHistory();
      setClearedNotice(true);
      setTimeout(() => setClearedNotice(false), 3000);
    }
  };

  return (
    <div className="flex-1 p-4 sm:p-6 max-w-4xl mx-auto w-full flex flex-col space-y-6">
      {/* Header */}
      <div>
        <h2 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
          <span>Settings &amp; System Diagnostics</span>
        </h2>
        <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
          OCR Provider status, recognition defaults, and privacy preferences
        </p>
      </div>

      {/* 1. OCR Engine Provider Diagnostics */}
      <div className="bg-white dark:bg-slate-800 rounded-2xl p-5 border border-slate-200 dark:border-slate-700/60 shadow-sm space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 dark:border-slate-700 pb-3">
          <div className="flex items-center space-x-2.5">
            <Server className="w-5 h-5 text-blue-600 dark:text-blue-400" />
            <h3 className="font-bold text-sm text-slate-900 dark:text-white">
              Handwriting OCR Engine Status
            </h3>
          </div>

          <button
            onClick={onRefreshHealth}
            className="flex items-center space-x-1 text-xs text-blue-600 dark:text-blue-400 hover:underline"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Check Connectivity</span>
          </button>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
          <div className="bg-slate-50 dark:bg-slate-900/60 p-3.5 rounded-xl">
            <span className="text-slate-400 block mb-1">OCR Engine &amp; Vision Model</span>
            <span className="font-semibold text-slate-800 dark:text-slate-200 text-sm">
              {health?.ocrProvider || 'Gemini Vision 3.8 Flash'}
            </span>
          </div>

          <div className="bg-slate-50 dark:bg-slate-900/60 p-3.5 rounded-xl">
            <span className="text-slate-400 block mb-1">API Key &amp; Environment</span>
            <div className="flex items-center space-x-2">
              {health?.configured ? (
                <span className="flex items-center text-emerald-600 font-semibold">
                  <CheckCircle2 className="w-4 h-4 mr-1" /> Configured &amp; Active
                </span>
              ) : (
                <span className="flex items-center text-amber-600 font-semibold">
                  <AlertTriangle className="w-4 h-4 mr-1" /> Not Configured in Secrets
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="text-xs text-slate-500 dark:text-slate-400 bg-blue-50/50 dark:bg-blue-950/20 p-3 rounded-xl border border-blue-100 dark:border-blue-900/40">
          <p className="flex items-start gap-1.5">
            <Info className="w-4 h-4 text-blue-500 shrink-0 mt-0.5" />
            <span>
              Real OCR is powered by Gemini 3.8 Flash with specialized document prompt engineering for
              handwriting transcription, Latin cursive, and Indian languages (Devanagari, Tamil, Bengali, Telugu, Gujarati, Kannada, Malayalam, Gurmukhi, Nastaliq).
            </span>
          </p>
        </div>
      </div>

      {/* 2. Preferences */}
      <div className="bg-white dark:bg-slate-800 rounded-2xl p-5 border border-slate-200 dark:border-slate-700/60 shadow-sm space-y-4">
        <div className="flex items-center space-x-2.5 border-b border-slate-100 dark:border-slate-700 pb-3">
          <Globe className="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
          <h3 className="font-bold text-sm text-slate-900 dark:text-white">
            Default Language &amp; Image Retention
          </h3>
        </div>

        <div className="space-y-4 text-xs">
          <div>
            <label className="font-semibold text-slate-800 dark:text-slate-200 block mb-1.5">
              Default Recognition Language
            </label>
            <select
              value={settings.defaultLanguage}
              onChange={(e) => onUpdateSettings({ defaultLanguage: e.target.value })}
              className="w-full sm:w-80 bg-slate-50 dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-xl p-2.5 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {LANGUAGES.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name} ({lang.nativeName}) — {lang.script}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="font-semibold text-slate-800 dark:text-slate-200 block mb-1.5">
              Document Image Storage Retention
            </label>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
              {[
                { id: 'keep_thumbnail', name: 'Save Thumbnails', desc: 'Saves text & small preview thumbnail' },
                { id: 'keep_all', name: 'Keep Full Photos', desc: 'Preserves full-resolution images' },
                { id: 'none', name: 'Text Only', desc: 'Zero images kept locally; text only' },
              ].map((opt) => (
                <button
                  key={opt.id}
                  onClick={() =>
                    onUpdateSettings({ imageRetention: opt.id as AppSettings['imageRetention'] })
                  }
                  className={`p-3 rounded-xl border text-left transition-all ${
                    settings.imageRetention === opt.id
                      ? 'border-blue-500 bg-blue-50/60 dark:bg-blue-900/30 text-blue-900 dark:text-blue-200'
                      : 'border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50'
                  }`}
                >
                  <div className="font-bold">{opt.name}</div>
                  <div className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">{opt.desc}</div>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* 3. Privacy & Security */}
      <div className="bg-white dark:bg-slate-800 rounded-2xl p-5 border border-slate-200 dark:border-slate-700/60 shadow-sm space-y-4">
        <div className="flex items-center space-x-2.5 border-b border-slate-100 dark:border-slate-700 pb-3">
          <Shield className="w-5 h-5 text-emerald-600 dark:text-emerald-400" />
          <h3 className="font-bold text-sm text-slate-900 dark:text-white">
            Privacy &amp; Data Security Pledge
          </h3>
        </div>

        <div className="space-y-2 text-xs text-slate-600 dark:text-slate-300">
          <p>
            • <strong>Zero Cloud Retention:</strong> Images submitted for handwriting OCR are processed entirely in-memory and discarded immediately upon response. No user photos or scanned notes are stored on the server.
          </p>
          <p>
            • <strong>Local-First Storage:</strong> Your scanned documents and transcribed texts are saved only in your device local storage (IndexedDB/SQLite).
          </p>
          <p>
            • <strong>Zero Analytics Tracking:</strong> User images, extracted personal records, and confidential notes are never transmitted to third-party ad networks or analytics trackers.
          </p>
        </div>

        <div className="pt-3 border-t border-slate-100 dark:border-slate-700 flex items-center justify-between">
          <div>
            <span className="font-semibold text-xs text-red-600 dark:text-red-400 block">
              Danger Zone
            </span>
            <span className="text-[11px] text-slate-400">
              Permanently wipe all locally saved scanned documents and cache.
            </span>
          </div>

          <button
            onClick={handleClear}
            className="flex items-center space-x-1.5 px-3 py-2 rounded-xl bg-red-50 dark:bg-red-950/40 text-red-600 dark:text-red-400 border border-red-200 dark:border-red-800 hover:bg-red-100 text-xs font-semibold transition-colors"
          >
            <Trash2 className="w-3.5 h-3.5" />
            <span>Clear All History</span>
          </button>
        </div>

        {clearedNotice && (
          <p className="text-xs text-emerald-600 font-semibold text-right">
            ✓ Document history has been cleared!
          </p>
        )}
      </div>

      {/* App Version Info */}
      <div className="text-center text-xs text-slate-400 py-2">
        WriteScan AI • Version 2.4.0 • Material 3 Android Architecture
      </div>
    </div>
  );
};
