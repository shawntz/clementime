import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';

export default function Landing() {
  const [activeFeature, setActiveFeature] = useState(0);
  const [scrollY, setScrollY] = useState(0);

  useEffect(() => {
    const handleScroll = () => setScrollY(window.scrollY);
    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  const features = [
    {
      title: 'Smart Scheduling',
      description: 'Automatically generate optimized exam schedules that respect student constraints and balance TA workloads.',
      icon: '📅',
      gradient: 'from-orange-400 to-pink-500'
    },
    {
      title: 'Canvas Integration',
      description: 'Import rosters directly from Canvas. Match students with Slack for seamless notifications.',
      icon: '🎓',
      gradient: 'from-purple-400 to-indigo-500'
    },
    {
      title: 'Recording Management',
      description: 'Automatically organize and upload exam recordings to Google Drive with smart folder structures.',
      icon: '🎙️',
      gradient: 'from-blue-400 to-cyan-500'
    },
    {
      title: 'Real-time Notifications',
      description: 'Send automated Slack notifications to students with their exam schedules and details.',
      icon: '🔔',
      gradient: 'from-green-400 to-teal-500'
    }
  ];

  const stats = [
    { number: '500+', label: 'Students Scheduled' },
    { number: '15+', label: 'TAs Supported' },
    { number: '2000+', label: 'Exams Recorded' },
    { number: '100%', label: 'Open Source' }
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-primary-500 via-orange-500 to-secondary-500 overflow-hidden">
      {/* Animated Background Blobs */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none">
        <div className="absolute top-0 -left-4 w-72 h-72 bg-purple-300 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob"></div>
        <div className="absolute top-0 -right-4 w-72 h-72 bg-yellow-300 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob" style={{ animationDelay: '2s' }}></div>
        <div className="absolute -bottom-8 left-20 w-72 h-72 bg-pink-300 rounded-full mix-blend-multiply filter blur-xl opacity-70 animate-blob" style={{ animationDelay: '4s' }}></div>
      </div>

      {/* Navigation */}
      <nav className="relative z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div
            className={`flex justify-between items-center py-6 transition-all duration-300 ${
              scrollY > 50 ? 'backdrop-blur-xl bg-white/10 rounded-2xl px-6 mt-4' : ''
            }`}
            style={{
              boxShadow: scrollY > 50 ? '0 8px 32px 0 rgba(31, 38, 135, 0.37)' : 'none',
              border: scrollY > 50 ? '1px solid rgba(255, 255, 255, 0.18)' : 'none',
            }}
          >
            <div className="flex items-center space-x-3 animate-slide-down">
              <span className="text-5xl animate-bounce-slow">🍊</span>
              <h1 className="text-2xl font-bold text-white tracking-tight">
                Clementime
              </h1>
            </div>
            <div className="flex space-x-4 animate-slide-down">
              <a
                href="https://github.com/shawntz/clementime"
                target="_blank"
                rel="noopener noreferrer"
                className="px-6 py-2.5 backdrop-blur-xl bg-white/20 text-white rounded-xl font-medium transition-all duration-300 hover:bg-white/30 hover:scale-105 hover:shadow-lg border border-white/30"
              >
                GitHub
              </a>
              <Link
                to="/login"
                className="px-6 py-2.5 bg-white text-primary-600 rounded-xl font-semibold transition-all duration-300 hover:scale-105 hover:shadow-2xl"
              >
                Sign In
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Hero Section */}
      <div className="relative z-10 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 pt-20 pb-32 text-center">
        <div className="animate-slide-up">
          <h1 className="text-6xl md:text-7xl lg:text-8xl font-extrabold text-white mb-6 leading-tight">
            Oral Exam Scheduling,
            <br />
            <span className="bg-gradient-to-r from-yellow-200 via-orange-200 to-pink-200 bg-clip-text text-transparent animate-glow">
              Simplified
            </span>
          </h1>

          <p className="text-xl md:text-2xl text-white/90 max-w-3xl mx-auto mb-12 leading-relaxed">
            The complete solution for managing oral exams in university courses.
            Smart scheduling, automatic notifications, and seamless recording management.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-16">
            <a
              href="https://github.com/shawntz/clementime/wiki/Deployment-Guide"
              target="_blank"
              rel="noopener noreferrer"
              className="group px-8 py-4 text-lg font-semibold bg-white text-primary-600 rounded-2xl transition-all duration-300 hover:scale-110 hover:shadow-2xl hover:rotate-1 inline-flex items-center space-x-2"
            >
              <span>Deploy Your Instance</span>
              <span className="group-hover:translate-x-1 transition-transform">🚀</span>
            </a>
            <a
              href="https://github.com/shawntz/clementime#readme"
              className="px-8 py-4 text-lg font-semibold backdrop-blur-xl bg-white/20 text-white rounded-2xl transition-all duration-300 hover:bg-white/30 hover:scale-105 border-2 border-white/30 inline-flex items-center space-x-2"
            >
              <span>View Docs</span>
              <span>📚</span>
            </a>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-6 backdrop-blur-2xl bg-white/10 p-8 rounded-3xl border border-white/20 shadow-2xl">
            {stats.map((stat, idx) => (
              <div
                key={idx}
                className="transform hover:scale-110 transition-transform duration-300 cursor-default"
                style={{ animationDelay: `${idx * 100}ms` }}
              >
                <div className="text-4xl md:text-5xl font-extrabold text-white mb-2 animate-float">
                  {stat.number}
                </div>
                <div className="text-white/80 text-sm md:text-base font-medium">
                  {stat.label}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Features Section */}
      <div className="relative bg-white py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="text-center mb-16 animate-slide-up">
            <h2 className="text-5xl font-extrabold text-gray-900 mb-4">
              Everything you need to run oral exams
            </h2>
            <p className="text-xl text-gray-600 max-w-2xl mx-auto">
              Built for instructors and TAs who want to spend less time on logistics and more time teaching.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
            {features.map((feature, idx) => (
              <div
                key={idx}
                className={`group relative p-8 rounded-3xl transition-all duration-500 cursor-pointer ${
                  activeFeature === idx
                    ? 'scale-105 shadow-2xl'
                    : 'hover:scale-105 shadow-lg'
                }`}
                style={{
                  background: activeFeature === idx
                    ? `linear-gradient(135deg, ${feature.gradient.includes('orange') ? '#f97316' : feature.gradient.includes('purple') ? '#a855f7' : feature.gradient.includes('blue') ? '#3b82f6' : '#10b981'}, ${feature.gradient.includes('pink') ? '#ec4899' : feature.gradient.includes('indigo') ? '#6366f1' : feature.gradient.includes('cyan') ? '#06b6d4' : '#14b8a6'})`
                    : '#f9fafb',
                  animationDelay: `${idx * 150}ms`
                }}
                onMouseEnter={() => setActiveFeature(idx)}
                onMouseLeave={() => setActiveFeature(-1)}
              >
                <div className={`text-6xl mb-6 transform group-hover:scale-110 group-hover:rotate-12 transition-transform duration-500 ${activeFeature === idx ? 'animate-bounce-slow' : ''}`}>
                  {feature.icon}
                </div>
                <h3 className={`text-2xl font-bold mb-4 transition-colors duration-300 ${
                  activeFeature === idx ? 'text-white' : 'text-gray-900'
                }`}>
                  {feature.title}
                </h3>
                <p className={`leading-relaxed transition-colors duration-300 ${
                  activeFeature === idx ? 'text-white/90' : 'text-gray-600'
                }`}>
                  {feature.description}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Currently Used At */}
      <div className="relative bg-gradient-to-br from-orange-500 to-red-600 py-16 overflow-hidden">
        <div className="absolute inset-0 bg-black/10"></div>
        <div className="relative z-10 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-4xl md:text-5xl font-extrabold text-white mb-6">
            Currently used at Stanford University
          </h2>
          <div className="backdrop-blur-2xl bg-white/10 p-8 rounded-3xl border-2 border-white/30 shadow-2xl hover:scale-105 transition-transform duration-300">
            <a
              href="https://psych10.github.io/"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 text-xl text-white hover:text-orange-100 transition-colors font-medium"
            >
              <span>🎓</span>
              <span>Psych 10: Introduction to Statistical Methods: Precalculus</span>
              <span className="text-sm">↗</span>
            </a>
            <p className="text-white/90 mt-4 text-lg">
              Managing oral exams for 200+ students
            </p>
          </div>
        </div>
      </div>

      {/* How It Works */}
      <div className="relative bg-gradient-to-br from-gray-50 to-gray-100 py-24">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-5xl font-extrabold text-center text-gray-900 mb-20">
            Get started in minutes
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-12">
            {[
              { step: '1', title: 'Fork & Deploy', desc: 'Click "Use this template" on GitHub and deploy to Render.com in 5 minutes.', color: 'from-orange-400 to-pink-500' },
              { step: '2', title: 'Upload Roster', desc: 'Import your Canvas roster CSV and match students with Slack.', color: 'from-purple-400 to-indigo-500' },
              { step: '3', title: 'Generate Schedule', desc: 'Let Clementime optimize exam times based on student constraints.', color: 'from-blue-400 to-cyan-500' },
              { step: '4', title: 'Send Notifications', desc: 'Automatically notify students via Slack with their exam details.', color: 'from-green-400 to-teal-500' }
            ].map((item, idx) => (
              <div key={idx} className="text-center group">
                <div className={`w-20 h-20 mx-auto mb-6 rounded-full bg-gradient-to-br ${item.color} flex items-center justify-center text-3xl font-extrabold text-white shadow-2xl transform group-hover:scale-125 group-hover:rotate-12 transition-all duration-500 animate-float`}
                  style={{ animationDelay: `${idx * 200}ms` }}
                >
                  {item.step}
                </div>
                <h3 className="text-2xl font-bold text-gray-900 mb-4 group-hover:text-primary-600 transition-colors">
                  {item.title}
                </h3>
                <p className="text-gray-600 leading-relaxed">
                  {item.desc}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* CTA Section */}
      <div className="relative bg-gradient-to-br from-primary-600 via-orange-600 to-secondary-600 py-24 overflow-hidden">
        <div className="absolute inset-0 bg-black/10"></div>
        <div className="relative z-10 max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-5xl md:text-6xl font-extrabold text-white mb-6 animate-slide-up">
            Ready to simplify your oral exams?
          </h2>
          <p className="text-xl md:text-2xl text-white/90 mb-12 leading-relaxed">
            Deploy your own instance for free. No credit card required.
            <br />
            Open source and built for educators.
          </p>
          <div className="flex flex-col sm:flex-row gap-6 justify-center items-center">
            <a
              href="https://github.com/shawntz/clementime/wiki/Deployment-Guide"
              target="_blank"
              rel="noopener noreferrer"
              className="group px-10 py-5 text-xl font-bold bg-white text-primary-600 rounded-2xl transition-all duration-300 hover:scale-110 hover:shadow-2xl hover:-rotate-1 inline-flex items-center space-x-3"
            >
              <span>Get Started Free</span>
              <span className="group-hover:translate-x-2 transition-transform">→</span>
            </a>
            <a
              href="https://github.com/shawntz/clementime"
              target="_blank"
              rel="noopener noreferrer"
              className="px-10 py-5 text-xl font-bold backdrop-blur-xl bg-white/20 text-white rounded-2xl transition-all duration-300 hover:bg-white/30 hover:scale-105 border-2 border-white inline-flex items-center space-x-3"
            >
              <span>⭐</span>
              <span>Star on GitHub</span>
            </a>
          </div>
        </div>
      </div>

      {/* Footer */}
      <footer className="relative bg-gray-900 text-gray-300 py-16">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col items-center justify-center space-y-6">
            <div className="flex items-center space-x-3">
              <span className="text-5xl">🍊</span>
              <span className="text-2xl font-bold text-white">Clementime</span>
            </div>
            <p className="text-center text-gray-400">
              Open source oral exam scheduling for universities
            </p>
            <div className="flex space-x-8">
              <a href="https://github.com/shawntz/clementime" className="hover:text-white transition-colors">GitHub</a>
              <a href="https://github.com/shawntz/clementime#readme" className="hover:text-white transition-colors">Documentation</a>
              <a href="https://github.com/shawntz/clementime/issues" className="hover:text-white transition-colors">Support</a>
            </div>

            {/* Tech Stack Badges */}
            <div className="pt-4">
              <div className="text-gray-500 text-sm mb-3 text-center">Powered by</div>
              <div className="flex justify-center items-center gap-4 flex-wrap">
                <div className="flex items-center gap-2 bg-gray-800 px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                  <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M2 12C2 6.48 6.48 2 12 2C17.52 2 22 6.48 22 12C22 17.52 17.52 22 12 22C6.48 22 2 17.52 2 12Z" fill="#61DAFB"/>
                    <path d="M12 14.5C13.38 14.5 14.5 13.38 14.5 12C14.5 10.62 13.38 9.5 12 9.5C10.62 9.5 9.5 10.62 9.5 12C9.5 13.38 10.62 14.5 12 14.5Z" fill="#282C34"/>
                  </svg>
                  <span className="text-white font-medium">React</span>
                </div>
                <div className="flex items-center gap-2 bg-gray-800 px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                  <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M2 12L3.5 2H20.5L22 12L12 22L2 12Z" fill="#CC0000"/>
                    <path d="M12 2L12 22L22 12L20.5 2H12Z" fill="#990000"/>
                    <path d="M12 5L8 16H10L11 13H13L14 16H16L12 5Z" fill="white"/>
                  </svg>
                  <span className="text-white font-medium">Ruby on Rails</span>
                </div>
                <div className="flex items-center gap-2 bg-gray-800 px-4 py-2 rounded-lg hover:bg-gray-700 transition-colors">
                  <svg className="w-6 h-6" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <path d="M12 6.036L8.206 9.828L7.5 9.122L12 4.622L16.5 9.122L15.794 9.828L12 6.036Z" fill="#38BDF8"/>
                    <path d="M8.206 12.172L12 15.964L15.794 12.172L16.5 12.878L12 17.378L7.5 12.878L8.206 12.172Z" fill="#38BDF8"/>
                    <path d="M6.25 11L12 5.25L17.75 11L12 16.75L6.25 11Z" stroke="#38BDF8" strokeWidth="1.5" fill="none"/>
                  </svg>
                  <span className="text-white font-medium">Tailwind CSS</span>
                </div>
              </div>
            </div>

            <p className="text-sm text-gray-500 pt-2">
              Made with ❤️ by{' '}
              <a
                href="https://github.com/shawntz"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-orange-400 transition-colors"
              >
                @shawntz
              </a>
              {' '}for educators •{' '}
              <a
                href="https://github.com/shawntz/clementime/blob/main/LICENSE"
                target="_blank"
                rel="noopener noreferrer"
                className="hover:text-orange-400 transition-colors"
              >
                MIT License
              </a>
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
