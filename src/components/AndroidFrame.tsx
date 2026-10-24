import React, { useState, useEffect } from 'react';
import { Wifi, Battery, Signal } from 'lucide-react';

interface AndroidFrameProps {
  children: React.ReactNode;
  enabled: boolean;
}

export const AndroidFrame: React.FC<AndroidFrameProps> = ({ children, enabled }) => {
  const [currentTime, setCurrentTime] = useState('10:30');

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setCurrentTime(
        now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', hour12: false })
      );
    };
    updateTime();
    const interval = setInterval(updateTime, 30000);
    return () => clearInterval(interval);
  }, []);

  if (!enabled) {
    return <div className="w-full min-h-[calc(100vh-4rem)]">{children}</div>;
  }

  return (
    <div className="py-6 px-2 sm:px-4 flex justify-center items-center bg-slate-100 dark:bg-slate-950 min-h-[calc(100vh-4rem)]">
      {/* Outer Phone Shell */}
      <div className="relative w-full max-w-[420px] rounded-[48px] bg-slate-900 dark:bg-black p-3.5 shadow-2xl ring-1 ring-slate-800/40 shadow-slate-900/40 transition-all">
        {/* Antenna bands & Volume/Power button hints */}
        <div className="absolute -left-1.5 top-28 w-1 h-12 bg-slate-700 rounded-l-sm" />
        <div className="absolute -left-1.5 top-44 w-1 h-16 bg-slate-700 rounded-l-sm" />
        <div className="absolute -right-1.5 top-32 w-1 h-16 bg-slate-700 rounded-r-sm" />

        {/* Screen Glass */}
        <div className="relative rounded-[38px] overflow-hidden bg-white dark:bg-slate-900 border border-slate-700/50 flex flex-col h-[820px]">
          {/* Android Status Bar */}
          <div className="h-9 px-6 flex items-center justify-between bg-slate-900 text-white text-xs select-none z-20 shrink-0">
            <span className="font-semibold tracking-wide text-[13px]">{currentTime}</span>

            {/* Camera Hole Punch */}
            <div className="w-4 h-4 rounded-full bg-black ring-1 ring-slate-800 flex items-center justify-center">
              <div className="w-1.5 h-1.5 rounded-full bg-slate-900" />
            </div>

            <div className="flex items-center space-x-1.5 text-slate-300">
              <Signal className="w-3.5 h-3.5" />
              <span className="text-[10px] font-bold">5G</span>
              <Wifi className="w-3.5 h-3.5" />
              <Battery className="w-4 h-4" />
            </div>
          </div>

          {/* Screen Body */}
          <div className="flex-1 overflow-y-auto overflow-x-hidden flex flex-col bg-slate-50 dark:bg-slate-900">
            {children}
          </div>

          {/* Android Gesture Bar */}
          <div className="h-6 flex items-center justify-center bg-white dark:bg-slate-900 z-20 shrink-0 border-t border-slate-100 dark:border-slate-800">
            <div className="w-32 h-1 bg-slate-400 dark:bg-slate-600 rounded-full" />
          </div>
        </div>
      </div>
    </div>
  );
};
