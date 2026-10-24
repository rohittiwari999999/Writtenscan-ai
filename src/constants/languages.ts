import { SupportedLanguage } from '../types';

export const LANGUAGES: SupportedLanguage[] = [
  { code: 'auto', name: 'Auto Detect', nativeName: 'Auto Detect Script', script: 'Multilingual / Any', supportLevel: 'Full' },
  { code: 'en', name: 'English', nativeName: 'English', script: 'Latin (Cursive, Print, Draft)', supportLevel: 'Full' },
  { code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', script: 'Devanagari (देवनागरी)', supportLevel: 'Full' },
  { code: 'bn', name: 'Bengali', nativeName: 'বাংলা', script: 'Bengali-Assamese (বাংলা)', supportLevel: 'High' },
  { code: 'mr', name: 'Marathi', nativeName: 'मराठी', script: 'Devanagari (देवनागरी)', supportLevel: 'High' },
  { code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', script: 'Tamil (தமிழ் எழுத்துமுறை)', supportLevel: 'High' },
  { code: 'te', name: 'Telugu', nativeName: 'తెలుగు', script: 'Telugu (తెలుగు లిపి)', supportLevel: 'High' },
  { code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', script: 'Gujarati (ગુજરાતી લિપિ)', supportLevel: 'High' },
  { code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', script: 'Kannada (ಕನ್ನಡ ಲಿಪಿ)', supportLevel: 'High' },
  { code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', script: 'Malayalam (മലയാളലിപി)', supportLevel: 'High' },
  { code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', script: 'Gurmukhi (ਗੁਰਮੁਖੀ)', supportLevel: 'High' },
  { code: 'ur', name: 'Urdu', nativeName: 'اردو', script: 'Nastaliq / Arabic (نستعلیق)', supportLevel: 'Medium' },
  { code: 'es', name: 'Spanish', nativeName: 'Español', script: 'Latin', supportLevel: 'Full' },
  { code: 'fr', name: 'French', nativeName: 'Français', script: 'Latin', supportLevel: 'Full' },
  { code: 'de', name: 'German', nativeName: 'Deutsch', script: 'Latin', supportLevel: 'Full' },
  { code: 'zh', name: 'Chinese', nativeName: '中文', script: 'Hanzi (Simplified & Traditional)', supportLevel: 'High' },
  { code: 'ja', name: 'Japanese', nativeName: '日本語', script: 'Kanji & Kana (草書体)', supportLevel: 'High' },
  { code: 'ar', name: 'Arabic', nativeName: 'العربية', script: 'Arabic Script (الرقعة / النسخ)', supportLevel: 'Medium' },
];
