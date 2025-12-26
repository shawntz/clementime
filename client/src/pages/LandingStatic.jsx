import { useState, useEffect } from 'react';

export default function LandingStatic() {
  const [activeFeature, setActiveFeature] = useState(0);
  const [activePlatform, setActivePlatform] = useState('mac');
  const [scrollY, setScrollY] = useState(0);
  const [activeScreenshot, setActiveScreenshot] = useState(0);

  useEffect(() => {
    const handleScroll = () => setScrollY(window.scrollY);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      setActiveScreenshot((prev) => (prev + 1) % 4);
    }, 4000);
    return () => clearInterval(interval);
  }, []);

  const platforms = {
    mac: {
      title: 'Native macOS App',
      tagline: 'Offline-first, CloudKit sync',
      features: [
        { icon: '🎨', text: 'Native SwiftUI interface' },
        { icon: '☁️', text: 'Automatic iCloud sync' },
        { icon: '📴', text: 'Full offline support' },
        { icon: '🎭', text: 'Unlimited custom cohorts' },
        { icon: '🔐', text: 'Granular TA permissions' },
        { icon: '🤝', text: 'CloudKit course sharing' }
      ],
      cta: 'Download for Mac',
      ctaLink: 'https://github.com/shawntz/clementime/releases',
      gradient: 'from-blue-500 via-purple-500 to-pink-500'
    },
    web: {
      title: 'Web Application',
      tagline: 'Cross-platform, real-time collaboration',
      features: [
        { icon: '🌍', text: 'Access from any browser' },
        { icon: '💬', text: 'Slack notifications' },
        { icon: '📚', text: 'Canvas LMS integration' },
        { icon: '👥', text: 'Multi-user dashboards' },
        { icon: '🎙️', text: 'Browser recording' },
        { icon: '☁️', text: 'Google Drive storage' }
      ],
      cta: 'Deploy Web App',
      ctaLink: 'https://github.com/shawntz/clementime/wiki/Deployment-Guide',
      gradient: 'from-orange-500 via-red-500 to-pink-500'
    }
  };

  const features = [
    {
      title: 'Smart Scheduling',
      description: 'AI-powered schedule generation that respects student constraints, balances TA workloads, and optimizes time slots automatically.',
      icon: '📅',
      gradient: 'from-orange-400 to-pink-500'
    },
    {
      title: 'Flexible Cohorts',
      description: 'Create unlimited custom cohorts beyond A/B splits. Perfect for complex scheduling needs with multiple sections and exam tracks.',
      icon: '🎭',
      gradient: 'from-purple-400 to-indigo-500'
    },
    {
      title: 'Recording Management',
      description: 'Built-in audio recording with automatic cloud upload to iCloud or Google Drive. Organized folder structures included.',
      icon: '🎙️',
      gradient: 'from-blue-400 to-cyan-500'
    },
    {
      title: 'Real-time Sync',
      description: 'CloudKit sync for Mac app or real-time updates for web. Your data stays current across all devices and collaborators.',
      icon: '🔄',
      gradient: 'from-green-400 to-teal-500'
    }
  ];

  const stats = [
    { number: '500+', label: 'Students Scheduled' },
    { number: '2', label: 'Platforms' },
    { number: '2000+', label: 'Exams Recorded' },
    { number: '100%', label: 'Open Source' }
  ];

  const screenshots = [
    {
      title: 'Smart Scheduling',
      description: 'Automatically generate optimal exam schedules with student constraints',
      color: 'from-orange-500/20 to-pink-500/20'
    },
    {
      title: 'Course Management',
      description: 'Manage multiple courses, sections, and cohorts in one place',
      color: 'from-blue-500/20 to-purple-500/20'
    },
    {
      title: 'Student Dashboard',
      description: 'Track student availability and exam sessions effortlessly',
      color: 'from-purple-500/20 to-pink-500/20'
    },
    {
      title: 'Recording Tools',
      description: 'Built-in audio recording with automatic cloud sync',
      color: 'from-green-500/20 to-teal-500/20'
    }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white">
      {/* Animated Background Grid */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none opacity-20">
        <div className="absolute inset-0" style={{
          backgroundImage: 'radial-gradient(circle at 1px 1px, rgb(255 255 255 / 0.15) 1px, transparent 0)',
          backgroundSize: '40px 40px'
        }}></div>
      </div>

      {/* Gradient Orbs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-4 w-96 h-96 bg-orange-500/30 rounded-full blur-3xl animate-blob"></div>
        <div className="absolute top-0 -right-4 w-96 h-96 bg-purple-500/30 rounded-full blur-3xl animate-blob" style={{ animationDelay: '2s' }}></div>
        <div className="absolute -bottom-8 left-1/2 w-96 h-96 bg-pink-500/30 rounded-full blur-3xl animate-blob" style={{ animationDelay: '4s' }}></div>
      </div>

      {/* Navigation */}
      <nav className="sticky top-0 z-50 pt-4">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div
            className={`flex justify-between items-center py-6 transition-all duration-300 border ${
              scrollY > 50
                ? 'backdrop-blur-xl bg-gray-900/90 rounded-2xl px-6 border-white/10 shadow-lg'
                : 'border-transparent'
            }`}
          >
            <div className="flex items-center space-x-3">
              <span className="text-5xl">🍊</span>
              <h1 className="text-2xl font-bold tracking-tight">
                Clementime
              </h1>
            </div>
            <div className="flex items-center gap-3">
              <a
                href="https://buymeacoffee.com/shawntz"
                target="_blank"
                rel="noopener noreferrer"
                className="px-5 py-2.5 backdrop-blur-xl bg-white/10 rounded-xl font-medium transition-all duration-300 hover:bg-white/20 hover:scale-105 border border-white/20 inline-flex items-center gap-2"
              >
                <span>☕</span>
                <span>Donate</span>
              </a>
              <a
                href="https://github.com/shawntz/clementime"
                target="_blank"
                rel="noopener noreferrer"
                className="px-5 py-2.5 backdrop-blur-xl bg-white/10 rounded-xl font-medium transition-all duration-300 hover:bg-white/20 hover:scale-105 border border-white/20"
              >
                GitHub
              </a>
              <a
                href="https://github.com/shawntz/clementime/releases"
                target="_blank"
                rel="noopener noreferrer"
                className="px-6 py-2.5 bg-gradient-to-r from-orange-500 to-pink-500 rounded-xl font-semibold transition-all duration-300 hover:scale-105 hover:shadow-lg hover:shadow-orange-500/30 inline-flex items-center gap-2"
              >
                <span>Download</span>
                <span>↓</span>
              </a>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-32 text-center">
        <div className="animate-slide-up">
          <div className="inline-flex items-center gap-2 px-4 py-2 backdrop-blur-xl bg-white/10 rounded-full border border-white/20 mb-8">
            <span className="relative flex h-3 w-3">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-orange-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-3 w-3 bg-orange-500"></span>
            </span>
            <span className="text-sm font-medium">Now available for macOS 14+</span>
          </div>

          <h1 className="text-6xl md:text-7xl lg:text-8xl font-extrabold mb-6 leading-tight">
            Oral Exam Scheduling,
            <br />
            <span className="bg-gradient-to-r from-orange-400 via-pink-500 to-purple-500 bg-clip-text text-transparent">
              Reimagined
            </span>
          </h1>

          <p className="text-xl md:text-2xl text-gray-300 max-w-3xl mx-auto mb-12 leading-relaxed">
            Choose your platform: Native macOS app with iCloud sync, or web application with real-time collaboration.
            Both feature smart scheduling, automatic notifications, and seamless recording management.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-16">
            <a
              href="https://github.com/shawntz/clementime/releases"
              target="_blank"
              rel="noopener noreferrer"
              className="group px-8 py-4 text-lg font-semibold bg-gradient-to-r from-orange-500 to-pink-500 rounded-2xl transition-all duration-300 hover:scale-110 hover:shadow-2xl hover:shadow-orange-500/50 inline-flex items-center space-x-2"
            >
              <span>Download for Mac</span>
              <span className="group-hover:translate-x-1 transition-transform">→</span>
            </a>
            <a
              href="https://github.com/shawntz/clementime/wiki/Deployment-Guide"
              className="px-8 py-4 text-lg font-semibold backdrop-blur-xl bg-white/10 rounded-2xl transition-all duration-300 hover:bg-white/20 hover:scale-105 border border-white/20 inline-flex items-center space-x-2"
            >
              <span>Deploy Web App</span>
              <span>🚀</span>
            </a>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6 backdrop-blur-2xl bg-white/5 p-8 rounded-3xl border border-white/10">
            {stats.map((stat, idx) => (
              <div
                key={idx}
                className="transform hover:scale-110 transition-transform duration-300 cursor-default"
                style={{ animationDelay: `${idx * 100}ms` }}
              >
                <div className="text-4xl md:text-5xl font-extrabold mb-2 bg-gradient-to-r from-orange-400 to-pink-500 bg-clip-text text-transparent">
                  {stat.number}
                </div>
                <div className="text-gray-400 text-sm md:text-base font-medium">
                  {stat.label}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Apple-Style macOS App Showcase */}
      <div className="relative z-10 py-32 overflow-hidden">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          {/* App Icon and Title */}
          <div className="text-center mb-20">
            <div className="inline-block mb-8 transform hover:scale-105 transition-transform duration-500">
              <img
                src="/macos-app-logo.png"
                alt="Clementime macOS App"
                className="w-40 h-40 md:w-48 md:h-48 drop-shadow-2xl"
              />
            </div>
            <h2 className="text-5xl md:text-6xl font-extrabold mb-4 tracking-tight">
              Clementime for Mac
            </h2>
            <p className="text-2xl text-gray-400 max-w-3xl mx-auto leading-relaxed">
              Beautiful. Fast. Native.
            </p>
            <p className="text-lg text-gray-500 max-w-2xl mx-auto mt-4">
              Designed exclusively for macOS with CloudKit sync and offline-first architecture
            </p>
          </div>

          {/* Screenshot Gallery */}
          <div className="relative">
            {/* Main Screenshot Display */}
            <div className="relative aspect-[16/10] rounded-3xl overflow-hidden backdrop-blur-3xl bg-white/5 border border-white/10 shadow-2xl mb-8">
              <div className="absolute inset-0 flex items-center justify-center p-12">
                {screenshots.map((screenshot, idx) => (
                  <div
                    key={idx}
                    className={`absolute inset-0 transition-all duration-700 ${
                      activeScreenshot === idx
                        ? 'opacity-100 scale-100'
                        : 'opacity-0 scale-95 pointer-events-none'
                    }`}
                  >
                    <div className={`w-full h-full bg-gradient-to-br ${screenshot.color} rounded-2xl flex flex-col items-center justify-center p-12 border border-white/20`}>
                      <div className="text-center">
                        <div className="text-6xl md:text-8xl mb-6 opacity-30">
                          {idx === 0 ? '📅' : idx === 1 ? '📚' : idx === 2 ? '👥' : '🎙️'}
                        </div>
                        <h3 className="text-3xl md:text-4xl font-bold mb-4">{screenshot.title}</h3>
                        <p className="text-xl text-gray-300 max-w-xl mx-auto">{screenshot.description}</p>
                        <div className="mt-8 text-sm text-gray-500">
                          Screenshot placeholder - Add your app screenshots to public folder
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Navigation Arrows */}
              <button
                onClick={() => setActiveScreenshot((prev) => (prev - 1 + screenshots.length) % screenshots.length)}
                className="absolute left-4 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full backdrop-blur-xl bg-white/10 border border-white/20 flex items-center justify-center hover:bg-white/20 transition-all duration-300 hover:scale-110"
              >
                <span className="text-2xl">←</span>
              </button>
              <button
                onClick={() => setActiveScreenshot((prev) => (prev + 1) % screenshots.length)}
                className="absolute right-4 top-1/2 -translate-y-1/2 w-12 h-12 rounded-full backdrop-blur-xl bg-white/10 border border-white/20 flex items-center justify-center hover:bg-white/20 transition-all duration-300 hover:scale-110"
              >
                <span className="text-2xl">→</span>
              </button>
            </div>

            {/* Thumbnail Navigation */}
            <div className="flex justify-center gap-4 flex-wrap">
              {screenshots.map((screenshot, idx) => (
                <button
                  key={idx}
                  onClick={() => setActiveScreenshot(idx)}
                  className={`group relative px-6 py-3 rounded-xl transition-all duration-300 ${
                    activeScreenshot === idx
                      ? 'bg-white/10 border border-white/20 scale-105'
                      : 'bg-white/5 border border-white/10 hover:bg-white/10'
                  }`}
                >
                  <div className="flex items-center gap-2">
                    <span className="text-2xl">
                      {idx === 0 ? '📅' : idx === 1 ? '📚' : idx === 2 ? '👥' : '🎙️'}
                    </span>
                    <span className="text-sm font-medium">{screenshot.title}</span>
                  </div>
                  {activeScreenshot === idx && (
                    <div className="absolute -bottom-1 left-1/2 -translate-x-1/2 w-1/2 h-0.5 bg-gradient-to-r from-orange-400 to-pink-500 rounded-full"></div>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Feature Highlights */}
          <div className="grid md:grid-cols-3 gap-6 mt-20">
            <div className="text-center p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all duration-300">
              <div className="text-5xl mb-4">⚡</div>
              <h3 className="text-xl font-bold mb-2">Lightning Fast</h3>
              <p className="text-gray-400">Native performance with SwiftUI</p>
            </div>
            <div className="text-center p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all duration-300">
              <div className="text-5xl mb-4">☁️</div>
              <h3 className="text-xl font-bold mb-2">CloudKit Sync</h3>
              <p className="text-gray-400">Automatic iCloud synchronization</p>
            </div>
            <div className="text-center p-6 rounded-2xl backdrop-blur-xl bg-white/5 border border-white/10 hover:bg-white/10 transition-all duration-300">
              <div className="text-5xl mb-4">🔒</div>
              <h3 className="text-xl font-bold mb-2">Privacy First</h3>
              <p className="text-gray-400">Your data stays on your devices</p>
            </div>
          </div>

          {/* Download CTA */}
          <div className="text-center mt-16">
            <a
              href="https://github.com/shawntz/clementime/releases"
              target="_blank"
              rel="noopener noreferrer"
              className="group inline-flex items-center gap-3 px-10 py-5 text-xl font-bold bg-gradient-to-r from-orange-500 to-pink-500 rounded-2xl transition-all duration-300 hover:scale-110 hover:shadow-2xl hover:shadow-orange-500/50"
            >
              <span>Download for macOS</span>
              <span className="group-hover:translate-x-2 transition-transform">→</span>
            </a>
            <p className="text-sm text-gray-500 mt-4">macOS 14+ • Free & Open Source</p>
          </div>
        </div>
      </div>

      {/* Platform Comparison */}
      <div className="relative z-10 py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-5xl font-extrabold mb-4">
              Choose Your Platform
            </h2>
            <p className="text-xl text-gray-400 max-w-2xl mx-auto">
              Two independent implementations, both featuring the same powerful scheduling platform
            </p>
          </div>

          {/* Platform Toggle */}
          <div className="flex justify-center mb-12">
            <div className="inline-flex backdrop-blur-xl bg-white/5 rounded-2xl p-2 border border-white/10">
              <button
                onClick={() => setActivePlatform('mac')}
                className={`px-8 py-3 rounded-xl font-semibold transition-all duration-300 ${
                  activePlatform === 'mac'
                    ? 'bg-gradient-to-r from-blue-500 to-purple-500 text-white shadow-lg'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                🍎 macOS App
              </button>
              <button
                onClick={() => setActivePlatform('web')}
                className={`px-8 py-3 rounded-xl font-semibold transition-all duration-300 ${
                  activePlatform === 'web'
                    ? 'bg-gradient-to-r from-orange-500 to-pink-500 text-white shadow-lg'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                🌐 Web App
              </button>
            </div>
          </div>

          {/* Platform Details */}
          <div className="grid md:grid-cols-2 gap-8">
            {Object.entries(platforms).map(([key, platform]) => (
              <div
                key={key}
                className={`p-8 backdrop-blur-xl rounded-3xl border transition-all duration-500 ${
                  activePlatform === key
                    ? 'bg-white/10 border-white/20 scale-105 shadow-2xl'
                    : 'bg-white/5 border-white/10 opacity-50'
                }`}
              >
                <h3 className="text-3xl font-bold mb-2">{platform.title}</h3>
                <p className="text-gray-400 mb-6">{platform.tagline}</p>

                <div className="grid grid-cols-2 gap-4 mb-8">
                  {platform.features.map((feature, idx) => (
                    <div key={idx} className="flex items-center gap-2">
                      <span className="text-2xl">{feature.icon}</span>
                      <span className="text-sm text-gray-300">{feature.text}</span>
                    </div>
                  ))}
                </div>

                <a
                  href={platform.ctaLink}
                  target="_blank"
                  rel="noopener noreferrer"
                  className={`block w-full py-3 text-center font-semibold rounded-xl transition-all duration-300 ${
                    activePlatform === key
                      ? `bg-gradient-to-r ${platform.gradient} hover:scale-105 shadow-lg`
                      : 'bg-white/10 hover:bg-white/20'
                  }`}
                >
                  {platform.cta}
                </a>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Features Section */}
      <div className="relative z-10 py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16">
            <h2 className="text-5xl font-extrabold mb-4">
              Everything you need
            </h2>
            <p className="text-xl text-gray-400 max-w-2xl mx-auto">
              Powerful features built for instructors and TAs who value their time
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            {features.map((feature, idx) => (
              <div
                key={idx}
                className="group relative p-8 backdrop-blur-xl bg-white/5 rounded-3xl border border-white/10 transition-all duration-500 cursor-pointer hover:scale-105 hover:bg-white/10 hover:border-white/20"
                onMouseEnter={() => setActiveFeature(idx)}
              >
                <div className="text-6xl mb-6 transform group-hover:scale-110 group-hover:rotate-12 transition-transform duration-500">
                  {feature.icon}
                </div>
                <h3 className="text-2xl font-bold mb-4">
                  {feature.title}
                </h3>
                <p className="text-gray-400 leading-relaxed">
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Currently Used At */}
      <div className="relative z-10 py-24 bg-gradient-to-r from-orange-500/10 to-pink-500/10 backdrop-blur-xl border-y border-white/10">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-4xl md:text-5xl font-extrabold mb-6">
            Trusted at Stanford University
          </h2>
          <div className="backdrop-blur-xl bg-white/5 p-8 rounded-3xl border border-white/10 hover:scale-105 transition-transform duration-300">
            <a
              href="https://psych10.github.io/"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-xl hover:text-orange-400 transition-colors font-medium"
            >
              <span>🎓</span>
              <span>Psych 10: Introduction to Statistical Methods</span>
              <span className="text-sm">↗</span>
            </a>
            <p className="text-gray-400 mt-4 text-lg">
              Managing oral exams for 200+ students per quarter
            </p>
          </div>
        </div>
      </div>

      {/* CTA Section */}
      <div className="relative z-10 py-24">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-5xl md:text-6xl font-extrabold mb-6">
            Ready to get started?
          </h2>
          <p className="text-xl md:text-2xl text-gray-400 mb-12 leading-relaxed">
            Open source and free forever. Deploy in minutes or download the native Mac app.
          </p>
          <div className="flex flex-col sm:flex-row gap-6 justify-center items-center">
            <a
              href="https://github.com/shawntz/clementime/releases"
              target="_blank"
              rel="noopener noreferrer"
              className="group px-10 py-5 text-xl font-bold bg-gradient-to-r from-orange-500 to-pink-500 rounded-2xl transition-all duration-300 hover:scale-110 hover:shadow-2xl hover:shadow-orange-500/50 inline-flex items-center space-x-3"
            >
              <span>Download for Mac</span>
              <span className="group-hover:translate-x-2 transition-transform">→</span>
            </a>
            <a
              href="https://github.com/shawntz/clementime"
              target="_blank"
              rel="noopener noreferrer"
              className="px-10 py-5 text-xl font-bold backdrop-blur-xl bg-white/10 rounded-2xl transition-all duration-300 hover:bg-white/20 hover:scale-105 border border-white/20 inline-flex items-center space-x-3"
            >
              <span>⭐</span>
              <span>Star on GitHub</span>
            </a>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="relative z-10 border-t border-white/10 py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col items-center justify-center space-y-6">
            <div className="flex items-center space-x-3">
              <span className="text-5xl">🍊</span>
              <span className="text-2xl font-bold">Clementime</span>
            </div>
            <p className="text-center text-gray-400">
              Multi-platform oral exam scheduling for universities
            </p>
            <div className="flex space-x-8">
              <a href="https://github.com/shawntz/clementime" className="text-gray-400 hover:text-white transition-colors">GitHub</a>
              <a href="https://github.com/shawntz/clementime#readme" className="text-gray-400 hover:text-white transition-colors">Documentation</a>
              <a href="https://github.com/shawntz/clementime/releases" className="text-gray-400 hover:text-white transition-colors">Releases</a>
              <a href="https://github.com/shawntz/clementime/issues" className="text-gray-400 hover:text-white transition-colors">Support</a>
            </div>

            {/* Tech Stack */}
            <div className="pt-4">
              <div className="text-gray-500 text-sm mb-3 text-center">Built with</div>
              <div className="flex justify-center items-center gap-3 flex-wrap">
                <div className="px-3 py-1.5 backdrop-blur-xl bg-white/5 rounded-lg border border-white/10 text-sm">
                  Swift + SwiftUI
                </div>
                <div className="px-3 py-1.5 backdrop-blur-xl bg-white/5 rounded-lg border border-white/10 text-sm">
                  Ruby on Rails
                </div>
                <div className="px-3 py-1.5 backdrop-blur-xl bg-white/5 rounded-lg border border-white/10 text-sm">
                  React
                </div>
                <div className="px-3 py-1.5 backdrop-blur-xl bg-white/5 rounded-lg border border-white/10 text-sm">
                  CloudKit
                </div>
              </div>
            </div>

            <p className="text-sm text-gray-500 pt-2">
              © 2025 Shawn Schwartz • MIT License • Made with 🍊 for educators
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
