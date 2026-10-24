import { jsPDF } from 'jspdf';
import { ScannedDocument } from '../types';

export function exportDocumentToPdf(doc: ScannedDocument): void {
  const pdf = new jsPDF({
    orientation: 'portrait',
    unit: 'mm',
    format: 'a4',
  });

  const pageWidth = pdf.internal.pageSize.getWidth();
  const pageHeight = pdf.internal.pageSize.getHeight();
  const margin = 20;
  const contentWidth = pageWidth - margin * 2;

  // Header band
  pdf.setFillColor(243, 244, 246);
  pdf.rect(0, 0, pageWidth, 28, 'F');

  // App & Document Header
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(14);
  pdf.setTextColor(30, 58, 138); // Deep blue
  pdf.text('WriteScan AI — Transcribed Document', margin, 12);

  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(9);
  pdf.setTextColor(107, 114, 128);
  const dateStr = new Date(doc.createdAt).toLocaleString();
  pdf.text(`Date: ${dateStr}   |   Language: ${doc.detectedLanguage}   |   Confidence: ${doc.confidenceScore}%`, margin, 18);
  pdf.text(`Word count: ${doc.wordCount} words   |   Doc ID: ${doc.id.slice(0, 8)}`, margin, 23);

  // Document Title
  let currentY = 38;
  pdf.setFont('helvetica', 'bold');
  pdf.setFontSize(16);
  pdf.setTextColor(17, 24, 39);
  pdf.text(doc.title, margin, currentY);

  currentY += 8;
  pdf.setDrawColor(229, 231, 235);
  pdf.setLineWidth(0.5);
  pdf.line(margin, currentY, pageWidth - margin, currentY);
  currentY += 8;

  // Text Body
  pdf.setFont('helvetica', 'normal');
  pdf.setFontSize(10.5);
  pdf.setTextColor(31, 41, 55);

  const lines = pdf.splitTextToSize(doc.editedText || doc.rawText, contentWidth);
  const lineHeight = 5.8;

  for (let i = 0; i < lines.length; i++) {
    if (currentY + lineHeight > pageHeight - margin) {
      pdf.addPage();
      currentY = margin;
      // Footer page count can be added if desired
    }
    pdf.text(lines[i], margin, currentY);
    currentY += lineHeight;
  }

  // Footer on last page
  const fileName = `${doc.title.replace(/[^a-zA-Z0-9_\u0900-\u097F\u0B80-\u0BFF-]/g, '_') || 'document'}.pdf`;
  pdf.save(fileName);
}

export function exportDocumentToTxt(doc: ScannedDocument): void {
  const content = `================================================
${doc.title}
Date: ${new Date(doc.createdAt).toLocaleString()}
Language: ${doc.detectedLanguage} | Confidence: ${doc.confidenceScore}%
Transcribed via WriteScan AI
================================================

${doc.editedText || doc.rawText}
`;

  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${doc.title.replace(/[^a-zA-Z0-9_-]/g, '_') || 'document'}.txt`;
  link.click();
  URL.revokeObjectURL(url);
}

export function exportDocumentToMarkdown(doc: ScannedDocument): void {
  const content = `# ${doc.title}

> **Transcribed by WriteScan AI**  
> **Date:** ${new Date(doc.createdAt).toLocaleDateString()} | **Language:** ${doc.detectedLanguage} | **Accuracy Confidence:** ${doc.confidenceScore}%  

---

${doc.editedText || doc.rawText}
`;

  const blob = new Blob([content], { type: 'text/markdown;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `${doc.title.replace(/[^a-zA-Z0-9_-]/g, '_') || 'document'}.md`;
  link.click();
  URL.revokeObjectURL(url);
}
