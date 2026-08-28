// ============================================================
// ZeParty Admin Portal — React Error Boundary Component (JSX)
// Catches page errors gracefully and auto-resets on navigation
// ============================================================

import React from 'react';
import { AlertCircle, RefreshCw } from 'lucide-react';
import { Button } from '../ui/Button';

export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('ZeParty Page Render Error:', error, errorInfo);
  }

  componentDidUpdate(prevProps) {
    if (prevProps.locationKey !== this.props.locationKey && this.state.hasError) {
      this.setState({ hasError: false, error: null });
    }
  }

  handleReload = () => {
    this.setState({ hasError: false, error: null });
    window.location.reload();
  };

  render() {
    if (this.state.hasError) {
      return (
        <div className="p-8 rounded-2xl bg-slate-900 border border-slate-800 text-center space-y-4 max-w-xl mx-auto my-12 shadow-2xl">
          <div className="w-14 h-14 rounded-full bg-rose-500/20 text-rose-400 flex items-center justify-center mx-auto">
            <AlertCircle className="h-8 w-8" />
          </div>
          <h2 className="text-xl font-bold text-white">Something Went Wrong Rendering This Page</h2>
          {this.state.error && (
            <div className="p-3 rounded-lg bg-rose-950/60 border border-rose-800 text-rose-300 font-mono text-xs text-left overflow-x-auto max-h-32">
              {this.state.error.toString()}
            </div>
          )}
          <p className="text-xs text-slate-400">
            A temporary component error occurred. Clicking reload will restore full application state.
          </p>
          <div className="pt-2 flex justify-center gap-3">
            <Button variant="primary" size="sm" onClick={this.handleReload}>
              <RefreshCw className="h-4 w-4 mr-1.5" /> Refresh Page Content
            </Button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
