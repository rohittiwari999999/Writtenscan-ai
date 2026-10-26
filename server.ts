import express, { Request, Response } from 'express';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import { GoogleGenAI, Type } from '@google/genai';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 3000;

// Allow large image uploads (scanned 4K documents in Base64)
app.use(express.json({ limit: '30mb' }));
app.use(express.urlencoded({ extended: true, limit: '30mb' }));

// Supported languages catalog
export const SUPPORTED_LANGUAGES = [
  { code: 'auto', name: 'Auto Detect', nativeName: 'Auto Detect', script: 'Any', supportLevel: 'Full' },
  { code: 'en', name: 'English', nativeName: 'English', script: 'Latin (Cursive & Print)', supportLevel: 'Full' },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', script: 'Devanagari', supportLevel: 'Full' },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা', script: 'Bengali-Assamese', supportLevel: 'High' },
  { code: 'mr', name: 'Marathi', nativeName: 'मराठी', script: 'Devanagari', supportLevel: 'High' },
  { code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', script: 'Tamil', supportLevel: 'High' },
  { code: 'te', name: 'Telugu', nativeName: 'తెలుగు', script: 'Telugu', supportLevel: 'High' },
  { code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', script: 'Gujarati', supportLevel: 'High' },
  { code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', script: 'Kannada', supportLevel: 'High' },
  { code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', script: 'Malayalam', supportLevel: 'High' },
  { code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', script: 'Gurmukhi', supportLevel: 'High' },
  { code: 'ur', name: 'Urdu', nativeName: 'اردو', script: 'Nastaliq / Arabic', supportLevel: 'Medium' },
  { code: 'es', name: 'Spanish', nativeName: 'Español', script: 'Latin', supportLevel: 'Full' },
  { code: 'fr', name: 'French', nativeName: 'Français', script: 'Latin', supportLevel: 'Full' },
  { code: 'de', name: 'German', nativeName: 'Deutsch', script: 'Latin', supportLevel: 'Full' },
  { code: 'zh', name: 'Chinese', nativeName: '中文', script: 'Hanzi (Simplified/Traditional)', supportLevel: 'High' },
  { code: 'ja', name: 'Japanese', nativeName: '日本語', script: 'Kanji & Kana', supportLevel: 'High' },
  { code: 'ar', name: 'Arabic', nativeName: 'العربية', script: 'Arabic', supportLevel: 'Medium' },
];

// Initialize GoogleGenAI client
function getAIClient() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    return null;
  }
  return new GoogleGenAI({
    apiKey,
    httpOptions: {
      headers: {
        'User-Agent': 'aistudio-build',
      },
    },
  });
}

// 1. Health check & configuration status
app.get('/api/health', (_req: Request, res: Response) => {
  const hasKey = Boolean(process.env.GEMINI_API_KEY && process.env.GEMINI_API_KEY.trim().length > 0);
  res.json({
    status: 'ok',
    service: 'WriteScan AI OCR Engine',
    version: '2.4.0',
    ocrProvider: 'Google Gemini Vision 3.8 Flash (Document & Handwriting Multimodal Engine)',
    model: 'gemini-3.8-flash',
    configured: hasKey,
    supportedLanguagesCount: SUPPORTED_LANGUAGES.length,
    timestamp: new Date().toISOString(),
  });
});

// 2. Language list
app.get('/api/ocr/languages', (_req: Request, res: Response) => {
  res.json({
    languages: SUPPORTED_LANGUAGES,
  });
});

// 3. Real Handwriting Recognition endpoint
app.post('/api/ocr/recognize', async (req: Request, res: Response) => {
  const startTime = Date.now();
  try {
    const { imageBase64, mimeType = 'image/jpeg', language = 'auto', preserveLayout = true } = req.body;

    if (!imageBase64 || typeof imageBase64 !== 'string') {
      res.status(400).json({
        error: 'INVALID_INPUT',
        message: 'No image data provided. Please supply base64-encoded image data.',
      });
      return;
    }

    // Strip data URL header if present (e.g. data:image/jpeg;base64,...)
    let cleanBase64 = imageBase64;
    let detectedMime = mimeType;
    if (imageBase64.includes(';base64,')) {
      const parts = imageBase64.split(';base64,');
      cleanBase64 = parts[1];
      const mimeMatch = parts[0].match(/data:(image\/[a-zA-Z0-9.+_-]+)/);
      if (mimeMatch && mimeMatch[1]) {
        detectedMime = mimeMatch[1];
      }
    }

    // Inspect magic bytes if mimeType is default or unspecified
    if (detectedMime === 'image/jpeg' || !detectedMime) {
      if (cleanBase64.startsWith('iVBORw0KGgo')) {
        detectedMime = 'image/png';
      } else if (cleanBase64.startsWith('UklGR')) {
        detectedMime = 'image/webp';
      } else if (cleanBase64.startsWith('/9j/')) {
        detectedMime = 'image/jpeg';
      }
    }

    // Verify cleaned base64
    if (cleanBase64.length < 50) {
      res.status(400).json({
        error: 'IMAGE_TOO_SMALL',
        message: 'Supplied image base64 is empty or too small to be a valid document.',
      });
      return;
    }

    const ai = getAIClient();
    if (!ai) {
      res.status(503).json({
        error: 'API_KEY_NOT_CONFIGURED',
        message: 'GEMINI_API_KEY is not configured in the environment. Please configure your API key in AI Studio Settings > Secrets.',
        configured: false,
      });
      return;
    }

    // Language hint construction
    const targetLang = SUPPORTED_LANGUAGES.find((l) => l.code === language);
    const langPrompt =
      language && language !== 'auto' && targetLang
        ? `The user specified the primary expected language/script is: ${targetLang.name} (${targetLang.nativeName}, script: ${targetLang.script}). Prioritize recognizing this script accurately.`
        : 'Auto-detect the language or multiple languages present (e.g. English, Hindi, Devanagari, Tamil, etc.).';

    const systemInstruction = `You are WriteScan AI, an enterprise-grade OCR and Handwriting Recognition specialist engine.
Your mission is to accurately transcribe handwritten text, cursive handwriting, printed text, mixed script notes, formulas, lists, signatures, and document annotations from images.

CRITICAL RULES:
1. Faithfully extract and transcribe EXACTLY what is handwritten in the image.
2. Maintain reading order: top-to-bottom, left-to-right (or right-to-left for Urdu/Arabic).
3. Preserve paragraph breaks, line breaks, bullet points, numbering, and table/list alignments.
4. If a word or character is ambiguous or scribbled, use surrounding context to decipher the intended word. If completely illegible, transcribe best phonetic approximation or indicate [illegible].
5. Correctly handle Indian languages (Hindi, Bengali, Tamil, Telugu, Marathi, Gujarati, Kannada, Malayalam, Punjabi, Urdu) in their native Unicode scripts (not Latin transliteration unless the writer wrote Hinglish/Tanglish).
6. Never fabricate or invent text that does not exist in the image.
7. Return clean structured JSON conforming to the schema provided.`;

    const promptText = `Analyze this handwritten document image and transcribe all handwritten and printed text.
${langPrompt}
${preserveLayout ? 'Preserve line breaks, indentations, and vertical flow.' : 'Provide fluid continuous text.'}

Return your transcription in JSON with:
- text: full transcribed text string with exact line breaks (\\n) and paragraphs
- detectedLanguage: primary detected language name (e.g., "Hindi", "English", "Tamil", "Bilingual English/Hindi")
- languageCode: ISO code or 'mixed'
- confidenceScore: integer 0-100 indicating OCR transcription fidelity and clarity
- confidenceRating: "HIGH" (clear, high confidence), "MEDIUM" (some cursive/faint ambiguity), or "LOW" (very faded/difficult)
- wordCount: total count of transcribed words
- lineCount: total number of distinct text lines
- warnings: list of any observational notes (e.g. "Slight glare in top corner", "Cursive cursive font", "Marginal note included")`;

    // Generate content with 1 automatic retry on transient spikes (503/UNAVAILABLE)
    let response: any;
    let attempts = 0;
    while (attempts < 2) {
      try {
        attempts++;
        response = await ai.models.generateContent({
          model: 'gemini-3.8-flash',
          contents: {
            parts: [
              {
                inlineData: {
                  data: cleanBase64,
                  mimeType: detectedMime || 'image/jpeg',
                },
              },
              {
                text: promptText,
              },
            ],
          },
          config: {
            systemInstruction,
            temperature: 0.1, // Low temperature for high accuracy OCR transcription
            responseMimeType: 'application/json',
            responseSchema: {
              type: Type.OBJECT,
              properties: {
                text: {
                  type: Type.STRING,
                  description: 'The transcribed text preserving line breaks and original layout.',
                },
                detectedLanguage: {
                  type: Type.STRING,
                  description: 'The primary language identified in the handwriting.',
                },
                languageCode: {
                  type: Type.STRING,
                  description: 'ISO code e.g. en, hi, ta, te, bn, mr, etc.',
                },
                confidenceScore: {
                  type: Type.INTEGER,
                  description: 'Estimated transcription accuracy from 0 to 100.',
                },
                confidenceRating: {
                  type: Type.STRING,
                  description: 'HIGH, MEDIUM, or LOW.',
                },
                wordCount: {
                  type: Type.INTEGER,
                  description: 'Estimated word count of extracted text.',
                },
                lineCount: {
                  type: Type.INTEGER,
                  description: 'Number of transcribed lines.',
                },
                warnings: {
                  type: Type.ARRAY,
                  items: { type: Type.STRING },
                  description: 'Any document clarity or transcription remarks.',
                },
              },
              required: ['text', 'detectedLanguage', 'confidenceScore', 'confidenceRating'],
            },
          },
        });
        break; // Success
      } catch (genError: any) {
        const errorMsg = genError?.message || '';
        if (attempts < 2 && (errorMsg.includes('503') || errorMsg.includes('UNAVAILABLE') || errorMsg.includes('high demand'))) {
          await new Promise((resolve) => setTimeout(resolve, 1200));
          continue;
        }
        throw genError;
      }
    }

    const rawResponseText = response?.text || '{}';
    let parsedData: any = {};
    try {
      parsedData = JSON.parse(rawResponseText);
    } catch {
      // Fallback if formatting was non-standard
      parsedData = {
        text: rawResponseText,
        detectedLanguage: 'Auto-detected',
        languageCode: 'auto',
        confidenceScore: 85,
        confidenceRating: 'MEDIUM',
        wordCount: rawResponseText.split(/\s+/).filter(Boolean).length,
        lineCount: rawResponseText.split('\n').length,
        warnings: [],
      };
    }

    const processingTimeMs = Date.now() - startTime;

    res.json({
      success: true,
      text: parsedData.text || '',
      detectedLanguage: parsedData.detectedLanguage || 'English',
      languageCode: parsedData.languageCode || 'en',
      confidenceScore: typeof parsedData.confidenceScore === 'number' ? parsedData.confidenceScore : 90,
      confidenceRating: parsedData.confidenceRating || 'HIGH',
      wordCount: parsedData.wordCount || (parsedData.text ? parsedData.text.split(/\s+/).filter(Boolean).length : 0),
      lineCount: parsedData.lineCount || (parsedData.text ? parsedData.text.split('\n').length : 0),
      warnings: Array.isArray(parsedData.warnings) ? parsedData.warnings : [],
      processingTimeMs,
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    console.error('Error during OCR recognition:', error);
    const processingTimeMs = Date.now() - startTime;
    let cleanMessage = error?.message || 'An error occurred while recognizing handwriting from the image.';
    try {
      // If error message is a serialized Google JSON error, extract the user-friendly inner message
      const parsedError = JSON.parse(cleanMessage);
      if (parsedError?.error?.message) {
        cleanMessage = parsedError.error.message;
      }
    } catch {
      // Not JSON, keep original string
    }

    res.status(500).json({
      success: false,
      error: 'OCR_PROCESSING_FAILED',
      message: cleanMessage,
      processingTimeMs,
    });
  }
});

// Setup Vite middleware in dev or static files in production
async function startServer() {
  const isProd = process.env.NODE_ENV === 'production';

  if (!isProd) {
    const { createServer } = await import('vite');
    const vite = await createServer({
      server: {
        middlewareMode: true,
        hmr: false,
      },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(path.resolve(__dirname, 'dist')));
    app.get('*', (_req: Request, res: Response) => {
      res.sendFile(path.resolve(__dirname, 'dist', 'index.html'));
    });
  }

  const server = app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 WriteScan AI Server running on http://0.0.0.0:${PORT}`);
  });

  server.on('error', (err: any) => {
    if (err.code === 'EADDRINUSE') {
      console.warn(`Port ${PORT} in use, waiting 1s before retry...`);
      setTimeout(() => {
        try {
          server.close();
        } catch {}
        server.listen(PORT, '0.0.0.0');
      }, 1000);
    } else {
      console.error('Server error:', err);
    }
  });
}

startServer().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
