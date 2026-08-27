// ============================================================
// ZeParty Public — Contact Page (JSX)
// ============================================================

import React, { useState, useEffect } from 'react';
import { Mail, LifeBuoy, Briefcase, CheckCircle2 } from 'lucide-react';

export function ContactPage() {
  useEffect(() => {
    document.title = 'Contact ZeParty';
  }, []);

  const [formData, setFormData] = useState({
    name: '',
    email: '',
    subject: '',
    message: ''
  });
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [success, setSuccess] = useState(false);
  const [errors, setErrors] = useState({});

  const validate = () => {
    const newErrors = {};
    if (!formData.name.trim()) newErrors.name = 'Name is required';
    if (!formData.email.trim()) {
      newErrors.email = 'Email is required';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      newErrors.email = 'Invalid email address';
    }
    if (!formData.subject.trim()) newErrors.subject = 'Subject is required';
    if (!formData.message.trim()) newErrors.message = 'Message is required';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (validate()) {
      setIsSubmitting(true);
      // Simulate API call
      setTimeout(() => {
        setIsSubmitting(false);
        setSuccess(true);
        setFormData({ name: '', email: '', subject: '', message: '' });
      }, 1000);
    }
  };

  return (
    <div className="flex flex-col w-full overflow-hidden">
      
      {/* 1. Hero */}
      <section className="relative pt-32 pb-16 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto w-full text-center">
        <h1 className="text-4xl md:text-6xl font-bold text-white mb-6">
          Get in Touch
        </h1>
        <p className="text-lg text-slate-400 max-w-2xl mx-auto">
          Have a question, suggestion, or need assistance? We'd love to hear from you.
        </p>
      </section>

      {/* 2. Contact Information Cards */}
      <section className="py-12 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
        <div className="grid md:grid-cols-3 gap-6">
          {[
            { icon: Mail, title: 'Email', desc: 'General inquiries and information.', detail: 'hello@zeparty.app' },
            { icon: LifeBuoy, title: 'Support', desc: 'Help with your account or platform issues.', detail: 'support@zeparty.app' },
            { icon: Briefcase, title: 'Business', desc: 'For partnerships and agency inquiries.', detail: 'partners@zeparty.app' },
          ].map((info, i) => (
            <div key={i} className="bg-[#0a0a0a] border border-white/5 rounded-2xl p-8 text-center">
              <div className="mx-auto h-12 w-12 rounded-full bg-[#D4AF37]/10 flex items-center justify-center mb-4 text-[#D4AF37]">
                <info.icon className="h-6 w-6" />
              </div>
              <h3 className="text-white font-semibold text-lg mb-2">{info.title}</h3>
              <p className="text-slate-400 text-sm mb-4">{info.desc}</p>
              <p className="text-[#D4AF37] font-medium text-sm">{info.detail}</p>
            </div>
          ))}
        </div>
      </section>

      {/* 3. Form & FAQ Section */}
      <section className="py-16 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full mb-16">
        <div className="grid lg:grid-cols-2 gap-16">
          
          {/* Contact Form */}
          <div className="bg-[#111] border border-white/5 rounded-3xl p-8 md:p-10">
            <h2 className="text-2xl font-bold text-white mb-6">Send us a message</h2>
            
            {success ? (
              <div className="bg-emerald-500/10 border border-emerald-500/20 rounded-xl p-8 text-center">
                <CheckCircle2 className="h-12 w-12 text-emerald-400 mx-auto mb-4" />
                <h3 className="text-emerald-400 font-semibold text-lg mb-2">Message Sent Successfully</h3>
                <p className="text-slate-400 text-sm mb-6">Thank you. Your message has been received and our team will get back to you shortly.</p>
                <button
                  onClick={() => setSuccess(false)}
                  className="text-sm font-medium text-[#D4AF37] hover:text-white transition-colors"
                >
                  Send another message
                </button>
              </div>
            ) : (
              <form onSubmit={handleSubmit} className="space-y-5">
                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-1.5">Full Name</label>
                  <input
                    type="text"
                    value={formData.name}
                    onChange={(e) => { setFormData({...formData, name: e.target.value}); setErrors({...errors, name: ''}); }}
                    className={`w-full bg-[#050505] border ${errors.name ? 'border-red-500/50' : 'border-white/10'} rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#D4AF37]/50 focus:ring-1 focus:ring-[#D4AF37]/50 transition-colors`}
                    placeholder="John Doe"
                  />
                  {errors.name && <p className="mt-1 text-xs text-red-400">{errors.name}</p>}
                </div>

                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-1.5">Email Address</label>
                  <input
                    type="email"
                    value={formData.email}
                    onChange={(e) => { setFormData({...formData, email: e.target.value}); setErrors({...errors, email: ''}); }}
                    className={`w-full bg-[#050505] border ${errors.email ? 'border-red-500/50' : 'border-white/10'} rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#D4AF37]/50 focus:ring-1 focus:ring-[#D4AF37]/50 transition-colors`}
                    placeholder="john@example.com"
                  />
                  {errors.email && <p className="mt-1 text-xs text-red-400">{errors.email}</p>}
                </div>

                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-1.5">Subject</label>
                  <input
                    type="text"
                    value={formData.subject}
                    onChange={(e) => { setFormData({...formData, subject: e.target.value}); setErrors({...errors, subject: ''}); }}
                    className={`w-full bg-[#050505] border ${errors.subject ? 'border-red-500/50' : 'border-white/10'} rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#D4AF37]/50 focus:ring-1 focus:ring-[#D4AF37]/50 transition-colors`}
                    placeholder="How can we help?"
                  />
                  {errors.subject && <p className="mt-1 text-xs text-red-400">{errors.subject}</p>}
                </div>

                <div>
                  <label className="block text-sm font-medium text-slate-300 mb-1.5">Message</label>
                  <textarea
                    value={formData.message}
                    onChange={(e) => { setFormData({...formData, message: e.target.value}); setErrors({...errors, message: ''}); }}
                    rows={5}
                    className={`w-full bg-[#050505] border ${errors.message ? 'border-red-500/50' : 'border-white/10'} rounded-lg px-4 py-3 text-white focus:outline-none focus:border-[#D4AF37]/50 focus:ring-1 focus:ring-[#D4AF37]/50 transition-colors resize-none`}
                    placeholder="Type your message here..."
                  />
                  {errors.message && <p className="mt-1 text-xs text-red-400">{errors.message}</p>}
                </div>

                <button
                  type="submit"
                  disabled={isSubmitting}
                  className="w-full bg-[#D4AF37] hover:bg-[#B8962E] text-black font-semibold py-3.5 px-4 rounded-lg transition-colors disabled:opacity-50 flex justify-center items-center"
                >
                  {isSubmitting ? (
                    <div className="h-5 w-5 border-2 border-black/20 border-t-black rounded-full animate-spin" />
                  ) : (
                    'Send Message'
                  )}
                </button>
              </form>
            )}
          </div>

          {/* FAQ */}
          <div>
            <h2 className="text-2xl font-bold text-white mb-8">Frequently Asked Questions</h2>
            <div className="space-y-6">
              {[
                { q: 'How can I contact ZeParty?', a: 'The best way to reach us is by using the contact form on this page or emailing our support team directly.' },
                { q: 'How can I get help with the platform?', a: 'For technical issues or account inquiries, please select "Support" as your subject so we can route your message to the right team.' },
                { q: 'How can I provide feedback?', a: 'We love hearing from our community! Feel free to send us your thoughts and suggestions via the contact form.' },
                { q: 'How can I contact ZeParty for business inquiries?', a: 'For agency applications, host representation, or general business partnerships, please contact our business team at partners@zeparty.app.' }
              ].map((faq, i) => (
                <div key={i} className="pb-6 border-b border-white/5 last:border-0">
                  <h3 className="text-white font-semibold mb-2">{faq.q}</h3>
                  <p className="text-slate-400 text-sm leading-relaxed">{faq.a}</p>
                </div>
              ))}
            </div>
          </div>
          
        </div>
      </section>

    </div>
  );
}
