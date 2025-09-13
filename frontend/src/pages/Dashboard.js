import React, { useState, useEffect } from 'react';
import { 
  TrendingUp, 
  DollarSign, 
  Gavel, 
  Users, 
  Activity,
  ArrowUpRight,
  ArrowDownRight,
  Clock,
  Zap
} from 'lucide-react';

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalMEVRecovered: 2450000,
    activeAuctions: 3,
    totalLPs: 1247,
    avgAuctionTime: 8.5,
    lvrReduction: 78,
    operatorUptime: 99.9
  });

  const [recentAuctions, setRecentAuctions] = useState([
    {
      id: '0x123...abc',
      pair: 'ETH/USDC',
      winner: '0x456...def',
      bid: 0.025,
      mevRecovered: 1250,
      time: '2 min ago',
      status: 'completed'
    },
    {
      id: '0x789...ghi',
      pair: 'WBTC/USDC',
      winner: '0x012...jkl',
      bid: 0.018,
      mevRecovered: 890,
      time: '5 min ago',
      status: 'completed'
    },
    {
      id: '0x345...mno',
      pair: 'ETH/USDC',
      winner: null,
      bid: null,
      mevRecovered: null,
      time: 'Active',
      status: 'active'
    }
  ]);

  const [priceFeeds, setPriceFeeds] = useState([
    { pair: 'ETH/USDC', price: 3245.67, change: 1.2, isStale: false },
    { pair: 'WBTC/USDC', price: 43250.89, change: -0.8, isStale: false },
    { pair: 'ETH/BTC', price: 0.075, change: 2.1, isStale: false },
    { pair: 'LINK/USDC', price: 12.34, change: 0.5, isStale: true }
  ]);

  const formatCurrency = (amount) => {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(amount);
  };

  const formatETH = (amount) => {
    return `${amount.toFixed(3)} ETH`;
  };

  const getStatusBadge = (status) => {
    switch (status) {
      case 'active':
        return <span className="badge badge-warning">Active</span>;
      case 'completed':
        return <span className="badge badge-success">Completed</span>;
      case 'failed':
        return <span className="badge badge-danger">Failed</span>;
      default:
        return <span className="badge badge-gray">Unknown</span>;
    }
  };

  const getChangeIcon = (change) => {
    if (change > 0) {
      return <ArrowUpRight className="h-4 w-4 text-success-500" />;
    } else if (change < 0) {
      return <ArrowDownRight className="h-4 w-4 text-danger-500" />;
    }
    return null;
  };

  const getChangeColor = (change) => {
    if (change > 0) return 'text-success-600';
    if (change < 0) return 'text-danger-600';
    return 'text-gray-600';
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="slide-in">
        <h1 className="text-3xl font-bold text-gray-900">Dashboard</h1>
        <p className="mt-2 text-gray-600">
          Monitor LVR auction performance and MEV recovery in real-time
        </p>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="card-hover bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total MEV Recovered</p>
              <p className="text-2xl font-bold text-gray-900">{formatCurrency(stats.totalMEVRecovered)}</p>
              <p className="text-sm text-success-600 flex items-center mt-1">
                <ArrowUpRight className="h-4 w-4 mr-1" />
                +12.5% this week
              </p>
            </div>
            <div className="h-12 w-12 bg-success-100 rounded-lg flex items-center justify-center">
              <DollarSign className="h-6 w-6 text-success-600" />
            </div>
          </div>
        </div>

        <div className="card-hover bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Active Auctions</p>
              <p className="text-2xl font-bold text-gray-900">{stats.activeAuctions}</p>
              <p className="text-sm text-primary-600 flex items-center mt-1">
                <Activity className="h-4 w-4 mr-1" />
                3 pools active
              </p>
            </div>
            <div className="h-12 w-12 bg-primary-100 rounded-lg flex items-center justify-center">
              <Gavel className="h-6 w-6 text-primary-600" />
            </div>
          </div>
        </div>

        <div className="card-hover bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">Total LPs</p>
              <p className="text-2xl font-bold text-gray-900">{stats.totalLPs.toLocaleString()}</p>
              <p className="text-sm text-success-600 flex items-center mt-1">
                <ArrowUpRight className="h-4 w-4 mr-1" />
                +47 this week
              </p>
            </div>
            <div className="h-12 w-12 bg-blue-100 rounded-lg flex items-center justify-center">
              <Users className="h-6 w-6 text-blue-600" />
            </div>
          </div>
        </div>

        <div className="card-hover bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">LVR Reduction</p>
              <p className="text-2xl font-bold text-gray-900">{stats.lvrReduction}%</p>
              <p className="text-sm text-success-600 flex items-center mt-1">
                <TrendingUp className="h-4 w-4 mr-1" />
                +5% improvement
              </p>
            </div>
            <div className="h-12 w-12 bg-purple-100 rounded-lg flex items-center justify-center">
              <TrendingUp className="h-6 w-6 text-purple-600" />
            </div>
          </div>
        </div>
      </div>

      {/* Recent Auctions */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Recent Auctions</h2>
          <p className="text-sm text-gray-600">Latest auction activity and results</p>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="table-header">Auction ID</th>
                <th className="table-header">Pair</th>
                <th className="table-header">Winner</th>
                <th className="table-header">Bid</th>
                <th className="table-header">MEV Recovered</th>
                <th className="table-header">Time</th>
                <th className="table-header">Status</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {recentAuctions.map((auction) => (
                <tr key={auction.id} className="hover:bg-gray-50">
                  <td className="table-cell font-mono text-sm">{auction.id}</td>
                  <td className="table-cell">
                    <span className="font-medium">{auction.pair}</span>
                  </td>
                  <td className="table-cell">
                    {auction.winner ? (
                      <span className="font-mono text-sm">{auction.winner}</span>
                    ) : (
                      <span className="text-gray-400">Pending</span>
                    )}
                  </td>
                  <td className="table-cell">
                    {auction.bid ? formatETH(auction.bid) : '-'}
                  </td>
                  <td className="table-cell">
                    {auction.mevRecovered ? formatCurrency(auction.mevRecovered) : '-'}
                  </td>
                  <td className="table-cell">
                    <div className="flex items-center text-sm text-gray-600">
                      <Clock className="h-4 w-4 mr-1" />
                      {auction.time}
                    </div>
                  </td>
                  <td className="table-cell">
                    {getStatusBadge(auction.status)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Price Feeds */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200">
        <div className="px-6 py-4 border-b border-gray-200">
          <h2 className="text-lg font-semibold text-gray-900">Price Feeds</h2>
          <p className="text-sm text-gray-600">Real-time price data for LVR detection</p>
        </div>
        <div className="p-6">
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            {priceFeeds.map((feed) => (
              <div key={feed.pair} className="border border-gray-200 rounded-lg p-4">
                <div className="flex items-center justify-between mb-2">
                  <span className="font-medium text-gray-900">{feed.pair}</span>
                  {feed.isStale && (
                    <span className="badge badge-warning">Stale</span>
                  )}
                </div>
                <div className="flex items-center justify-between">
                  <span className="text-2xl font-bold text-gray-900">
                    ${feed.price.toLocaleString()}
                  </span>
                  <div className={`flex items-center ${getChangeColor(feed.change)}`}>
                    {getChangeIcon(feed.change)}
                    <span className="text-sm font-medium ml-1">
                      {feed.change > 0 ? '+' : ''}{feed.change}%
                    </span>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* System Status */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">System Health</h3>
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Operator Uptime</span>
              <span className="text-sm font-medium text-success-600">{stats.operatorUptime}%</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Average Auction Time</span>
              <span className="text-sm font-medium text-gray-900">{stats.avgAuctionTime}s</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Price Feed Status</span>
              <span className="text-sm font-medium text-warning-600">3/4 Active</span>
            </div>
          </div>
        </div>

        <div className="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>
          <div className="space-y-3">
            <button className="w-full btn-primary flex items-center justify-center">
              <Zap className="h-4 w-4 mr-2" />
              Start New Auction
            </button>
            <button className="w-full btn-secondary flex items-center justify-center">
              <Activity className="h-4 w-4 mr-2" />
              View All Auctions
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;
