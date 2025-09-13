import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import './App.css';

// Components
import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';

// Pages
import Dashboard from './pages/Dashboard';
import Auctions from './pages/Auctions';
import LPRewards from './pages/LPRewards';
import AuctionHistory from './pages/AuctionHistory';
import OperatorStatus from './pages/OperatorStatus';
import PriceFeeds from './pages/PriceFeeds';

function App() {
  return (
    <Router>
      <div className="min-h-screen bg-gray-50">
        <Navbar />
        
        <div className="flex">
          <Sidebar />
          
          <main className="flex-1 p-6 ml-64">
            <Routes>
              <Route path="/" element={<Dashboard />} />
              <Route path="/auctions" element={<Auctions />} />
              <Route path="/lp-rewards" element={<LPRewards />} />
              <Route path="/auction-history" element={<AuctionHistory />} />
              <Route path="/operator-status" element={<OperatorStatus />} />
              <Route path="/price-feeds" element={<PriceFeeds />} />
            </Routes>
          </main>
        </div>
        
        <Toaster
          position="top-right"
          toastOptions={{
            duration: 4000,
            style: {
              background: '#363636',
              color: '#fff',
            },
            success: {
              duration: 3000,
              iconTheme: {
                primary: '#22c55e',
                secondary: '#fff',
              },
            },
            error: {
              duration: 5000,
              iconTheme: {
                primary: '#ef4444',
                secondary: '#fff',
              },
            },
          }}
        />
      </div>
    </Router>
  );
}

export default App;
