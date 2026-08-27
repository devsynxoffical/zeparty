// ============================================================
// ZeParty Public — About Page (JSX)
// ============================================================

import React, { useEffect } from 'react';
import { Link } from 'react-router-dom';
import { Users, Video, Gift, Gamepad2, ArrowRight } from 'lucide-react';

export function AboutPage() {
  useEffect(() => {
    document.title = 'About ZeParty';
  }, []);

  return (
    <div className="flex flex-col w-full overflow-hidden">
      
      {/* 1. Hero */}
      <section className="relative pt-32 pb-20 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto w-full text-center">
        <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-[#D4AF37]/5 blur-[100px] rounded-full pointer-events-none" />
        <h1 className="text-4xl md:text-6xl font-bold text-white mb-6 relative z-10">
          About ZeParty
        </h1>
        <p className="text-lg text-slate-400 max-w-2xl mx-auto relative z-10">
          We are building the premier digital venue for live entertainment, real-time social interaction, and thriving communities.
        </p>
      </section>

      {/* 2. Who We Are */}
      <section className="py-24 bg-white/[0.02] border-y border-white/5">
        <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 text-center">
          <h2 className="text-2xl md:text-3xl font-bold text-white mb-8">Who We Are</h2>
          <p className="text-slate-400 text-lg leading-relaxed mb-6">
            ZeParty is a social entertainment platform designed to bridge the gap between creators and audiences. We believe that entertainment should be interactive, and that the best experiences are the ones we share with others.
          </p>
          <p className="text-slate-400 text-lg leading-relaxed">
            By providing powerful live streaming tools, a robust virtual economy, and engaging community features, we empower hosts to build their brands and give viewers a place to belong.
          </p>
        </div>
      </section>

      {/* 3. Our Vision */}
      <section className="py-24 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-gradient-to-br from-[#111] to-[#0a0a0a] border border-[#D4AF37]/20 rounded-3xl p-10 md:p-16 text-center relative overflow-hidden">
          <div className="absolute inset-0 bg-[#D4AF37]/5 pointer-events-none" />
          <h2 className="text-sm font-bold tracking-widest text-[#D4AF37] uppercase mb-6 relative z-10">Our Vision</h2>
          <p className="text-2xl md:text-4xl font-semibold text-white leading-tight max-w-4xl mx-auto relative z-10">
            "To create a space where entertainment and authentic human connection come together seamlessly."
          </p>
        </div>
      </section>

      {/* 4. Values */}
      <section className="py-24 bg-gradient-to-b from-transparent to-[#0a0a0a] border-t border-white/5">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <h2 className="text-3xl font-bold text-white mb-12 text-center">What We Believe</h2>
          <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-6">
            {[
              { title: 'Connection', desc: 'Bringing people together across boundaries to share meaningful moments.' },
              { title: 'Entertainment', desc: 'Creating engaging, high-quality live experiences that captivate audiences.' },
              { title: 'Community', desc: 'Building safe, welcoming social spaces where everyone can find their crowd.' },
              { title: 'Innovation', desc: 'Continuously improving how people interact, play, and experience live content.' },
            ].map((val, i) => (
              <div key={i} className="bg-[#111] border border-white/5 rounded-xl p-6 hover:border-[#D4AF37]/30 transition-colors">
                <h3 className="text-[#D4AF37] font-semibold text-xl mb-3">{val.title}</h3>
                <p className="text-slate-400 text-sm leading-relaxed">{val.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 5. Platform Experience */}
      <section className="py-24 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <h2 className="text-3xl font-bold text-white mb-12 text-center">The Platform Experience</h2>
        <div className="grid md:grid-cols-2 gap-8">
          {[
            { icon: Video, title: 'Live Broadcasting', desc: 'A global stage for hosts to showcase their talents and connect directly with their audience.' },
            { icon: Users, title: 'Social Interaction', desc: 'Real-time chat, VIP privileges, and fan clubs that turn passive viewers into active communities.' },
            { icon: Gift, title: 'Virtual Economy', desc: 'An integrated coin system allowing viewers to support hosts through premium virtual gifts and rewards.' },
            { icon: Gamepad2, title: 'Interactive Games', desc: 'Integrated minigames that hosts and viewers can play together to keep the energy high.' },
          ].map((exp, i) => (
            <div key={i} className="flex gap-6 p-6 rounded-2xl bg-white/[0.02] border border-white/5">
              <div className="h-14 w-14 rounded-xl bg-[#D4AF37]/10 flex items-center justify-center shrink-0">
                <exp.icon className="h-7 w-7 text-[#D4AF37]" />
              </div>
              <div>
                <h3 className="text-xl font-semibold text-white mb-2">{exp.title}</h3>
                <p className="text-slate-400 leading-relaxed text-sm">{exp.desc}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* 6. Closing CTA */}
      <section className="py-32 border-t border-white/5 text-center px-4">
        <h2 className="text-3xl font-bold text-white mb-6">Have Questions?</h2>
        <p className="text-slate-400 mb-8 max-w-md mx-auto">
          Whether you want to learn more about the platform, explore partnership opportunities, or need support, we are here to help.
        </p>
        <Link
          to="/contact"
          className="inline-flex items-center gap-2 bg-[#D4AF37] hover:bg-[#B8962E] text-black font-semibold py-3 px-8 rounded-lg transition-colors"
        >
          Contact Us <ArrowRight className="h-4 w-4" />
        </Link>
      </section>

    </div>
  );
}
