import React from 'react';
import {
  FileText,
  Camera,
  Edit3,
  Clock,
  Settings,
  Code2,
  Smartphone,
  Maximize2,
  Moon,
  Sun,
  CheckCircle2,
  AlertTriangle,
} from 'lucide-react';
import { AppTab, BackendHealth } from '../types';

interface HeaderProps {
  currentTab: AppTab;
  onTabChange: (tab: AppTab) => void;
  health: BackendHealth | null;
  historyCount: number;
  hasActiveDocument: boolean;
  viewMode: 'phone' | 'full';
  onToggleViewMode: () => void;
  isDark: boolean;
  onToggleTheme: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  currentTab,
  onTabChange,
  health,
  historyCount,
  hasActiveDocument,
  viewMode,
  onToggleViewMode,
  isDark,
  onToggleTheme,
}) => {
  return (
    <header className="sticky top-0 z-30 bg-white/95 dark:bg-slate-900/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-800 transition-colors">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo & Brand */}
          <div className="flex items-center space-x-3 cursor-pointer" onClick={() => onTabChange('scanner')}>
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-blue-600 via-indigo-600 to-sky-500 flex items-center justify-center text-white shadow-md shadow-indigo-500/20">
              <FileText className="w-5 h-5" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-bold text-lg tracking-tight text-slate-900 dark:text-white">
                  WriteScan <span className="text-blue-600 dark:text-blue-400">AI</span>
                </span>
                <span className="hidden sm:inline-block px-2 py-0.5 text-xs font-semibold bg-blue-100 text-blue-700 dark:bg-blue-900/60 dark:text-blue-300 rounded-full">
                  Material 3
                </span>
              </div>
              <p className="text-xs text-slate-500 dark:text-slate-400 hidden sm:block">
                Handwriting to Text OCR • Multi-Script Engine
              </p>
            </div>
          </div>

          {/* Center Tabs Navigation */}
          <nav className="hidden md:flex items-center space-x-1 bg-slate-100 dark:bg-slate-800/80 p-1 rounded-xl">
            <button
              onClick={() => onTabChange('scanner')}
              className={`flex items-center space-x-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                currentTab === 'scanner'
                  ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
                  : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              <Camera className="w-4 h-4" />
              <span>Scanner &amp; Studio</span>
            </button>

            <button
              onClick={() => onTabChange('editor')}
              disabled={!hasActiveDocument}
              title={!hasActiveDocument ? 'Scan or select a document first' : undefined}
              className={`flex items-center space-x-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                currentTab === 'editor'
                  ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
                  : hasActiveDocument
                  ? 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
                  : 'text-slate-300 dark:text-slate-600 cursor-not-allowed'
              }`}
            >
              <Edit3 className="w-4 h-4" />
              <span>Editor</span>
            </button>

            <button
              onClick={() => onTabChange('history')}
              className={`flex items-center space-x-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                currentTab === 'history'
                  ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
                  : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              <Clock className="w-4 h-4" />
              <span>History</span>
              {historyCount > 0 && (
                <span className="ml-1 px-1.5 py-0.2 text-xs font-semibold bg-blue-100 dark:bg-blue-900/60 text-blue-700 dark:text-blue-300 rounded-full">
                  {historyCount}
                </span>
              )}
            </button>

            <button
              onClick={() => onTabChange('flutter_code')}
              className={`flex items-center space-x-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                currentTab === 'flutter_code'
                  ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
                  : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              <Code2 className="w-4 h-4" />
              <span>Flutter App Code</span>
            </button>

            <button
              onClick={() => onTabChange('settings')}
              className={`flex items-center space-x-2 px-3 py-1.5 rounded-lg text-sm font-medium transition-all ${
                currentTab === 'settings'
                  ? 'bg-white dark:bg-slate-700 text-blue-600 dark:text-blue-300 shadow-sm'
                  : 'text-slate-600 dark:text-slate-300 hover:text-slate-900 dark:hover:text-white'
              }`}
            >
              <Settings className="w-4 h-4" />
              <span>Settings</span>
            </button>
          </nav>

          {/* Right Controls: OCR Status, Frame Toggle, Dark Mode */}
          <div className="flex items-center space-x-2">
            {/* Backend OCR engine status indicator */}
            <div
              className={`hidden lg:flex items-center space-x-1.5 px-2.5 py-1 rounded-full text-xs font-medium border ${
                health?.configured
                  ? 'bg-emerald-50 dark:bg-emerald-950/40 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800'
                  : 'bg-amber-50 dark:bg-amber-950/40 text-amber-700 dark:text-amber-300 border-amber-200 dark:border-amber-800'
              }`}
            >
              {health?.configured ? (
                <>
                  <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
                  <span>OCR Engine Ready</span>
                </>
              ) : (
                <>
                  <AlertTriangle className="w-3.5 h-3.5 text-amber-600 dark:text-amber-400" />
                  <span>Attach Key in Secrets</span>
                </>
              )}
            </div>

            {/* Mobile frame vs Fullscreen toggle */}
            <button
              onClick={onToggleViewMode}
              title={viewMode === 'phone' ? 'Switch to Full Screen View' : 'Switch to Android Phone View'}
              className="p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            >
              {viewMode === 'phone' ? (
                <Maximize2 className="w-4 h-4" />
              ) : (
                <Smartphone className="w-4 h-4" />
              )}
            </button>

            {/* Dark mode toggle */}
            <button
              onClick={onToggleTheme}
              title={isDark ? 'Switch to Light Theme' : 'Switch to Dark Theme'}
              className="p-2 rounded-xl text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors"
            >
              {isDark ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4" />}
            </button>
          </div>
        </div>
      </div>

      {/* Mobile Bottom Tab Bar for smaller screens */}
      <div className="md:hidden flex items-center justify-around border-t border-slate-200 dark:border-slate-800 bg-white/95 dark:bg-slate-900/95 py-2 px-1">
        <button
          onClick={() => onTabChange('scanner')}
          className={`flex flex-col items-center py-1 px-2 text-xs ${
            currentTab === 'scanner' ? 'text-blue-600 dark:text-blue-400 font-semibold' : 'text-slate-500'
          }`}
        >
          <Camera className="w-5 h-5 mb-0.5" />
          <span>Scanner</span>
        </button>

        <button
          onClick={() => onTabChange('editor')}
          disabled={!hasActiveDocument}
          className={`flex flex-col items-center py-1 px-2 text-xs ${
            currentTab === 'editor'
              ? 'text-blue-600 dark:text-blue-400 font-semibold'
              : hasActiveDocument
              ? 'text-slate-500'
              : 'text-slate-300 dark:text-slate-600'
          }`}
        >
          <Edit3 className="w-5 h-5 mb-0.5" />
          <span>Editor</span>
        </button>

        <button
          onClick={() => onTabChange('history')}
          className={`flex flex-col items-center py-1 px-2 text-xs relative ${
            currentTab === 'history' ? 'text-blue-600 dark:text-blue-400 font-semibold' : 'text-slate-500'
          }`}
        >
          <Clock className="w-5 h-5 mb-0.5" />
          <span>History</span>
          {historyCount > 0 && (
            <span className="absolute top-0 right-1 px-1 text-[10px] bg-blue-600 text-white rounded-full">
              {historyCount}
            </span>
          )}
        </button>

        <button
          onClick={() => onTabChange('flutter_code')}
          className={`flex flex-col items-center py-1 px-2 text-xs ${
            currentTab === 'flutter_code' ? 'text-blue-600 dark:text-blue-400 font-semibold' : 'text-slate-500'
          }`}
        >
          <Code2 className="w-5 h-5 mb-0.5" />
          <span>Flutter</span>
        </button>

        <button
          onClick={() => onTabChange('settings')}
          className={`flex flex-col items-center py-1 px-2 text-xs ${
            currentTab === 'settings' ? 'text-blue-600 dark:text-blue-400 font-semibold' : 'text-slate-500'
          }`}
        >
          <Settings className="w-5 h-5 mb-0.5" />
          <span>Settings</span>
        </button>
      </div>
    </header>
  );
};
