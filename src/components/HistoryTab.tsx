import React, { useState } from 'react';
import {
  Search,
  FileText,
  Clock,
  Trash2,
  Copy,
  Download,
  Edit3,
  ExternalLink,
  CheckCircle2,
  AlertCircle,
  FileDown,
  Sparkles,
} from 'lucide-react';
import { ScannedDocument } from '../types';
import { exportDocumentToPdf } from '../services/pdfExport';

interface HistoryTabProps {
  documents: ScannedDocument[];
  onOpenDocument: (doc: ScannedDocument) => void;
  onDeleteDocument: (id: string) => void;
  onDuplicateDocument: (id: string) => void;
  onNewScan: () => void;
}

export const HistoryTab: React.FC<HistoryTabProps> = ({
  documents,
  onOpenDocument,
  onDeleteDocument,
  onDuplicateDocument,
  onNewScan,
}) => {
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedLanguageFilter, setSelectedLanguageFilter] = useState('all');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Filter documents
  const filteredDocs = documents.filter((doc) => {
    const matchesSearch =
      doc.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      doc.editedText.toLowerCase().includes(searchTerm.toLowerCase()) ||
      doc.rawText.toLowerCase().includes(searchTerm.toLowerCase());

    const matchesLang =
      selectedLanguageFilter === 'all' ||
      doc.detectedLanguage.toLowerCase().includes(selectedLanguageFilter.toLowerCase());

    return matchesSearch && matchesLang;
  });

  // Extract unique languages
  const availableLangs = Array.from(new Set(documents.map((d) => d.detectedLanguage))).filter(Boolean);

  const handleCopyText = (doc: ScannedDocument) => {
    navigator.clipboard.writeText(doc.editedText || doc.rawText);
    setCopiedId(doc.id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleDeleteWithConfirm = (doc: ScannedDocument) => {
    if (window.confirm(`Are you sure you want to delete "${doc.title}"?`)) {
      onDeleteDocument(doc.id);
    }
  };

  return (
    <div className="flex-1 p-4 sm:p-6 max-w-5xl mx-auto w-full flex flex-col space-y-5">
      {/* Top Banner */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <span>Saved Document History</span>
            <span className="text-xs px-2.5 py-0.5 rounded-full bg-blue-100 text-blue-800 dark:bg-blue-900/60 dark:text-blue-300 font-semibold">
              {documents.length} Total
            </span>
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
            Locally stored handwritten transcriptions and documents
          </p>
        </div>

        <button
          onClick={onNewScan}
          className="self-start sm:self-auto px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold shadow-md shadow-blue-500/20 transition-all"
        >
          + Scan New Note
        </button>
      </div>

      {/* Search & Filter Controls */}
      <div className="flex flex-col sm:flex-row gap-3">
        {/* Search Bar */}
        <div className="flex-1 relative">
          <input
            type="text"
            placeholder="Search by title, handwritten text, or keywords..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="w-full pl-9 pr-4 py-2.5 rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-sm text-slate-900 dark:text-white placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3.5" />
        </div>

        {/* Language Filter */}
        {availableLangs.length > 0 && (
          <div className="flex items-center space-x-2">
            <select
              value={selectedLanguageFilter}
              onChange={(e) => setSelectedLanguageFilter(e.target.value)}
              className="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-slate-200 text-xs font-medium py-2.5 px-3 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              <option value="all">All Languages</option>
              {availableLangs.map((lang) => (
                <option key={lang} value={lang}>
                  {lang}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>

      {/* Document Grid / Empty state */}
      {filteredDocs.length === 0 ? (
        <div className="bg-white dark:bg-slate-800/80 rounded-3xl border border-dashed border-slate-300 dark:border-slate-700 p-12 text-center flex flex-col items-center justify-center my-6">
          <div className="w-16 h-16 rounded-2xl bg-blue-50 dark:bg-blue-950/50 text-blue-500 flex items-center justify-center mb-4">
            <Clock className="w-8 h-8" />
          </div>
          <h3 className="text-base font-bold text-slate-900 dark:text-white">
            {searchTerm ? 'No matching documents found' : 'No saved documents yet'}
          </h3>
          <p className="text-xs text-slate-500 dark:text-slate-400 max-w-sm mt-1 mb-5">
            {searchTerm
              ? 'Try searching with different terms or reset your filters.'
              : 'Scan notes using your camera or try out one of the instant sample handwritten documents!'}
          </p>
          <button
            onClick={onNewScan}
            className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-medium text-xs shadow-md shadow-blue-500/20"
          >
            Scan a Handwritten Document
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredDocs.map((doc) => (
            <div
              key={doc.id}
              className="bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 p-4 shadow-sm hover:shadow-md transition-all flex flex-col justify-between"
            >
              <div>
                {/* Header: Title + Language badge */}
                <div className="flex items-start justify-between gap-2 mb-2">
                  <div className="flex-1 min-w-0">
                    <h3
                      onClick={() => onOpenDocument(doc)}
                      className="font-bold text-base text-slate-900 dark:text-white truncate cursor-pointer hover:text-blue-600 dark:hover:text-blue-400 transition-colors"
                    >
                      {doc.title}
                    </h3>
                    <div className="flex items-center space-x-2 text-[11px] text-slate-400 mt-0.5">
                      <Clock className="w-3 h-3" />
                      <span>{new Date(doc.createdAt).toLocaleDateString()}</span>
                      <span>•</span>
                      <span>{doc.wordCount} words</span>
                    </div>
                  </div>

                  <span className="shrink-0 text-[10px] font-semibold px-2 py-0.5 rounded-full bg-blue-50 dark:bg-blue-950/60 text-blue-700 dark:text-blue-300">
                    {doc.detectedLanguage}
                  </span>
                </div>

                {/* Text snippet preview */}
                <p
                  onClick={() => onOpenDocument(doc)}
                  className="text-xs text-slate-600 dark:text-slate-300 bg-slate-50 dark:bg-slate-900/60 p-3 rounded-xl line-clamp-3 font-mono cursor-pointer hover:bg-slate-100 transition-colors"
                >
                  {doc.editedText || doc.rawText}
                </p>
              </div>

              {/* Bottom Card Actions */}
              <div className="mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/60 flex items-center justify-between">
                <div className="flex items-center space-x-1">
                  <button
                    onClick={() => onOpenDocument(doc)}
                    className="flex items-center space-x-1 px-2.5 py-1 text-xs font-semibold text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-950/50 rounded-lg transition-colors"
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                    <span>Open &amp; Edit</span>
                  </button>

                  <button
                    onClick={() => handleCopyText(doc)}
                    className="p-1.5 text-slate-500 hover:text-slate-800 dark:hover:text-slate-200 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
                    title="Copy Text"
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>

                  <button
                    onClick={() => exportDocumentToPdf(doc)}
                    className="p-1.5 text-slate-500 hover:text-red-600 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
                    title="Download PDF"
                  >
                    <FileDown className="w-3.5 h-3.5" />
                  </button>

                  <button
                    onClick={() => onDuplicateDocument(doc.id)}
                    className="p-1.5 text-slate-500 hover:text-blue-600 rounded-lg hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
                    title="Duplicate Document"
                  >
                    <Copy className="w-3.5 h-3.5" />
                  </button>
                </div>

                <button
                  onClick={() => handleDeleteWithConfirm(doc)}
                  className="p-1.5 text-slate-400 hover:text-red-600 rounded-lg hover:bg-red-50 dark:hover:bg-red-950/40 transition-colors"
                  title="Delete Document"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
};
