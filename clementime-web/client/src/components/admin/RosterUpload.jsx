import { useState } from 'react';
import CanvasUpload from './CanvasUpload';
import SlackMatching from './SlackMatching';

export default function RosterUpload() {
  const [activeTab, setActiveTab] = useState('canvas');

  return (
    <div className="space-y-6">
      {/* Tab Selector */}
      <div className="bg-white rounded-lg shadow-sm border border-gray-200 p-2">
        <div className="flex gap-2">
          <button
            onClick={() => setActiveTab('canvas')}
            className={`flex-1 px-6 py-3 rounded-lg font-semibold transition-colors ${
              activeTab === 'canvas'
                ? 'bg-orange-500 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            📤 Canvas Upload
          </button>
          <button
            onClick={() => setActiveTab('slack')}
            className={`flex-1 px-6 py-3 rounded-lg font-semibold transition-colors ${
              activeTab === 'slack'
                ? 'bg-purple-600 text-white'
                : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
            }`}
          >
            💬 Slack Matching
          </button>
        </div>
      </div>

      {/* Content */}
      <div>{activeTab === 'canvas' ? <CanvasUpload /> : <SlackMatching />}</div>
    </div>
  );
}
