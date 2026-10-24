import React, { useState, useEffect, useRef } from 'react';
import { AppTab, ScannedDocument, BackendHealth } from './types';
import { Header } from './components/Header';
import { AndroidFrame } from './components/AndroidFrame';
import { ScannerTab } from './components/ScannerTab';
import { ImageEditorTab } from './components/ImageEditorTab';
import { DocumentEditorTab } from './components/DocumentEditorTab';
import { HistoryTab } from './components/HistoryTab';
import { SettingsTab } from './components/SettingsTab';
import { FlutterCodeHubTab } from './components/FlutterCodeHubTab';
import { OcrProcessingModal } from './components/OcrProcessingModal';
import { checkBackendHealth, recognizeHandwritingAPI } from './services/ocrApi';
import { createThumbnail } from './services/imageProcessing';
import {
  getSavedDocuments,
  saveDocument,
  deleteDocument,
  duplicateDocument,
  clearAllDocuments,
  getAppSettings,
  saveAppSettings,
  AppSettings,
} from './services/storage';

export default function App() {
  const [currentTab, setCurrentTab] = useState<AppTab>('scanner');
  const [settings, setSettings] = useState<AppSettings>(getAppSettings());
  const [documents, setDocuments] = useState<ScannedDocument[]>([]);
  const [activeDocument, setActiveDocument] = useState<ScannedDocument | null>(null);

  // Selected image currently being edited / preprocessed
  const [imageToEdit, setImageToEdit] = useState<string | null>(null);
  const [selectedLanguage, setSelectedLanguage] = useState<string>(settings.defaultLanguage || 'auto');

  // OCR Processing state
  const [isOcrRunning, setIsOcrRunning] = useState(false);
  const [ocrError, setOcrError] = useState<string | null>(null);
  const currentAbortController = useRef<AbortController | null>(null);

  // System status & health
  const [backendHealth, setBackendHealth] = useState<BackendHealth | null>(null);

  // Theme & View mode
  const [isDark, setIsDark] = useState<boolean>(() => {
    return (
      settings.theme === 'dark' ||
      (settings.theme === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches)
    );
  });
  const [viewMode, setViewMode] = useState<'phone' | 'full'>(settings.viewMode || 'full');

  // Load saved documents and health check on mount
  useEffect(() => {
    setDocuments(getSavedDocuments());
    refreshHealth();
  }, []);

  // Sync theme with HTML class
  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDark]);

  const refreshHealth = async () => {
    const health = await checkBackendHealth();
    setBackendHealth(health);
  };

  const handleUpdateSettings = (newSettings: Partial<AppSettings>) => {
    const updated = saveAppSettings(newSettings);
    setSettings(updated);
    if (newSettings.defaultLanguage) {
      setSelectedLanguage(newSettings.defaultLanguage);
    }
    if (newSettings.viewMode) {
      setViewMode(newSettings.viewMode);
    }
  };

  const toggleTheme = () => {
    setIsDark((prev) => {
      const next = !prev;
      handleUpdateSettings({ theme: next ? 'dark' : 'light' });
      return next;
    });
  };

  const toggleViewMode = () => {
    setViewMode((prev) => {
      const next = prev === 'phone' ? 'full' : 'phone';
      handleUpdateSettings({ viewMode: next });
      return next;
    });
  };

  // Image selected from camera or gallery
  const handleImageSelected = (dataUrl: string, lang: string) => {
    setImageToEdit(dataUrl);
    setSelectedLanguage(lang);
  };

  // Trigger OCR with processed image
  const handleRunOcr = async (processedDataUrl: string) => {
    setIsOcrRunning(true);
    setOcrError(null);

    const controller = new AbortController();
    currentAbortController.current = controller;

    try {
      // 1. Create a thumbnail for local document history
      const thumbnail = await createThumbnail(processedDataUrl, 200);

      // 2. Call real handwriting OCR API
      const result = await recognizeHandwritingAPI(
        processedDataUrl,
        selectedLanguage,
        controller.signal
      );

      // 3. Construct persistent document record
      const dateNow = new Date();
      const defaultTitle = `${result.detectedLanguage} Note — ${dateNow.toLocaleDateString([], {
        month: 'short',
        day: 'numeric',
      })} ${dateNow.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

      const newDoc: ScannedDocument = {
        id: 'doc_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
        title: defaultTitle,
        rawText: result.text,
        editedText: result.text,
        imageThumbnail: settings.imageRetention !== 'none' ? thumbnail : undefined,
        detectedLanguage: result.detectedLanguage,
        confidenceScore: result.confidenceScore,
        confidenceRating: result.confidenceRating,
        wordCount: result.wordCount,
        lineCount: result.lineCount,
        createdAt: dateNow.toISOString(),
        updatedAt: dateNow.toISOString(),
      };

      // 4. Save to persistent storage
      saveDocument(newDoc);
      setDocuments(getSavedDocuments());
      setActiveDocument(newDoc);
      setImageToEdit(null);
      setIsOcrRunning(false);

      // 5. Navigate to Editor Tab
      setCurrentTab('editor');
    } catch (err: any) {
      if (err.name === 'AbortError') {
        setIsOcrRunning(false);
      } else {
        setOcrError(err.message || 'Handwriting transcription failed.');
      }
    }
  };

  const handleCancelOcr = () => {
    if (currentAbortController.current) {
      currentAbortController.current.abort();
    }
    setIsOcrRunning(false);
    setOcrError(null);
  };

  const handleOpenDocument = (doc: ScannedDocument) => {
    setActiveDocument(doc);
    setImageToEdit(null);
    setCurrentTab('editor');
  };

  const handleDeleteDocument = (id: string) => {
    deleteDocument(id);
    const updated = getSavedDocuments();
    setDocuments(updated);
    if (activeDocument?.id === id) {
      setActiveDocument(updated[0] || null);
      if (updated.length === 0) {
        setCurrentTab('scanner');
      }
    }
  };

  const handleDuplicateDocument = (id: string) => {
    const copy = duplicateDocument(id);
    if (copy) {
      setDocuments(getSavedDocuments());
    }
  };

  const handleClearHistory = () => {
    clearAllDocuments();
    setDocuments([]);
    setActiveDocument(null);
  };

  const handleSaveActiveDocument = (updatedDoc: ScannedDocument) => {
    saveDocument(updatedDoc);
    setActiveDocument(updatedDoc);
    setDocuments(getSavedDocuments());
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950 text-slate-900 dark:text-slate-100 flex flex-col font-sans transition-colors">
      {/* Top Header */}
      <Header
        currentTab={currentTab}
        onTabChange={(tab) => {
          if (tab === 'scanner') setImageToEdit(null);
          setCurrentTab(tab);
        }}
        health={backendHealth}
        historyCount={documents.length}
        hasActiveDocument={Boolean(activeDocument)}
        viewMode={viewMode}
        onToggleViewMode={toggleViewMode}
        isDark={isDark}
        onToggleTheme={toggleTheme}
      />

      {/* Main Content framed in Android Device or Full Screen */}
      <AndroidFrame enabled={viewMode === 'phone'}>
        <main className="flex-1 flex flex-col">
          {/* TAB 1: SCANNER & IMAGE PREPROCESSING */}
          {currentTab === 'scanner' && (
            imageToEdit ? (
              <ImageEditorTab
                originalImageUrl={imageToEdit}
                onProceedToOcr={handleRunOcr}
                onCancel={() => setImageToEdit(null)}
              />
            ) : (
              <ScannerTab
                onImageSelected={handleImageSelected}
                selectedLanguage={selectedLanguage}
                onLanguageChange={setSelectedLanguage}
              />
            )
          )}

          {/* TAB 2: DOCUMENT EDITOR */}
          {currentTab === 'editor' && activeDocument && (
            <DocumentEditorTab
              document={activeDocument}
              onUpdateDocument={handleSaveActiveDocument}
              onSaveToHistory={handleSaveActiveDocument}
              onNewScan={() => {
                setImageToEdit(null);
                setCurrentTab('scanner');
              }}
            />
          )}

          {/* TAB 3: DOCUMENT HISTORY */}
          {currentTab === 'history' && (
            <HistoryTab
              documents={documents}
              onOpenDocument={handleOpenDocument}
              onDeleteDocument={handleDeleteDocument}
              onDuplicateDocument={handleDuplicateDocument}
              onNewScan={() => {
                setImageToEdit(null);
                setCurrentTab('scanner');
              }}
            />
          )}

          {/* TAB 4: FLUTTER CODE & APK BUILD HUB */}
          {currentTab === 'flutter_code' && <FlutterCodeHubTab />}

          {/* TAB 5: SETTINGS */}
          {currentTab === 'settings' && (
            <SettingsTab
              health={backendHealth}
              onRefreshHealth={refreshHealth}
              settings={settings}
              onUpdateSettings={handleUpdateSettings}
              onClearHistory={handleClearHistory}
            />
          )}
        </main>
      </AndroidFrame>

      {/* Real OCR Processing Modal */}
      <OcrProcessingModal
        isOpen={isOcrRunning}
        onCancel={handleCancelOcr}
        onRetry={() => {
          if (imageToEdit) handleRunOcr(imageToEdit);
        }}
        error={ocrError}
        targetLanguage={selectedLanguage}
      />
    </div>
  );
}
