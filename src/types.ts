export interface OcrResult {
  text: string;
  detectedLanguage: string;
  languageCode: string;
  confidenceScore: number;
  confidenceRating: 'HIGH' | 'MEDIUM' | 'LOW';
  wordCount: number;
  lineCount: number;
  warnings: string[];
  processingTimeMs: number;
  timestamp?: string;
}

export interface SupportedLanguage {
  code: string;
  name: string;
  nativeName: string;
  script: string;
  supportLevel: 'Full' | 'High' | 'Medium' | 'Experimental';
  flag?: string;
}

export interface ScannedDocument {
  id: string;
  title: string;
  rawText: string;
  editedText: string;
  imageThumbnail?: string;
  detectedLanguage: string;
  confidenceScore: number;
  confidenceRating: 'HIGH' | 'MEDIUM' | 'LOW';
  wordCount: number;
  lineCount: number;
  createdAt: string;
  updatedAt: string;
  tags?: string[];
}

export interface ImageAdjustments {
  rotation: number; // 0, 90, 180, 270
  straightenAngle: number; // -30 to 30 degrees
  brightness: number; // -50 to 50
  contrast: number; // -50 to 50
  filter: 'none' | 'binarize' | 'grayscale' | 'magic_sharp' | 'warm';
  cropRect?: {
    x: number;
    y: number;
    width: number;
    height: number;
  };
}

export interface BackendHealth {
  status: string;
  service: string;
  version: string;
  ocrProvider: string;
  model: string;
  configured: boolean;
  supportedLanguagesCount: number;
  timestamp: string;
}

export type AppTab = 'scanner' | 'editor' | 'history' | 'flutter_code' | 'settings';
