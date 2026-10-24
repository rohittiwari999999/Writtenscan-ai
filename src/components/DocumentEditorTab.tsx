import React, { useState, useEffect, useRef } from 'react';
import {
  Copy,
  Check,
  Undo2,
  Redo2,
  Search,
  Replace,
  Download,
  Share2,
  Trash2,
  Volume2,
  VolumeX,
  Save,
  CheckCircle2,
  FileText,
  FileCode,
  FileDown,
  Printer,
  Edit2,
  Sparkles,
} from 'lucide-react';
import { ScannedDocument } from '../types';
import { exportDocumentToPdf, exportDocumentToTxt, exportDocumentToMarkdown } from '../services/pdfExport';

interface DocumentEditorTabProps {
  document: ScannedDocument;
  onUpdateDocument: (updated: ScannedDocument) => void;
  onSaveToHistory: (doc: ScannedDocument) => void;
  onNewScan: () => void;
}

export const DocumentEditorTab: React.FC<DocumentEditorTabProps> = ({
  document,
  onUpdateDocument,
  onSaveToHistory,
  onNewScan,
}) => {
  const [text, setText] = useState(document.editedText || document.rawText);
  const [title, setTitle] = useState(document.title);
  const [isEditingTitle, setIsEditingTitle] = useState(false);

  // Undo/Redo stack
  const [history, setHistory] = useState<string[]>([text]);
  const [historyIndex, setHistoryIndex] = useState(0);

  // Find & Replace
  const [showFindReplace, setShowFindReplace] = useState(false);
  const [findTerm, setFindTerm] = useState('');
  const [replaceTerm, setReplaceTerm] = useState('');
  const [findMatchesCount, setFindMatchesCount] = useState(0);

  // Copy toast
  const [copied, setCopied] = useState(false);
  const [savedToast, setSavedToast] = useState(false);

  // Text to Speech
  const [isPlayingAudio, setIsPlayingAudio] = useState(false);
  const speechRef = useRef<SpeechSynthesisUtterance | null>(null);

  // Font styling options
  const [isMonospace, setIsMonospace] = useState(false);

  // Textarea ref
  const textareaRef = useRef<HTMLTextAreaElement | null>(null);

  // Sync state if document prop changes
  useEffect(() => {
    setText(document.editedText || document.rawText);
    setTitle(document.title);
    setHistory([document.editedText || document.rawText]);
    setHistoryIndex(0);
  }, [document.id]);

  // Handle text modification
  const handleTextChange = (newVal: string) => {
    setText(newVal);
    // Push to undo stack (max 50 states)
    const newHistory = history.slice(0, historyIndex + 1);
    newHistory.push(newVal);
    if (newHistory.length > 50) newHistory.shift();
    setHistory(newHistory);
    setHistoryIndex(newHistory.length - 1);

    // Update parent
    const wordCount = newVal.split(/\s+/).filter(Boolean).length;
    const lineCount = newVal.split('\n').length;
    onUpdateDocument({
      ...document,
      editedText: newVal,
      wordCount,
      lineCount,
      updatedAt: new Date().toISOString(),
    });
  };

  const undo = () => {
    if (historyIndex > 0) {
      const prev = history[historyIndex - 1];
      setHistoryIndex(historyIndex - 1);
      setText(prev);
    }
  };

  const redo = () => {
    if (historyIndex < history.length - 1) {
      const next = history[historyIndex + 1];
      setHistoryIndex(historyIndex + 1);
      setText(next);
    }
  };

  // Find matches count
  useEffect(() => {
    if (!findTerm.trim()) {
      setFindMatchesCount(0);
      return;
    }
    try {
      const regex = new RegExp(findTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
      const matches = text.match(regex);
      setFindMatchesCount(matches ? matches.length : 0);
    } catch {
      setFindMatchesCount(0);
    }
  }, [findTerm, text]);

  // Replace one
  const handleReplaceOne = () => {
    if (!findTerm) return;
    const regex = new RegExp(findTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i');
    const newText = text.replace(regex, replaceTerm);
    handleTextChange(newText);
  };

  // Replace all
  const handleReplaceAll = () => {
    if (!findTerm) return;
    const regex = new RegExp(findTerm.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi');
    const newText = text.replace(regex, replaceTerm);
    handleTextChange(newText);
  };

  // Copy to clipboard
  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch (err) {
      console.error('Failed to copy text:', err);
    }
  };

  // Select all
  const handleSelectAll = () => {
    if (textareaRef.current) {
      textareaRef.current.select();
    }
  };

  // Clear text
  const handleClearText = () => {
    if (window.confirm('Are you sure you want to clear all transcribed text?')) {
      handleTextChange('');
    }
  };

  // Save changes
  const handleSave = () => {
    const updatedDoc: ScannedDocument = {
      ...document,
      title,
      editedText: text,
      wordCount: text.split(/\s+/).filter(Boolean).length,
      lineCount: text.split('\n').length,
      updatedAt: new Date().toISOString(),
    };
    onSaveToHistory(updatedDoc);
    setSavedToast(true);
    setTimeout(() => setSavedToast(false), 2500);
  };

  // Text to Speech
  const toggleSpeech = () => {
    if (!('speechSynthesis' in window)) {
      alert('Speech synthesis is not supported in this browser.');
      return;
    }

    if (isPlayingAudio) {
      window.speechSynthesis.cancel();
      setIsPlayingAudio(false);
      return;
    }

    if (!text.trim()) return;

    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(text);
    speechRef.current = utterance;

    // Detect language voice if applicable
    if (document.detectedLanguage.toLowerCase().includes('hindi')) {
      utterance.lang = 'hi-IN';
    } else if (document.detectedLanguage.toLowerCase().includes('tamil')) {
      utterance.lang = 'ta-IN';
    } else {
      utterance.lang = 'en-US';
    }

    utterance.onend = () => setIsPlayingAudio(false);
    utterance.onerror = () => setIsPlayingAudio(false);

    window.speechSynthesis.speak(utterance);
    setIsPlayingAudio(true);
  };

  // Native share
  const handleShare = async () => {
    if (navigator.share) {
      try {
        await navigator.share({
          title: title,
          text: text,
        });
      } catch {
        // user cancelled share
      }
    } else {
      handleCopy();
      alert('Text copied to clipboard for sharing!');
    }
  };

  const currentDocWithEdits: ScannedDocument = {
    ...document,
    title,
    editedText: text,
  };

  return (
    <div className="flex-1 p-4 sm:p-6 max-w-5xl mx-auto w-full flex flex-col space-y-4">
      {/* Top Document Title Bar */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3 bg-white dark:bg-slate-800 p-4 rounded-2xl border border-slate-200 dark:border-slate-700/60 shadow-sm">
        <div className="flex items-center space-x-3">
          <div className="w-10 h-10 rounded-xl bg-blue-100 dark:bg-blue-900/40 text-blue-600 dark:text-blue-400 flex items-center justify-center shrink-0">
            <FileText className="w-5 h-5" />
          </div>

          <div className="flex-1 min-w-0">
            {isEditingTitle ? (
              <div className="flex items-center space-x-2">
                <input
                  type="text"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  onBlur={() => setIsEditingTitle(false)}
                  onKeyDown={(e) => e.key === 'Enter' && setIsEditingTitle(false)}
                  autoFocus
                  className="px-2 py-1 text-base font-bold bg-slate-100 dark:bg-slate-700 rounded-lg text-slate-900 dark:text-white border border-blue-500 focus:outline-none"
                />
                <button
                  onClick={() => setIsEditingTitle(false)}
                  className="p-1 text-emerald-600 hover:text-emerald-700"
                >
                  <Check className="w-4 h-4" />
                </button>
              </div>
            ) : (
              <div className="flex items-center space-x-2">
                <h2 className="text-lg font-bold text-slate-900 dark:text-white truncate">
                  {title}
                </h2>
                <button
                  onClick={() => setIsEditingTitle(true)}
                  className="text-slate-400 hover:text-slate-600 dark:hover:text-slate-200"
                  title="Rename Document"
                >
                  <Edit2 className="w-3.5 h-3.5" />
                </button>
              </div>
            )}

            {/* Badges: Confidence, Language, Word count */}
            <div className="flex flex-wrap items-center gap-2 mt-1">
              <span className="text-xs px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-300 font-semibold flex items-center gap-1">
                <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                <span>{document.confidenceScore}% Confidence ({document.confidenceRating})</span>
              </span>

              <span className="text-xs px-2 py-0.5 rounded-full bg-blue-50 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300 font-medium">
                {document.detectedLanguage}
              </span>

              <span className="text-xs text-slate-500 dark:text-slate-400">
                {text.split(/\s+/).filter(Boolean).length} words • {text.length} chars
              </span>
            </div>
          </div>
        </div>

        {/* Primary Save & Export Buttons */}
        <div className="flex items-center space-x-2 self-end sm:self-center">
          <button
            onClick={handleSave}
            className="flex items-center space-x-1.5 px-3.5 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-semibold shadow-md shadow-blue-500/20 transition-all"
          >
            <Save className="w-4 h-4" />
            <span>Save Changes</span>
          </button>

          <button
            onClick={handleShare}
            className="p-2 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors"
            title="Share Document"
          >
            <Share2 className="w-4 h-4" />
          </button>

          {/* Export Dropdown */}
          <div className="relative group">
            <button
              className="flex items-center space-x-1 px-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors text-xs font-medium"
              title="Export Document"
            >
              <Download className="w-4 h-4" />
              <span>Export</span>
            </button>

            <div className="absolute right-0 mt-1 w-44 bg-white dark:bg-slate-800 rounded-2xl shadow-xl border border-slate-200 dark:border-slate-700 py-1.5 hidden group-hover:block z-30">
              <button
                onClick={() => exportDocumentToPdf(currentDocWithEdits)}
                className="w-full text-left px-3.5 py-2 text-xs font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 flex items-center space-x-2"
              >
                <FileDown className="w-4 h-4 text-red-500" />
                <span>Export as PDF</span>
              </button>
              <button
                onClick={() => exportDocumentToTxt(currentDocWithEdits)}
                className="w-full text-left px-3.5 py-2 text-xs font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 flex items-center space-x-2"
              >
                <FileText className="w-4 h-4 text-blue-500" />
                <span>Export as TXT</span>
              </button>
              <button
                onClick={() => exportDocumentToMarkdown(currentDocWithEdits)}
                className="w-full text-left px-3.5 py-2 text-xs font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 flex items-center space-x-2"
              >
                <FileCode className="w-4 h-4 text-indigo-500" />
                <span>Export as Markdown</span>
              </button>
              <button
                onClick={() => window.print()}
                className="w-full text-left px-3.5 py-2 text-xs font-medium text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 flex items-center space-x-2 border-t border-slate-100 dark:border-slate-700"
              >
                <Printer className="w-4 h-4 text-slate-500" />
                <span>Print Document</span>
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Editor Toolbar */}
      <div className="flex flex-wrap items-center justify-between gap-2 bg-slate-100 dark:bg-slate-800/80 px-3 py-2 rounded-xl text-xs text-slate-700 dark:text-slate-300">
        {/* Left Toolbar actions */}
        <div className="flex items-center space-x-1">
          <button
            onClick={undo}
            disabled={historyIndex <= 0}
            className={`p-1.5 rounded-lg transition-colors ${
              historyIndex > 0 ? 'hover:bg-white dark:hover:bg-slate-700' : 'opacity-40 cursor-not-allowed'
            }`}
            title="Undo (Ctrl+Z)"
          >
            <Undo2 className="w-4 h-4" />
          </button>

          <button
            onClick={redo}
            disabled={historyIndex >= history.length - 1}
            className={`p-1.5 rounded-lg transition-colors ${
              historyIndex < history.length - 1
                ? 'hover:bg-white dark:hover:bg-slate-700'
                : 'opacity-40 cursor-not-allowed'
            }`}
            title="Redo (Ctrl+Y)"
          >
            <Redo2 className="w-4 h-4" />
          </button>

          <div className="w-px h-4 bg-slate-300 dark:bg-slate-600 mx-1" />

          <button
            onClick={() => setShowFindReplace(!showFindReplace)}
            className={`flex items-center space-x-1 px-2 py-1 rounded-lg transition-colors ${
              showFindReplace
                ? 'bg-blue-600 text-white'
                : 'hover:bg-white dark:hover:bg-slate-700'
            }`}
            title="Find & Replace"
          >
            <Search className="w-3.5 h-3.5" />
            <span>Find &amp; Replace</span>
          </button>

          <button
            onClick={toggleSpeech}
            className={`flex items-center space-x-1 px-2 py-1 rounded-lg transition-colors ${
              isPlayingAudio ? 'bg-amber-500 text-white' : 'hover:bg-white dark:hover:bg-slate-700'
            }`}
            title="Read text aloud"
          >
            {isPlayingAudio ? <VolumeX className="w-3.5 h-3.5" /> : <Volume2 className="w-3.5 h-3.5" />}
            <span>{isPlayingAudio ? 'Stop Voice' : 'Read Aloud'}</span>
          </button>

          <button
            onClick={() => setIsMonospace(!isMonospace)}
            className="px-2 py-1 rounded-lg hover:bg-white dark:hover:bg-slate-700 font-mono text-[11px]"
            title="Toggle Monospace / Standard font"
          >
            {isMonospace ? 'Proportional' : 'Monospace'}
          </button>
        </div>

        {/* Right Toolbar Actions */}
        <div className="flex items-center space-x-2">
          <button
            onClick={handleSelectAll}
            className="px-2 py-1 rounded-lg hover:bg-white dark:hover:bg-slate-700"
          >
            Select All
          </button>

          <button
            onClick={handleCopy}
            className="flex items-center space-x-1 px-2.5 py-1 bg-white dark:bg-slate-700 rounded-lg shadow-sm font-medium hover:bg-slate-50 transition-colors"
          >
            {copied ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
            <span>{copied ? 'Copied!' : 'Copy Text'}</span>
          </button>

          <button
            onClick={handleClearText}
            className="p-1.5 rounded-lg text-red-500 hover:bg-red-50 dark:hover:bg-red-950/40"
            title="Clear Text"
          >
            <Trash2 className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>

      {/* Find & Replace Bar (Collapsible) */}
      {showFindReplace && (
        <div className="bg-slate-50 dark:bg-slate-800 p-3 rounded-xl border border-slate-200 dark:border-slate-700 space-y-2 text-xs">
          <div className="flex flex-col sm:flex-row gap-2">
            <div className="flex-1 relative">
              <input
                type="text"
                placeholder="Find in document..."
                value={findTerm}
                onChange={(e) => setFindTerm(e.target.value)}
                className="w-full pl-8 pr-16 py-1.5 rounded-lg bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
              <Search className="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-slate-400" />
              {findTerm && (
                <span className="absolute right-2 top-2 text-[10px] text-slate-400 font-mono">
                  {findMatchesCount} found
                </span>
              )}
            </div>

            <div className="flex-1 relative">
              <input
                type="text"
                placeholder="Replace with..."
                value={replaceTerm}
                onChange={(e) => setReplaceTerm(e.target.value)}
                className="w-full pl-8 pr-2 py-1.5 rounded-lg bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-600 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
              <Replace className="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-slate-400" />
            </div>

            <div className="flex gap-2">
              <button
                onClick={handleReplaceOne}
                disabled={!findTerm}
                className="px-3 py-1.5 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50"
              >
                Replace
              </button>
              <button
                onClick={handleReplaceAll}
                disabled={!findTerm}
                className="px-3 py-1.5 bg-slate-200 dark:bg-slate-700 text-slate-800 dark:text-slate-200 rounded-lg font-medium hover:bg-slate-300 disabled:opacity-50"
              >
                Replace All
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Main Textarea Editor Area */}
      <div className="flex-1 min-h-[380px] bg-white dark:bg-slate-800 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm overflow-hidden flex flex-col">
        <textarea
          ref={textareaRef}
          value={text}
          onChange={(e) => handleTextChange(e.target.value)}
          placeholder="Extracted handwritten text will appear here. You can freely edit, format, or correct..."
          className={`flex-1 p-5 w-full resize-none border-none focus:outline-none bg-transparent text-slate-900 dark:text-slate-100 text-sm leading-relaxed ${
            isMonospace ? 'font-mono' : 'font-sans'
          }`}
          style={{ minHeight: '380px' }}
        />
      </div>

      {/* Bottom Status & Quick Action Footer */}
      <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400 pt-1">
        <div className="flex items-center space-x-3">
          <span>Preserves line breaks, numbered steps, and Indian Unicode scripts</span>
          {savedToast && (
            <span className="text-emerald-600 dark:text-emerald-400 font-semibold flex items-center gap-1">
              <Check className="w-3.5 h-3.5" /> Saved to local history!
            </span>
          )}
        </div>

        <button
          onClick={onNewScan}
          className="text-blue-600 dark:text-blue-400 hover:underline font-medium"
        >
          + Scan Another Note
        </button>
      </div>
    </div>
  );
};
