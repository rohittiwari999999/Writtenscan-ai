import React, { useState, useEffect } from 'react';
import { Loader2, X, AlertTriangle, RefreshCw, Cpu, Layers, Sparkles } from 'lucide-react';

interface OcrProcessingModalProps {
  isOpen: boolean;
  onCancel: () => void;
  onRetry: () => void;
  error: string | null;
  targetLanguage: string;
}

export const OcrProcessingModal: React.FC<OcrProcessingModalProps> = ({
  isOpen,
  onCancel,
  onRetry,
  error,
  targetLanguage,
}) => {
  const [elapsedSeconds, setElapsedSeconds] = useState(0);

  useEffect(() => {
    let interval: any;
    if (isOpen && !error) {
      setElapsedSeconds(0);
      interval = setInterval(() => {
        setElapsedSeconds((prev) => prev + 1);
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isOpen, error]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/70 backdrop-blur-sm animate-fade-in">
      <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-3xl p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 text-center relative overflow-hidden">
        {/* Animated Scanner Beam Header (if processing) */}
        {!error && (
          <div className="absolute top-0 inset-x-0 h-1.5 bg-gradient-to-r from-blue-500 via-indigo-500 to-sky-400 animate-pulse" />
        )}

        {/* Close / Cancel Button */}
        <button
          onClick={onCancel}
          className="absolute top-4 right-4 p-2 rounded-full text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          title="Cancel Transcription"
        >
          <X className="w-5 h-5" />
        </button>

        {error ? (
          /* Error State */
          <div className="space-y-4 py-2">
            <div className="w-16 h-16 rounded-2xl bg-red-100 dark:bg-red-950/60 text-red-600 dark:text-red-400 flex items-center justify-center mx-auto">
              <AlertTriangle className="w-8 h-8" />
            </div>

            <div>
              <h3 className="text-lg font-bold text-slate-900 dark:text-white">
                Transcription Failed
              </h3>
              <p className="text-xs sm:text-sm text-slate-600 dark:text-slate-400 mt-2 px-2 leading-relaxed">
                {error}
              </p>
            </div>

            <div className="flex gap-3 pt-4">
              <button
                onClick={onCancel}
                className="flex-1 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-slate-50 dark:hover:bg-slate-800"
              >
                Close
              </button>
              <button
                onClick={onRetry}
                className="flex-1 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-xs font-semibold text-white flex items-center justify-center space-x-1.5 shadow-md shadow-blue-500/20"
              >
                <RefreshCw className="w-3.5 h-3.5" />
                <span>Retry Request</span>
              </button>
            </div>
          </div>
        ) : (
          /* Live Progress State */
          <div className="space-y-6 py-2">
            <div className="relative w-20 h-20 mx-auto flex items-center justify-center">
              <div className="absolute inset-0 rounded-full border-4 border-blue-100 dark:border-blue-950 animate-ping opacity-25" />
              <div className="w-16 h-16 rounded-2xl bg-blue-50 dark:bg-blue-950/60 border border-blue-200 dark:border-blue-800 text-blue-600 dark:text-blue-400 flex items-center justify-center shadow-inner">
                <Loader2 className="w-8 h-8 animate-spin" />
              </div>
            </div>

            <div>
              <h3 className="text-lg font-bold text-slate-900 dark:text-white">
                Transcribing Handwriting...
              </h3>
              <p className="text-xs text-slate-500 dark:text-slate-400 mt-1">
                Gemini 3.8 Flash Vision OCR Engine ({targetLanguage.toUpperCase()})
              </p>
            </div>

            {/* Pipeline Step Indicators */}
            <div className="space-y-2 text-left bg-slate-50 dark:bg-slate-800/60 p-3.5 rounded-2xl border border-slate-100 dark:border-slate-800 text-xs">
              <div className="flex items-center space-x-2 text-slate-700 dark:text-slate-300">
                <Layers className="w-4 h-4 text-emerald-500" />
                <span>Document feature normalization</span>
              </div>
              <div className="flex items-center space-x-2 text-slate-700 dark:text-slate-300">
                <Cpu className="w-4 h-4 text-blue-500 animate-pulse" />
                <span>Multimodal script &amp; stroke analysis</span>
              </div>
              <div className="flex items-center space-x-2 text-slate-500 dark:text-slate-400">
                <Sparkles className="w-4 h-4 text-indigo-400" />
                <span>Extracting line breaks and indentation</span>
              </div>
            </div>

            <div className="flex items-center justify-between text-xs text-slate-400 pt-1">
              <span>Elapsed: {elapsedSeconds}s</span>
              <button
                onClick={onCancel}
                className="text-red-500 hover:text-red-600 font-medium underline"
              >
                Abort
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
