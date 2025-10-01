import { useState } from 'react';
import ScheduleGenerator from './ScheduleGenerator';
import TimeSlotManager from './TimeSlotManager';

export default function SessionManager() {
  const [activeTab, setActiveTab] = useState('generator');

  return (
    <div className="space-y-6">
      {/* Tab Selector */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-2">
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('generator')}
            className={`flex-1 px-6 py-3 rounded-lg font-semibold transition-colors ${
              activeTab === 'generator'
                ? 'bg-orange-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            📅 Generate Schedules
          </button>
          <button
            onClick={() => setActiveTab('timeslots')}
            className={`flex-1 px-6 py-3 rounded-lg font-semibold transition-colors ${
              activeTab === 'timeslots'
                ? 'bg-orange-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            🕐 Time Slots
          </button>
        </div>
      </div>

      {/* Content */}
      <div>
        {activeTab === 'generator' ? <ScheduleGenerator /> : <TimeSlotManager />}
      </div>
    </div>
  );
}
