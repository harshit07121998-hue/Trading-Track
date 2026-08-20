import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/open_positions_screen.dart';
import 'screens/closed_trades_screen.dart';
import 'screens/xirr_screen.dart';
import 'screens/backup_restore_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TradingTrackerApp());
}

class TradingTrackerApp extends StatelessWidget {
  const TradingTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const RootShell(),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _navigate(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onNavigate: _navigate),
      const OpenPositionsScreen(),
      const ClosedTradesScreen(),
      const XirrScreen(),
      MoreScreen(onNavigate: _navigate),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: _navigate,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.description_outlined), label: 'Open Positions'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Closed Trades'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'XIRR'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
