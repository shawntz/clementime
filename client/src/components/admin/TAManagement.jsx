import { useState } from 'react';
import TAManager from './TAManager';
import SectionManager from './SectionManager';

export default function TAManagement() {
  const [activeTab, setActiveTab] = useState('manage');

  return (
    <div className="space-y-6">
      {/* Tab Selector */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-2">
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('manage')}
            className={`flex-1 px-6 py-3 rounded-lg font-semibold transition-colors ${
              activeTab === 'manage'
                ? 'bg-orange-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            👨‍🏫 TA Management
          </button>
          <button
            onClick={() => setActiveTab('assign')}
            className={`flex-1 px-6 py-3 rounded-lg font-semibold transition-colors ${
              activeTab === 'assign'
                ? 'bg-orange-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            👥 Assign TAs
          </button>
        </div>
      </div>

      {/* Content */}
      <div>
        {activeTab === 'manage' ? <TAManager /> : <SectionManager />}
      </div>
    </div>
  );
}
