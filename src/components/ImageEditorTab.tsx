import React, { useState, useEffect, useRef } from 'react';
import {
  RotateCw,
  RotateCcw,
  Sliders,
  Crop as CropIcon,
  Sparkles,
  RefreshCw,
  Check,
  ArrowRight,
  Eye,
  Sun,
  Contrast,
  Compass,
} from 'lucide-react';
import { ImageAdjustments } from '../types';
import { processImageOnCanvas } from '../services/imageProcessing';

interface ImageEditorTabProps {
  originalImageUrl: string;
  onProceedToOcr: (processedImageUrl: string) => void;
  onCancel: () => void;
}

const DEFAULT_ADJUSTMENTS: ImageAdjustments = {
  rotation: 0,
  straightenAngle: 0,
  brightness: 0,
  contrast: 0,
  filter: 'none',
};

export const ImageEditorTab: React.FC<ImageEditorTabProps> = ({
  originalImageUrl,
  onProceedToOcr,
  onCancel,
}) => {
  const [adjustments, setAdjustments] = useState<ImageAdjustments>(DEFAULT_ADJUSTMENTS);
  const [processedUrl, setProcessedUrl] = useState<string>(originalImageUrl);
  const [isProcessing, setIsProcessing] = useState(false);
  const [activeSubTab, setActiveSubTab] = useState<'filters' | 'tune' | 'crop'>('filters');
  const [showOriginalComparison, setShowOriginalComparison] = useState(false);

  // Debounced processing of adjustments onto canvas
  useEffect(() => {
    let isCurrent = true;
    const runProcessing = async () => {
      setIsProcessing(true);
      try {
        const result = await processImageOnCanvas(originalImageUrl, adjustments);
        if (isCurrent) {
          setProcessedUrl(result);
        }
      } catch (err) {
        console.error('Failed to process image preview:', err);
      } finally {
        if (isCurrent) setIsProcessing(false);
      }
    };

    const timer = setTimeout(runProcessing, 150);
    return () => {
      isCurrent = false;
      clearTimeout(timer);
    };
  }, [originalImageUrl, adjustments]);

  const rotate90 = (direction: 'cw' | 'ccw') => {
    setAdjustments((prev) => ({
      ...prev,
      rotation: (prev.rotation + (direction === 'cw' ? 90 : 270)) % 360,
    }));
  };

  const handleReset = () => {
    setAdjustments(DEFAULT_ADJUSTMENTS);
  };

  return (
    <div className="flex-1 p-4 sm:p-6 max-w-5xl mx-auto w-full flex flex-col space-y-5">
      {/* Top Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-white">
            Document Preprocessing &amp; Enhancement
          </h2>
          <p className="text-xs text-slate-500 dark:text-slate-400">
            Deskew, enhance contrast, and binarize ink for maximum handwriting recognition accuracy
          </p>
        </div>

        <div className="flex items-center space-x-2">
          <button
            onClick={handleReset}
            className="flex items-center space-x-1.5 px-3 py-1.5 text-xs font-medium rounded-xl border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>Reset</span>
          </button>

          <button
            onClick={onCancel}
            className="px-3 py-1.5 text-xs font-medium rounded-xl border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
          >
            Cancel
          </button>

          <button
            onClick={() => onProceedToOcr(processedUrl)}
            disabled={isProcessing}
            className="flex items-center space-x-1.5 px-4 py-2 text-xs font-semibold rounded-xl bg-blue-600 hover:bg-blue-700 text-white shadow-md shadow-blue-500/20 transition-all"
          >
            <span>Recognize Handwriting</span>
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      {/* Main Workspace: Image Preview and Controls */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-5 flex-1 items-start">
        {/* Preview Frame */}
        <div className="lg:col-span-8 bg-slate-900 rounded-3xl overflow-hidden p-4 flex flex-col items-center justify-center min-h-[420px] max-h-[580px] relative shadow-lg">
          <div className="w-full h-full flex items-center justify-center overflow-hidden relative">
            <img
              src={showOriginalComparison ? originalImageUrl : processedUrl}
              alt="Handwriting scan preview"
              className="max-h-[520px] max-w-full object-contain rounded-lg shadow-md transition-opacity duration-200"
            />

            {/* Comparison Badge */}
            {showOriginalComparison && (
              <div className="absolute top-3 left-3 bg-black/70 backdrop-blur-md text-amber-300 text-xs font-bold px-3 py-1 rounded-full">
                Original Image
              </div>
            )}
          </div>

          {/* Quick Floating Preview Controls */}
          <div className="absolute bottom-4 flex items-center space-x-2 bg-slate-800/80 backdrop-blur-md px-3 py-1.5 rounded-full border border-slate-700/60 text-white text-xs">
            <button
              onClick={() => rotate90('ccw')}
              className="p-1.5 hover:bg-white/10 rounded-full transition-colors"
              title="Rotate 90° Left"
            >
              <RotateCcw className="w-4 h-4" />
            </button>
            <button
              onClick={() => rotate90('cw')}
              className="p-1.5 hover:bg-white/10 rounded-full transition-colors"
              title="Rotate 90° Right"
            >
              <RotateCw className="w-4 h-4" />
            </button>
            <div className="w-px h-4 bg-slate-600 mx-1" />
            <button
              onMouseDown={() => setShowOriginalComparison(true)}
              onMouseUp={() => setShowOriginalComparison(false)}
              onTouchStart={() => setShowOriginalComparison(true)}
              onTouchEnd={() => setShowOriginalComparison(false)}
              className="flex items-center space-x-1 px-2.5 py-1 hover:bg-white/10 rounded-full transition-colors"
              title="Hold to see original"
            >
              <Eye className="w-3.5 h-3.5" />
              <span>Hold for Original</span>
            </button>
          </div>
        </div>

        {/* Adjustments Tool Panel */}
        <div className="lg:col-span-4 bg-white dark:bg-slate-800 rounded-3xl p-5 border border-slate-200 dark:border-slate-700/60 shadow-sm flex flex-col space-y-5">
          {/* Sub-tab selection */}
          <div className="flex rounded-xl bg-slate-100 dark:bg-slate-700/80 p-1">
            <button
              onClick={() => setActiveSubTab('filters')}
              className={`flex-1 py-1.5 text-xs font-medium rounded-lg transition-all flex items-center justify-center space-x-1 ${
                activeSubTab === 'filters'
                  ? 'bg-white dark:bg-slate-600 text-blue-600 dark:text-blue-300 shadow-sm'
                  : 'text-slate-600 dark:text-slate-300'
              }`}
            >
              <Sparkles className="w-3.5 h-3.5" />
              <span>Document Filters</span>
            </button>

            <button
              onClick={() => setActiveSubTab('tune')}
              className={`flex-1 py-1.5 text-xs font-medium rounded-lg transition-all flex items-center justify-center space-x-1 ${
                activeSubTab === 'tune'
                  ? 'bg-white dark:bg-slate-600 text-blue-600 dark:text-blue-300 shadow-sm'
                  : 'text-slate-600 dark:text-slate-300'
              }`}
            >
              <Sliders className="w-3.5 h-3.5" />
              <span>Adjustments</span>
            </button>

            <button
              onClick={() => setActiveSubTab('crop')}
              className={`flex-1 py-1.5 text-xs font-medium rounded-lg transition-all flex items-center justify-center space-x-1 ${
                activeSubTab === 'crop'
                  ? 'bg-white dark:bg-slate-600 text-blue-600 dark:text-blue-300 shadow-sm'
                  : 'text-slate-600 dark:text-slate-300'
              }`}
            >
              <CropIcon className="w-3.5 h-3.5" />
              <span>Crop &amp; Tilt</span>
            </button>
          </div>

          {/* 1. FILTER PRESETS */}
          {activeSubTab === 'filters' && (
            <div className="space-y-3">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
                Enhancement Presets
              </span>

              <div className="grid grid-cols-1 gap-2">
                {[
                  {
                    id: 'none',
                    name: 'Natural Photo',
                    desc: 'Original camera colors and lighting',
                  },
                  {
                    id: 'binarize',
                    name: 'Clean B&W Scan',
                    desc: 'High contrast document filter; removes paper shadows',
                  },
                  {
                    id: 'magic_sharp',
                    name: 'Ink Sharp / Darken',
                    desc: 'Crisp pencil and fountain pen strokes',
                  },
                  {
                    id: 'grayscale',
                    name: 'Grayscale Document',
                    desc: 'Monochrome contrast enhancement',
                  },
                  {
                    id: 'warm',
                    name: 'Warm Parchment',
                    desc: 'Softizes blue glare for notebook pages',
                  },
                ].map((f) => (
                  <button
                    key={f.id}
                    onClick={() =>
                      setAdjustments((prev) => ({
                        ...prev,
                        filter: f.id as ImageAdjustments['filter'],
                      }))
                    }
                    className={`p-3 rounded-xl border text-left transition-all flex items-start justify-between ${
                      adjustments.filter === f.id
                        ? 'border-blue-500 bg-blue-50/60 dark:bg-blue-900/30 text-blue-900 dark:text-blue-200 shadow-sm'
                        : 'border-slate-200 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50'
                    }`}
                  >
                    <div>
                      <div className="font-semibold text-xs text-slate-900 dark:text-slate-100">
                        {f.name}
                      </div>
                      <div className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">
                        {f.desc}
                      </div>
                    </div>
                    {adjustments.filter === f.id && (
                      <Check className="w-4 h-4 text-blue-600 dark:text-blue-400 shrink-0 mt-0.5" />
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* 2. TUNE BRIGHTNESS & CONTRAST */}
          {activeSubTab === 'tune' && (
            <div className="space-y-5">
              <div>
                <div className="flex items-center justify-between text-xs font-medium mb-1.5 text-slate-700 dark:text-slate-300">
                  <span className="flex items-center gap-1.5">
                    <Sun className="w-3.5 h-3.5 text-amber-500" />
                    <span>Brightness</span>
                  </span>
                  <span className="font-mono text-slate-500">{adjustments.brightness}</span>
                </div>
                <input
                  type="range"
                  min="-50"
                  max="50"
                  value={adjustments.brightness}
                  onChange={(e) =>
                    setAdjustments((prev) => ({
                      ...prev,
                      brightness: parseInt(e.target.value, 10),
                    }))
                  }
                  className="w-full accent-blue-600"
                />
              </div>

              <div>
                <div className="flex items-center justify-between text-xs font-medium mb-1.5 text-slate-700 dark:text-slate-300">
                  <span className="flex items-center gap-1.5">
                    <Contrast className="w-3.5 h-3.5 text-blue-500" />
                    <span>Contrast</span>
                  </span>
                  <span className="font-mono text-slate-500">{adjustments.contrast}</span>
                </div>
                <input
                  type="range"
                  min="-50"
                  max="50"
                  value={adjustments.contrast}
                  onChange={(e) =>
                    setAdjustments((prev) => ({
                      ...prev,
                      contrast: parseInt(e.target.value, 10),
                    }))
                  }
                  className="w-full accent-blue-600"
                />
              </div>

              <div className="pt-2">
                <button
                  onClick={() =>
                    setAdjustments((prev) => ({
                      ...prev,
                      brightness: 0,
                      contrast: 0,
                    }))
                  }
                  className="w-full py-2 text-xs font-medium rounded-xl border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-100"
                >
                  Reset Sliders
                </button>
              </div>
            </div>
          )}

          {/* 3. CROP & TILT */}
          {activeSubTab === 'crop' && (
            <div className="space-y-4">
              <div>
                <div className="flex items-center justify-between text-xs font-medium mb-1.5 text-slate-700 dark:text-slate-300">
                  <span className="flex items-center gap-1.5">
                    <Compass className="w-3.5 h-3.5 text-indigo-500" />
                    <span>Deskew / Fine Tilt</span>
                  </span>
                  <span className="font-mono text-slate-500">{adjustments.straightenAngle}°</span>
                </div>
                <input
                  type="range"
                  min="-25"
                  max="25"
                  step="0.5"
                  value={adjustments.straightenAngle}
                  onChange={(e) =>
                    setAdjustments((prev) => ({
                      ...prev,
                      straightenAngle: parseFloat(e.target.value),
                    }))
                  }
                  className="w-full accent-blue-600"
                />
                <div className="flex justify-between text-[10px] text-slate-400 mt-1">
                  <span>-25° (Left Tilt)</span>
                  <span>0° (Straight)</span>
                  <span>+25° (Right Tilt)</span>
                </div>
              </div>

              <div className="pt-2 border-t border-slate-100 dark:border-slate-700">
                <span className="text-xs font-bold text-slate-700 dark:text-slate-300 block mb-2">
                  90-Degree Step Rotation
                </span>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    onClick={() => rotate90('ccw')}
                    className="flex items-center justify-center space-x-1.5 py-2 px-3 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-medium hover:bg-slate-50 dark:hover:bg-slate-700"
                  >
                    <RotateCcw className="w-3.5 h-3.5" />
                    <span>90° Left</span>
                  </button>
                  <button
                    onClick={() => rotate90('cw')}
                    className="flex items-center justify-center space-x-1.5 py-2 px-3 border border-slate-200 dark:border-slate-700 rounded-xl text-xs font-medium hover:bg-slate-50 dark:hover:bg-slate-700"
                  >
                    <RotateCw className="w-3.5 h-3.5" />
                    <span>90° Right</span>
                  </button>
                </div>
              </div>
            </div>
          )}

          {/* Bottom Action in Tool Panel */}
          <div className="pt-3 border-t border-slate-200 dark:border-slate-700">
            <button
              onClick={() => onProceedToOcr(processedUrl)}
              disabled={isProcessing}
              className="w-full py-3 rounded-2xl bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white font-semibold text-sm shadow-md shadow-blue-500/20 flex items-center justify-center space-x-2 transition-all active:scale-[0.99]"
            >
              <Sparkles className="w-4 h-4" />
              <span>Transcribe with Real OCR</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
