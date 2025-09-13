import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Gavel, 
  DollarSign, 
  History, 
  Activity, 
  TrendingUp,
  ChevronRight
} from 'lucide-react';

const Sidebar = () => {
  const location = useLocation();

  const navigation = [
    { name: 'Dashboard', href: '/', icon: LayoutDashboard },
    { name: 'Active Auctions', href: '/auctions', icon: Gavel },
    { name: 'LP Rewards', href: '/lp-rewards', icon: DollarSign },
    { name: 'Auction History', href: '/auction-history', icon: History },
    { name: 'Operator Status', href: '/operator-status', icon: Activity },
    { name: 'Price Feeds', href: '/price-feeds', icon: TrendingUp },
  ];

  const isActive = (href) => {
    if (href === '/') {
      return location.pathname === '/';
    }
    return location.pathname.startsWith(href);
  };

  return (
    <div className="fixed inset-y-0 left-0 z-50 w-64 bg-white shadow-lg border-r border-gray-200">
      <div className="flex flex-col h-full">
        {/* Sidebar header */}
        <div className="flex items-center justify-center h-16 px-4 border-b border-gray-200">
          <div className="flex items-center space-x-3">
            <div className="h-8 w-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
              <span className="text-white font-bold text-sm">LVR</span>
            </div>
            <span className="text-lg font-semibold text-gray-900">Auction Hook</span>
          </div>
        </div>

        {/* Navigation */}
        <nav className="flex-1 px-4 py-6 space-y-2 overflow-y-auto">
          {navigation.map((item) => {
            const Icon = item.icon;
            const active = isActive(item.href);
            
            return (
              <Link
                key={item.name}
                to={item.href}
                className={`
                  group flex items-center justify-between px-3 py-2 text-sm font-medium rounded-lg transition-all duration-200
                  ${active
                    ? 'bg-primary-50 text-primary-700 border-r-2 border-primary-500'
                    : 'text-gray-600 hover:bg-gray-50 hover:text-gray-900'
                  }
                `}
              >
                <div className="flex items-center space-x-3">
                  <Icon 
                    className={`h-5 w-5 ${
                      active ? 'text-primary-500' : 'text-gray-400 group-hover:text-gray-500'
                    }`} 
                  />
                  <span>{item.name}</span>
                </div>
                {active && (
                  <ChevronRight className="h-4 w-4 text-primary-500" />
                )}
              </Link>
            );
          })}
        </nav>

        {/* Sidebar footer */}
        <div className="px-4 py-4 border-t border-gray-200">
          <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg p-4">
            <div className="flex items-center space-x-3">
              <div className="h-8 w-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                <span className="text-white font-bold text-xs">⚡</span>
              </div>
              <div>
                <p className="text-sm font-medium text-gray-900">MEV Recovery</p>
                <p className="text-xs text-gray-600">$2.4M recovered</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Sidebar;
