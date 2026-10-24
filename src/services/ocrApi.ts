import { BackendHealth, OcrResult } from '../types';

export async function checkBackendHealth(): Promise<BackendHealth> {
  try {
    const res = await fetch('/api/health');
    if (!res.ok) {
      throw new Error(`Health check returned status ${res.status}`);
    }
    return await res.json();
  } catch (err: any) {
    return {
      status: 'error',
      service: 'WriteScan AI OCR Engine',
      version: '2.4.0',
      ocrProvider: 'Gemini Vision 3.8 Flash',
      model: 'gemini-3.8-flash',
      configured: false,
      supportedLanguagesCount: 0,
      timestamp: new Date().toISOString(),
    };
  }
}

export async function recognizeHandwritingAPI(
  imageBase64: string,
  language = 'auto',
  signal?: AbortSignal
): Promise<OcrResult> {
  const res = await fetch('/api/ocr/recognize', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
    },
    body: JSON.stringify({
      imageBase64,
      language,
      preserveLayout: true,
    }),
    signal,
  });

  const data = await res.json();

  if (!res.ok || !data.success) {
    if (res.status === 503 || data.error === 'API_KEY_NOT_CONFIGURED') {
      throw new Error(
        'Gemini API key is not configured. Please add GEMINI_API_KEY to Settings > Secrets in AI Studio.'
      );
    }
    throw new Error(data.message || data.error || `OCR transcription failed with code ${res.status}`);
  }

  return {
    text: data.text || '',
    detectedLanguage: data.detectedLanguage || 'English',
    languageCode: data.languageCode || 'en',
    confidenceScore: data.confidenceScore ?? 85,
    confidenceRating: data.confidenceRating ?? 'HIGH',
    wordCount: data.wordCount ?? 0,
    lineCount: data.lineCount ?? 0,
    warnings: data.warnings || [],
    processingTimeMs: data.processingTimeMs ?? 0,
    timestamp: data.timestamp,
  };
}
