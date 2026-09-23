import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/live_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/call_provider.dart';
import 'providers/social_provider.dart';
import 'providers/messaging_provider.dart';
import 'providers/vip_provider.dart';
import 'providers/game_provider.dart';
import 'providers/host_agency_provider.dart';
import 'providers/seller_provider.dart';
import 'providers/notification_provider.dart';
import 'features/coin_marketplace/providers/p2p_provider.dart';
import 'features/coin_marketplace/providers/escrow_provider.dart';
import 'providers/live_party_provider.dart';
import 'providers/store_provider.dart';
import 'providers/svip_provider.dart';
import 'providers/noble_provider.dart';
import 'providers/mystery_provider.dart';
import 'providers/region_provider.dart';
import 'providers/coin_agency_provider.dart';
import 'providers/bd_center_provider.dart';
import 'providers/cumulative_recharge_provider.dart';
import 'providers/vip_honor_provider.dart';
import 'providers/agency_provider.dart';
import 'providers/live_host_provider.dart';
import 'providers/recharge_agency_provider.dart';
import 'providers/merchant_provider.dart';
import 'providers/lucky_gift_provider.dart';
import 'providers/wallet_details_provider.dart';
import 'providers/privacy_settings_provider.dart';
import 'providers/cp_ranking_provider.dart';
import 'providers/emoji_reaction_provider.dart';
import 'providers/live_gift_provider.dart';
import 'providers/backpack_provider.dart';
import 'providers/support_provider.dart';
import 'core/config/app_config.dart';
import 'core/repositories/backend_repository.dart';
import 'features/auth/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Authoritative Centralized App Configuration
  AppConfig.initialize(
    environment: kReleaseMode ? AppEnvironment.production : AppEnvironment.development,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const LiveStreamApp());
}

class LiveStreamApp extends StatelessWidget {
  const LiveStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: BackendRepository.instance),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LiveProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => CallProvider()),
        ChangeNotifierProvider(create: (_) => SocialProvider()),
        ChangeNotifierProvider(create: (_) => MessagingProvider()),
        ChangeNotifierProvider(create: (_) => VipProvider()),
        ChangeNotifierProvider(create: (_) => GameProvider()),
        ChangeNotifierProvider(create: (_) => HostAgencyProvider()),
        ChangeNotifierProvider(create: (_) => SellerProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => P2PProvider()),
        ChangeNotifierProvider(create: (_) => EscrowProvider()),
        ChangeNotifierProvider(create: (_) => LivePartyProvider()),
        ChangeNotifierProvider(create: (_) => StoreProvider()),
        ChangeNotifierProvider(create: (_) => BackpackProvider()),
        ChangeNotifierProvider(create: (_) => SVIPProvider()),
        ChangeNotifierProvider(create: (_) => MysteryProvider()),
        ChangeNotifierProvider(create: (_) => NobleProvider()),
        ChangeNotifierProvider(create: (_) => RegionProvider()),
        ChangeNotifierProvider(create: (_) => CoinAgencyProvider()),
        ChangeNotifierProvider(create: (_) => BDCenterProvider()),
        ChangeNotifierProvider(create: (_) => CumulativeRechargeProvider()),
        ChangeNotifierProvider(create: (_) => VIPHonorProvider()),
        ChangeNotifierProvider(create: (_) => AgencyProvider()),
        ChangeNotifierProvider(create: (_) => LiveHostProvider()),
        ChangeNotifierProvider(create: (_) => RechargeAgencyProvider()),
        ChangeNotifierProvider(create: (_) => MerchantProvider()),
        ChangeNotifierProvider(create: (_) => LuckyGiftProvider()),
        ChangeNotifierProvider(create: (_) => WalletDetailsProvider()),
        ChangeNotifierProvider(create: (_) => PrivacySettingsProvider()),
        ChangeNotifierProvider(create: (_) => CpRankingProvider()),
        ChangeNotifierProvider(create: (_) => EmojiReactionProvider()),
        ChangeNotifierProvider(create: (_) => LiveGiftProvider()),
        ChangeNotifierProvider(create: (_) => SupportProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return ScreenUtilInit(
            designSize: const Size(375, 812),
            minTextAdapt: true,
            builder: (context, child) {
              return MaterialApp(
                title: 'ZeParty',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                home: const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
