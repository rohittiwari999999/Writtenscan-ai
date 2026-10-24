import React, { useState, useRef, useEffect } from 'react';
import {
  Camera,
  Upload,
  Zap,
  ZapOff,
  SwitchCamera,
  Grid,
  FileImage,
  Globe,
  Sparkles,
  Info,
  CheckCircle,
  AlertCircle,
} from 'lucide-react';
import { LANGUAGES } from '../constants/languages';
import { SAMPLE_NOTES, SampleNote } from '../constants/sampleNotes';

interface ScannerTabProps {
  onImageSelected: (dataUrl: string, selectedLang: string) => void;
  selectedLanguage: string;
  onLanguageChange: (lang: string) => void;
}

export const ScannerTab: React.FC<ScannerTabProps> = ({
  onImageSelected,
  selectedLanguage,
  onLanguageChange,
}) => {
  const [activeMode, setActiveMode] = useState<'camera' | 'upload' | 'samples'>('samples');
  const [cameraActive, setCameraActive] = useState(false);
  const [facingMode, setFacingMode] = useState<'environment' | 'user'>('environment');
  const [flashEnabled, setFlashEnabled] = useState(false);
  const [showGrid, setShowGrid] = useState(true);
  const [cameraError, setCameraError] = useState<string | null>(null);
  const [dragActive, setDragActive] = useState(false);

  const videoRef = useRef<HTMLVideoElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  // Initialize camera stream
  const startCamera = async () => {
    stopCamera();
    setCameraError(null);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode,
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
        audio: false,
      });

      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        videoRef.current.play();
      }
      setCameraActive(true);
    } catch (err: any) {
      console.warn('Camera access error:', err);
      setCameraError(
        err.name === 'NotAllowedError'
          ? 'Camera permission was denied. Please allow camera permissions in your browser or switch to Gallery/Sample upload.'
          : 'Camera device is unavailable or already in use. You can import an image from gallery or select a sample note.'
      );
      setCameraActive(false);
    }
  };

  const stopCamera = () => {
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    setCameraActive(false);
  };

  // Flip camera
  const toggleFacingMode = () => {
    setFacingMode((prev) => (prev === 'environment' ? 'user' : 'environment'));
  };

  useEffect(() => {
    if (activeMode === 'camera') {
      startCamera();
    } else {
      stopCamera();
    }
    return () => {
      stopCamera();
    };
  }, [activeMode, facingMode]);

  // Capture snapshot from video stream
  const captureSnapshot = () => {
    if (!videoRef.current) return;
    const video = videoRef.current;
    const canvas = document.createElement('canvas');
    canvas.width = video.videoWidth || 1280;
    canvas.height = video.videoHeight || 720;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Draw frame
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
    const dataUrl = canvas.toDataURL('image/jpeg', 0.95);
    stopCamera();
    onImageSelected(dataUrl, selectedLanguage);
  };

  // Handle file uploads
  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    readFile(file);
  };

  const readFile = (file: File) => {
    if (!file.type.startsWith('image/')) {
      alert('Please select an image file (JPEG, PNG, WEBP).');
      return;
    }
    const reader = new FileReader();
    reader.onload = (event) => {
      if (event.target?.result) {
        onImageSelected(event.target.result as string, selectedLanguage);
      }
    };
    reader.readAsDataURL(file);
  };

  // Drag and drop handlers
  const handleDrag = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (e.type === 'dragenter' || e.type === 'dragover') {
      setDragActive(true);
    } else if (e.type === 'dragleave') {
      setDragActive(false);
    }
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setDragActive(false);
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      readFile(e.dataTransfer.files[0]);
    }
  };

  // Select sample note
  const handleSelectSample = (sample: SampleNote) => {
    // Optionally auto-set language match
    if (sample.id.includes('hindi')) {
      onLanguageChange('hi');
    } else if (sample.id.includes('tamil')) {
      onLanguageChange('ta');
    } else if (sample.id.includes('english') || sample.id.includes('checklist')) {
      onLanguageChange('en');
    }
    onImageSelected(sample.previewUrl, selectedLanguage);
  };

  // Paste from clipboard support
  useEffect(() => {
    const handlePaste = (e: ClipboardEvent) => {
      const items = e.clipboardData?.items;
      if (!items) return;
      for (let i = 0; i < items.length; i++) {
        if (items[i].type.indexOf('image') !== -1) {
          const file = items[i].getAsFile();
          if (file) readFile(file);
          break;
        }
      }
    };
    window.addEventListener('paste', handlePaste);
    return () => window.removeEventListener('paste', handlePaste);
  }, [selectedLanguage]);

  const currentLangObj = LANGUAGES.find((l) => l.code === selectedLanguage) || LANGUAGES[0];

  return (
    <div className="flex-1 p-4 sm:p-6 max-w-4xl mx-auto w-full flex flex-col space-y-6">
      {/* Top Banner / Mode Switcher */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 bg-white dark:bg-slate-800/80 p-4 rounded-2xl border border-slate-200 dark:border-slate-700/60 shadow-sm">
        <div>
          <h2 className="text-xl font-bold text-slate-900 dark:text-white flex items-center gap-2">
            <span>Handwriting Scanner &amp; Intake</span>
            <span className="text-xs px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 dark:bg-emerald-900/60 dark:text-emerald-300 font-medium">
              OCR Engine
            </span>
          </h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Capture with camera, upload an image, or test instant handwritten samples
          </p>
        </div>

        {/* Target Language Dropdown */}
        <div className="flex items-center space-x-2">
          <Globe className="w-4 h-4 text-slate-400" />
          <div className="relative">
            <select
              value={selectedLanguage}
              onChange={(e) => onLanguageChange(e.target.value)}
              className="appearance-none bg-slate-100 dark:bg-slate-700/80 text-slate-900 dark:text-slate-100 text-sm font-medium py-1.5 pl-3 pr-8 rounded-xl border border-slate-200 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500"
            >
              {LANGUAGES.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.name} ({lang.nativeName})
                </option>
              ))}
            </select>
            <div className="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-slate-400">
              ▼
            </div>
          </div>
        </div>
      </div>

      {/* Mode Segmented Control */}
      <div className="flex rounded-xl bg-slate-200/80 dark:bg-slate-800 p-1">
        <button
          onClick={() => setActiveMode('samples')}
          className={`flex-1 py-2 text-sm font-medium rounded-lg transition-all flex items-center justify-center space-x-2 ${
            activeMode === 'samples'
              ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900'
          }`}
        >
          <Sparkles className="w-4 h-4" />
          <span>Quick Sample Notes</span>
        </button>

        <button
          onClick={() => setActiveMode('camera')}
          className={`flex-1 py-2 text-sm font-medium rounded-lg transition-all flex items-center justify-center space-x-2 ${
            activeMode === 'camera'
              ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900'
          }`}
        >
          <Camera className="w-4 h-4" />
          <span>Live Camera</span>
        </button>

        <button
          onClick={() => setActiveMode('upload')}
          className={`flex-1 py-2 text-sm font-medium rounded-lg transition-all flex items-center justify-center space-x-2 ${
            activeMode === 'upload'
              ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
              : 'text-slate-600 dark:text-slate-400 hover:text-slate-900'
          }`}
        >
          <Upload className="w-4 h-4" />
          <span>Gallery &amp; Upload</span>
        </button>
      </div>

      {/* 1. SAMPLES MODE */}
      {activeMode === 'samples' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-sm font-semibold text-slate-700 dark:text-slate-300">
              Select a sample handwritten document to test real OCR transcription immediately:
            </span>
            <span className="text-xs text-blue-600 dark:text-blue-400 font-medium">
              1-Click Instant Test
            </span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {SAMPLE_NOTES.map((sample) => (
              <div
                key={sample.id}
                onClick={() => handleSelectSample(sample)}
                className="group relative cursor-pointer rounded-2xl bg-white dark:bg-slate-800 p-4 border border-slate-200 dark:border-slate-700 hover:border-blue-500 dark:hover:border-blue-500 shadow-sm hover:shadow-md transition-all flex flex-col justify-between"
              >
                <div>
                  <div className="aspect-[4/3] w-full rounded-xl overflow-hidden bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-700/50 mb-3 relative">
                    <img
                      src={sample.previewUrl}
                      alt={sample.title}
                      className="w-full h-full object-cover object-top group-hover:scale-102 transition-transform duration-300"
                    />
                    <div className="absolute top-2 right-2 px-2 py-0.5 rounded-full text-[11px] font-semibold bg-blue-600 text-white shadow-sm">
                      {sample.language}
                    </div>
                  </div>

                  <h3 className="font-bold text-base text-slate-900 dark:text-white group-hover:text-blue-600 dark:group-hover:text-blue-400 transition-colors">
                    {sample.title}
                  </h3>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 line-clamp-2">
                    {sample.description}
                  </p>
                </div>

                <div className="mt-4 pt-3 border-t border-slate-100 dark:border-slate-700/60 flex items-center justify-between text-xs font-semibold text-blue-600 dark:text-blue-400">
                  <span>Enhance &amp; Recognize</span>
                  <span className="group-hover:translate-x-1 transition-transform">→</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* 2. CAMERA MODE */}
      {activeMode === 'camera' && (
        <div className="relative rounded-2xl overflow-hidden bg-black aspect-[4/3] sm:aspect-[16/10] flex flex-col items-center justify-center border border-slate-700 shadow-xl">
          {cameraError ? (
            <div className="p-6 text-center max-w-md text-white">
              <AlertCircle className="w-12 h-12 text-amber-400 mx-auto mb-3" />
              <h3 className="text-lg font-bold mb-2">Camera Unavailable</h3>
              <p className="text-sm text-slate-300 mb-4">{cameraError}</p>
              <div className="flex justify-center gap-3">
                <button
                  onClick={startCamera}
                  className="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-xl text-sm font-medium transition-colors"
                >
                  Retry Camera
                </button>
                <button
                  onClick={() => setActiveMode('upload')}
                  className="px-4 py-2 bg-slate-800 hover:bg-slate-700 text-white rounded-xl text-sm font-medium transition-colors"
                >
                  Upload File Instead
                </button>
              </div>
            </div>
          ) : (
            <>
              {/* Video Element */}
              <video
                ref={videoRef}
                playsInline
                autoPlay
                muted
                className="w-full h-full object-cover"
              />

              {/* Flash / Light simulation overlay */}
              {flashEnabled && <div className="absolute inset-0 bg-white/20 pointer-events-none" />}

              {/* Document Alignment Grid */}
              {showGrid && (
                <div className="absolute inset-0 pointer-events-none grid grid-cols-3 grid-rows-3 border border-white/20">
                  <div className="border-r border-b border-white/20" />
                  <div className="border-r border-b border-white/20" />
                  <div className="border-b border-white/20" />
                  <div className="border-r border-b border-white/20" />
                  <div className="border-r border-b border-white/20" />
                  <div className="border-b border-white/20" />
                  <div className="border-r border-white/20" />
                  <div className="border-r border-white/20" />
                  <div className="" />
                </div>
              )}

              {/* Top Viewfinder Controls */}
              <div className="absolute top-4 inset-x-4 flex items-center justify-between z-10">
                <button
                  onClick={() => setShowGrid(!showGrid)}
                  className={`p-2.5 rounded-full backdrop-blur-md transition-colors ${
                    showGrid ? 'bg-blue-600 text-white' : 'bg-black/40 text-white hover:bg-black/60'
                  }`}
                  title="Toggle Document Grid"
                >
                  <Grid className="w-5 h-5" />
                </button>

                <button
                  onClick={() => setFlashEnabled(!flashEnabled)}
                  className={`p-2.5 rounded-full backdrop-blur-md transition-colors ${
                    flashEnabled ? 'bg-amber-500 text-white' : 'bg-black/40 text-white hover:bg-black/60'
                  }`}
                  title="Toggle Flash / Torch"
                >
                  {flashEnabled ? <Zap className="w-5 h-5" /> : <ZapOff className="w-5 h-5" />}
                </button>

                <button
                  onClick={toggleFacingMode}
                  className="p-2.5 rounded-full bg-black/40 text-white hover:bg-black/60 backdrop-blur-md transition-colors"
                  title="Switch Camera (Front/Back)"
                >
                  <SwitchCamera className="w-5 h-5" />
                </button>
              </div>

              {/* Bottom Viewfinder Shutter Button */}
              <div className="absolute bottom-6 inset-x-0 flex items-center justify-center z-10">
                <button
                  onClick={captureSnapshot}
                  className="group relative w-18 h-18 rounded-full border-4 border-white flex items-center justify-center bg-white/30 backdrop-blur-md hover:bg-white/50 active:scale-95 transition-all shadow-lg"
                  title="Capture Handwritten Document"
                >
                  <div className="w-13 h-13 rounded-full bg-white group-hover:scale-95 transition-transform" />
                </button>
              </div>
            </>
          )}
        </div>
      )}

      {/* 3. UPLOAD MODE */}
      {activeMode === 'upload' && (
        <div
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
          onClick={() => fileInputRef.current?.click()}
          className={`border-2 border-dashed rounded-3xl p-8 sm:p-12 text-center cursor-pointer transition-all flex flex-col items-center justify-center min-h-[320px] ${
            dragActive
              ? 'border-blue-500 bg-blue-50/50 dark:bg-blue-950/20 scale-[0.99]'
              : 'border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800/60 hover:border-blue-400 dark:hover:border-blue-600'
          }`}
        >
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            onChange={handleFileUpload}
            className="hidden"
          />

          <div className="w-16 h-16 rounded-2xl bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-400 flex items-center justify-center mb-4 shadow-sm">
            <FileImage className="w-8 h-8" />
          </div>

          <h3 className="text-lg font-bold text-slate-900 dark:text-white">
            Choose a handwritten photo or drag &amp; drop
          </h3>
          <p className="text-sm text-slate-500 dark:text-slate-400 max-w-sm mt-1 mb-4">
            Supports JPEG, PNG, WEBP, and scanned documents up to 25MB. You can also paste directly
            using <kbd className="px-1.5 py-0.5 text-xs bg-slate-100 dark:bg-slate-700 rounded border">Ctrl + V</kbd>.
          </p>

          <button
            type="button"
            className="px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-medium text-sm shadow-md shadow-blue-500/20 transition-all"
          >
            Browse Photo Gallery
          </button>
        </div>
      )}

      {/* Supported Script Badge Footer */}
      <div className="bg-slate-100 dark:bg-slate-800/50 p-4 rounded-xl border border-slate-200 dark:border-slate-700/50 flex items-start space-x-3">
        <Info className="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0 mt-0.5" />
        <div className="text-xs text-slate-600 dark:text-slate-300">
          <p className="font-semibold text-slate-800 dark:text-slate-200">
            Selected OCR Language: {currentLangObj.name} ({currentLangObj.nativeName}) — {currentLangObj.script}
          </p>
          <p className="mt-0.5">
            Engine status: <strong>{currentLangObj.supportLevel} handwriting support</strong>. Our model recognizes
            cursive English, Devanagari (Hindi, Marathi), Tamil, Bengali, Gujarati, Telugu, Kannada, Punjabi, Malayalam, and Urdu with paragraph and formatting preservation.
          </p>
        </div>
      </div>
    </div>
  );
};
