// ============================================================
// ZeParty Public — Home Page (JSX)
// ============================================================

import React, { useEffect } from 'react';
import { Radio, Users, Coins, Star, Gamepad2, Heart, ArrowRight } from 'lucide-react';

export function HomePage() {
  useEffect(() => {
    document.title = 'ZeParty — Live. Connect. Entertain.';
  }, []);

  const scrollToFeatures = () => {
    document.getElementById('features')?.scrollIntoView({ behavior: 'smooth' });
  };

  return (
    <div className="flex flex-col w-full overflow-hidden">
      
      {/* 1. Hero Section */}
      <section className="relative pt-32 pb-20 lg:pt-48 lg:pb-32 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto w-full flex flex-col items-center text-center">
        {/* Decorative background glow */}
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-[#D4AF37]/10 blur-[120px] rounded-full pointer-events-none" />
        
        <p className="text-[#D4AF37] font-semibold tracking-widest text-sm uppercase mb-4 relative z-10">
          Welcome to ZeParty
        </p>
        <h1 className="text-5xl md:text-7xl font-bold text-white mb-6 tracking-tight relative z-10 leading-tight">
          Connect. Go Live. <br className="hidden md:block" />
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-[#D4AF37] to-[#E5C158]">
            Experience ZeParty.
          </span>
        </h1>
        <p className="text-lg md:text-xl text-slate-400 mb-10 max-w-2xl mx-auto relative z-10">
          The premier social entertainment platform where creators go live, 
          communities connect, and interactive experiences come to life.
        </p>
        
        <div className="flex flex-col sm:flex-row gap-4 relative z-10">
          <button
            onClick={scrollToFeatures}
            className="bg-[#D4AF37] hover:bg-[#B8962E] text-black font-semibold py-3.5 px-8 rounded-lg transition-all shadow-[0_0_20px_rgba(212,175,55,0.3)] hover:shadow-[0_0_30px_rgba(212,175,55,0.5)]"
          >
            Get Started
          </button>
          <button
            onClick={scrollToFeatures}
            className="bg-transparent border border-white/20 hover:border-[#D4AF37]/50 text-white hover:text-[#D4AF37] font-medium py-3.5 px-8 rounded-lg transition-all"
          >
            Explore ZeParty
          </button>
        </div>
      </section>

      {/* 2. Introduction */}
      <section className="py-20 bg-white/[0.02] border-y border-white/5 relative">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="grid md:grid-cols-2 gap-12 items-center">
            <div>
              <h2 className="text-3xl md:text-4xl font-bold text-white mb-6">A New Way to Connect and Entertain</h2>
              <p className="text-slate-400 text-lg leading-relaxed mb-6">
                ZeParty brings people together through engaging live streams and interactive social features. Whether you're a talented host looking for an audience, or a viewer seeking entertainment, ZeParty provides the ultimate digital venue.
              </p>
              <p className="text-slate-400 text-lg leading-relaxed">
                Join thousands of users participating in daily live events, sharing virtual gifts, and building lasting communities across the globe.
              </p>
            </div>
            <div className="relative h-[400px] rounded-2xl bg-gradient-to-br from-[#111] to-[#0a0a0a] border border-white/10 p-8 flex items-center justify-center overflow-hidden group">
              <div className="absolute inset-0 bg-[#D4AF37]/5 opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
              <div className="flex gap-4 items-center">
                <div className="h-24 w-24 rounded-full bg-[#1a1a1a] border border-white/10 flex items-center justify-center relative shadow-2xl z-10">
                  <Radio className="h-10 w-10 text-[#D4AF37]" />
                  <div className="absolute -top-2 -right-2 h-6 w-6 rounded-full bg-red-500 border-2 border-[#111] animate-pulse" />
                </div>
                <div className="h-20 w-20 rounded-full bg-[#1a1a1a] border border-white/10 flex items-center justify-center -ml-6 shadow-xl z-0 opacity-80">
                  <Users className="h-8 w-8 text-slate-500" />
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 3. Platform Features */}
      <section id="features" className="py-24 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <div className="text-center max-w-3xl mx-auto mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">Platform Features</h2>
          <p className="text-slate-400">Everything you need to broadcast, engage, and entertain.</p>
        </div>
        
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {[
            { icon: Radio, title: 'Live Streaming', desc: 'High-quality broadcasting tools for hosts to connect with their audience in real-time.' },
            { icon: Users, title: 'Social Interaction', desc: 'Real-time chat, reactions, and community-building features that bring viewers together.' },
            { icon: Coins, title: 'Virtual Economy', desc: 'A rich platform economy built around coins, virtual gifts, and exclusive creator rewards.' },
            { icon: Star, title: 'Hosts & Creators', desc: 'Discover talented creators, join their fan clubs, and engage with premium content.' },
            { icon: Gamepad2, title: 'Games & Entertainment', desc: 'Interactive minigames and activities that viewers can play alongside their favorite hosts.' },
            { icon: Heart, title: 'Community First', desc: 'A safe, moderated environment designed to foster positive connections.' },
          ].map((feature, i) => (
            <div key={i} className="bg-[#0a0a0a] border border-white/5 hover:border-[#D4AF37]/30 rounded-xl p-8 transition-all group hover:-translate-y-1">
              <div className="h-12 w-12 rounded-lg bg-[#D4AF37]/10 flex items-center justify-center mb-6 text-[#D4AF37] group-hover:bg-[#D4AF37] group-hover:text-black transition-colors">
                <feature.icon className="h-6 w-6" />
              </div>
              <h3 className="text-xl font-semibold text-white mb-3">{feature.title}</h3>
              <p className="text-slate-400 leading-relaxed text-sm">{feature.desc}</p>
            </div>
          ))}
        </div>
      </section>

      {/* 4. Why ZeParty */}
      <section className="py-24 bg-gradient-to-b from-transparent to-[#0a0a0a] border-t border-white/5">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-sm font-bold tracking-widest text-[#D4AF37] uppercase mb-12 text-center">Why ZeParty?</h2>
          <div className="grid md:grid-cols-3 gap-8">
            <div className="text-center p-6">
              <h3 className="text-white font-semibold text-xl mb-3">Built for Connection</h3>
              <p className="text-slate-400 text-sm">Designed from the ground up around meaningful social interaction and community engagement.</p>
            </div>
            <div className="text-center p-6 border-y md:border-y-0 md:border-x border-white/5">
              <h3 className="text-white font-semibold text-xl mb-3">Live Entertainment</h3>
              <p className="text-slate-400 text-sm">A stage for talent. Discover engaging live experiences ranging from music to casual conversation.</p>
            </div>
            <div className="text-center p-6">
              <h3 className="text-white font-semibold text-xl mb-3">Interactive by Design</h3>
              <p className="text-slate-400 text-sm">Don't just watch—participate. Send gifts, join the chat, and influence the stream.</p>
            </div>
          </div>
        </div>
      </section>

      {/* 5. Live Entertainment */}
      <section className="py-24 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <div className="bg-gradient-to-br from-[#111] to-[#0a0a0a] border border-white/10 rounded-3xl p-8 md:p-16 relative overflow-hidden">
          <div className="absolute right-0 top-0 w-1/2 h-full bg-[#D4AF37]/5 blur-[100px] pointer-events-none" />
          <div className="relative z-10 max-w-2xl">
            <h2 className="text-3xl md:text-5xl font-bold text-white mb-6">Always Something Happening</h2>
            <p className="text-slate-400 text-lg mb-8 leading-relaxed">
              Dive into a world of continuous live entertainment. Discover new rooms, engage with dynamic hosts, and find your next favorite creator in a platform that never sleeps.
            </p>
            <div className="flex items-center gap-2 text-[#D4AF37] font-medium cursor-pointer hover:text-[#E5C158] transition-colors">
              Explore Live Rooms <ArrowRight className="h-5 w-5" />
            </div>
          </div>
        </div>
      </section>

      {/* 6. How It Works */}
      <section className="py-24 bg-white/[0.02] border-t border-white/5">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-3xl font-bold text-white mb-16">How It Works</h2>
          <div className="grid md:grid-cols-3 gap-8">
            {[
              { num: '01', title: 'Discover', desc: 'Explore live rooms, find exciting hosts, and browse varied entertainment categories.' },
              { num: '02', title: 'Connect', desc: 'Join the conversation, follow your favorites, and build your social network.' },
              { num: '03', title: 'Enjoy', desc: 'Send virtual gifts, play interactive games, and be part of the live experience.' },
            ].map((step, i) => (
              <div key={i} className="flex flex-col items-center">
                <div className="text-5xl font-black text-transparent bg-clip-text bg-gradient-to-b from-[#D4AF37] to-[#D4AF37]/10 mb-6">
                  {step.num}
                </div>
                <h3 className="text-xl font-semibold text-white mb-3">{step.title}</h3>
                <p className="text-slate-400 text-sm max-w-xs">{step.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 7. CTA */}
      <section className="py-32 max-w-4xl mx-auto px-4 text-center">
        <h2 className="text-4xl md:text-5xl font-bold text-white mb-6">Ready to Experience ZeParty?</h2>
        <p className="text-xl text-slate-400 mb-10">
          Join the community and discover a platform built around live entertainment and genuine connection.
        </p>
        <button
          onClick={() => window.scrollTo({ top: 0, behavior: 'smooth' })}
          className="bg-[#D4AF37] hover:bg-[#B8962E] text-black font-semibold py-4 px-10 rounded-lg transition-all text-lg shadow-[0_0_20px_rgba(212,175,55,0.3)] hover:shadow-[0_0_30px_rgba(212,175,55,0.5)]"
        >
          Explore ZeParty
        </button>
      </section>

    </div>
  );
}
