// High quality synthetic handwritten document images encoded as Data URIs
// These provide instant, reliable test documents for testing real OCR recognition across English, Hindi, Tamil & Checklists.

function svgToDataUrl(svgString: string): string {
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svgString)}`;
}

// 1. English Lecture & Meeting Notes
const englishNoteSvg = `
<svg width="800" height="1000" viewBox="0 0 800 1000" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="paper-texture">
      <feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="3" result="noise" />
      <feDiffuseLighting in="noise" lighting-color="#fffdf8" surfaceScale="1.2" result="light">
        <feDistantLight azimuth="45" elevation="60" />
      </feDiffuseLighting>
      <feBlend mode="multiply" in="SourceGraphic" in2="light" />
    </filter>
  </defs>
  <rect width="800" height="1000" fill="#fcf9f0" />
  <!-- Ruled notebook lines -->
  <line x1="80" y1="0" x2="80" y2="1000" stroke="#fca5a5" stroke-width="1.5" />
  ${Array.from({ length: 22 }, (_, i) => `<line x1="0" y1="${120 + i * 38}" x2="800" y2="${120 + i * 38}" stroke="#bfdbfe" stroke-width="1" />`).join('\n')}
  
  <g font-family="Caveat, 'Segoe Script', cursive, sans-serif" fill="#1e3a8a">
    <text x="110" y="95" font-size="28" font-weight="bold" fill="#0f172a">Meeting &amp; Project Notes — Oct 24</text>
    <text x="110" y="148" font-size="22" font-style="italic">1. Client requirements review completed with team.</text>
    <text x="110" y="186" font-size="22">2. Need to optimize handwriting recognition OCR model:</text>
    <text x="140" y="224" font-size="21">- Target latency: under 1.5 seconds</text>
    <text x="140" y="262" font-size="21">- Support Indian vernacular scripts (Hindi, Tamil, Bengali)</text>
    <text x="140" y="300" font-size="21">- Add deskew and adaptive binarization filter</text>
    <text x="110" y="338" font-size="22">3. Action Items for release v1.0:</text>
    <text x="140" y="376" font-size="21">• Camera scanner with flash &amp; grid guide</text>
    <text x="140" y="414" font-size="21">• Full offline-first SQLite history sync</text>
    <text x="140" y="452" font-size="21">• PDF and TXT export with styling</text>
    <text x="110" y="528" font-size="22">Summary formula: Accuracy = (Total Correct Words / Total Words) * 100</text>
    <text x="110" y="566" font-size="21">Sign-off: Dr. A. Sharma (Lead Architect)</text>
    <text x="110" y="604" font-size="20" fill="#475569">Urgent follow-up: Check API key rate limits before launch.</text>
  </g>
</svg>
`;

// 2. Hindi Handwritten Recipe & Cultural Note (Devanagari)
const hindiNoteSvg = `
<svg width="800" height="1000" viewBox="0 0 800 1000" xmlns="http://www.w3.org/2000/svg">
  <rect width="800" height="1000" fill="#fffef5" />
  <line x1="90" y1="0" x2="90" y2="1000" stroke="#f87171" stroke-width="1.5" />
  ${Array.from({ length: 22 }, (_, i) => `<line x1="0" y1="${120 + i * 38}" x2="800" y2="${120 + i * 38}" stroke="#cbd5e1" stroke-width="1" />`).join('\n')}

  <g font-family="'Noto Sans Devanagari', 'Mangal', 'Kruti Dev', sans-serif" fill="#111827">
    <text x="120" y="95" font-size="28" font-weight="bold" fill="#7c2d12">पारंपरिक बादाम-केसर खीर (रेसिपी डायरी)</text>
    <text x="120" y="150" font-size="21">सामग्री सूची:</text>
    <text x="150" y="188" font-size="20">१. १ लीटर ताजा गाय का गाढ़ा दूध</text>
    <text x="150" y="226" font-size="20">२. ५० ग्राम बासमती चावल (आधा घंटा भीगे हुए)</text>
    <text x="150" y="264" font-size="20">३. १५-२० धागे शुद्ध कश्मीरी केसर</text>
    <text x="150" y="302" font-size="20">४. २५ ग्राम कटे हुए काजू, बादाम और पिस्ता</text>
    <text x="150" y="340" font-size="20">५. आधा चम्मच हरी इलायची का ताजा पाउडर</text>
    <text x="120" y="416" font-size="21" font-weight="bold">बनाने की सरल विधि:</text>
    <text x="120" y="454" font-size="20">दूध को धीमी आंच पर उबलने दें जब तक वह एक-तिहाई कम न हो जाए।</text>
    <text x="120" y="492" font-size="20">चावल को हाथ से थोड़ा मसल कर दूध में डालें और लगातार हिलाते रहें।</text>
    <text x="120" y="530" font-size="20">केसर को २ चम्मच गुनगुने दूध में घोलकर डालें।</text>
    <text x="120" y="568" font-size="20">अंत में चीनी और मेवे मिलाकर ५ मिनट पकाएं। गरमा-गरम परोसें।</text>
    <text x="120" y="644" font-size="19" fill="#047857">नोट: चांदी का वर्क और गुलाब की पंखुड़ियों से सजाएं।</text>
  </g>
</svg>
`;

// 3. Tamil Handwritten Journal (Tamil Script)
const tamilNoteSvg = `
<svg width="800" height="1000" viewBox="0 0 800 1000" xmlns="http://www.w3.org/2000/svg">
  <rect width="800" height="1000" fill="#fefce8" />
  <line x1="85" y1="0" x2="85" y2="1000" stroke="#ef4444" stroke-width="1.5" />
  ${Array.from({ length: 22 }, (_, i) => `<line x1="0" y1="${120 + i * 38}" x2="800" y2="${120 + i * 38}" stroke="#e2e8f0" stroke-width="1" />`).join('\n')}

  <g font-family="'Noto Sans Tamil', 'Latha', sans-serif" fill="#1e293b">
    <text x="110" y="95" font-size="26" font-weight="bold" fill="#0f766e">தினசரி குறிப்புகள் — அறிவியல் பாடக் குறிப்பு</text>
    <text x="110" y="150" font-size="20">தலைப்பு: நியூட்டனின் மூன்றாம் இயக்க விதி</text>
    <text x="110" y="195" font-size="19">1. ஒவ்வொரு விசைக்கும் சமமான மற்றும் எதிர் விசை உண்டு.</text>
    <text x="110" y="235" font-size="19">2. ராக்கெட் ஏவுதலில் எரிபொருள் கீழ்நோக்கி வெளியேறுகிறது.</text>
    <text x="110" y="275" font-size="19">3. இதனால் ராக்கெட் மேல்நோக்கி வேகமாக நகர்கிறது.</text>
    <text x="110" y="350" font-size="20" font-weight="bold">முக்கியமான கணக்கீடுகள்:</text>
    <text x="140" y="390" font-size="19">• விசை F = m x a (நிறை பெருக்கல் முடுக்கம்)</text>
    <text x="140" y="430" font-size="19">• உந்த அழிவின்மை விதி: m1v1 + m2v2 = மாறிலி</text>
    <text x="110" y="510" font-size="19">அடுத்த தேர்வு நாள்: திங்கட்கிழமை காலை 10 மணி.</text>
    <text x="110" y="550" font-size="18" fill="#64748b">குறிப்பு: ஆய்வகக் குறிப்பேட்டை வெள்ளிக்கிழமைக்குள் சமர்ப்பிக்கவும்.</text>
  </g>
</svg>
`;

// 4. Grocery & Checklist Note
const checklistNoteSvg = `
<svg width="800" height="1000" viewBox="0 0 800 1000" xmlns="http://www.w3.org/2000/svg">
  <rect width="800" height="1000" fill="#fafafa" />
  <line x1="80" y1="0" x2="80" y2="1000" stroke="#f43f5e" stroke-width="1.5" />
  ${Array.from({ length: 22 }, (_, i) => `<line x1="0" y1="${120 + i * 38}" x2="800" y2="${120 + i * 38}" stroke="#e2e8f0" stroke-width="1" />`).join('\n')}

  <g font-family="'Caveat', cursive, sans-serif" fill="#18181b">
    <text x="110" y="95" font-size="30" font-weight="bold">WEEKLY GROCERY &amp; TASKS LIST</text>
    <text x="110" y="150" font-size="24">[x] 2 Liters Whole Milk</text>
    <text x="110" y="188" font-size="24">[x] Brown Bread &amp; Peanut Butter</text>
    <text x="110" y="226" font-size="24">[ ] Fresh Organic Tomatoes (1 kg)</text>
    <text x="110" y="264" font-size="24">[x] Green Apples &amp; Bananas</text>
    <text x="110" y="302" font-size="24">[ ] Basmati Rice (5 kg bag)</text>
    <text x="110" y="340" font-size="24">[ ] Turmeric Powder &amp; Garam Masala</text>
    <text x="110" y="378" font-size="24">[x] Dark Roast Coffee Beans</text>
    <text x="110" y="454" font-size="26" font-weight="bold" fill="#2563eb">Weekend Reminders:</text>
    <text x="110" y="492" font-size="23">- Pick up laundry by 5:00 PM</text>
    <text x="110" y="530" font-size="23">- Return library books (Algorithms &amp; AI)</text>
    <text x="110" y="568" font-size="23">- Call Grandma at 7:30 PM</text>
    <text x="110" y="606" font-size="22" fill="#71717a">Budget: keep total under $75</text>
  </g>
</svg>
`;

export interface SampleNote {
  id: string;
  title: string;
  language: string;
  description: string;
  previewUrl: string;
}

export const SAMPLE_NOTES: SampleNote[] = [
  {
    id: 'sample-english-notes',
    title: 'Project Review & Math Notes',
    language: 'English',
    description: 'Cursive notes with bullet points, numbered items, and formulas.',
    previewUrl: svgToDataUrl(englishNoteSvg),
  },
  {
    id: 'sample-hindi-recipe',
    title: 'दादी माँ की खीर रेसिपी',
    language: 'Hindi (Devanagari)',
    description: 'Traditional handwritten Hindi recipe notes with numbered cooking steps.',
    previewUrl: svgToDataUrl(hindiNoteSvg),
  },
  {
    id: 'sample-tamil-journal',
    title: 'அறிவியல் பாடக் குறிப்பு (Physics)',
    language: 'Tamil',
    description: 'Handwritten Tamil notes with scientific terms and bullet points.',
    previewUrl: svgToDataUrl(tamilNoteSvg),
  },
  {
    id: 'sample-checklist',
    title: 'Grocery & Weekend Tasks',
    language: 'English',
    description: 'Handwritten checklist with checkboxes, brackets, and budget notes.',
    previewUrl: svgToDataUrl(checklistNoteSvg),
  },
];
