# SPRINT - App Mobile MikroTik Manager

## AUDIT DES PAGES

### PAGES FONCTIONNELLES (testees et confirmees)
| # | Page | Fichier | Statut |
|---|------|---------|--------|
| 1 | Login | screens/auth/login_screen.dart | OK |
| 2 | Register | screens/auth/register_screen.dart | OK |
| 3 | Dashboard | screens/dashboard/dashboard_screen.dart | OK - KPI, top sites, routeurs |
| 4 | Rapports | screens/reports/reports_screen.dart | OK - Revenue, sales mix, top vendors, filtre periode |
| 5 | Automatisation | screens/automatisation/automatisation_screen.dart | OK - Liste configs, toggle on/off |
| 6 | Menu Plus | screens/more/more_screen.dart | OK - Grille navigation |
| 7 | Sites Liste | screens/sites/sites_list_screen.dart | OK - Filtre par statut ajoute |
| 8 | Site Detail | screens/sites/site_detail_screen.dart | OK - Parsing data.* corrige |
| 9 | Mikhmon Hub | screens/mikhmon/mikhmon_hub_screen.dart | OK - SiteSelector |
| 10 | Mikhmon Dashboard | screens/mikhmon/mikhmon_dashboard_screen.dart | OK - Parsing corrige |
| 11 | Hotspot Users | screens/mikhmon/hotspot_users_screen.dart | OK - Backend action ajoutee |
| 12 | Hotspot Active | screens/mikhmon/hotspot_active_screen.dart | OK - Backend response corrigee |
| 13 | Hotspot Servers | screens/mikhmon/hotspot_servers_screen.dart | OK |
| 14 | DHCP Leases | screens/mikhmon/dhcp_leases_screen.dart | OK - Backend action ajoutee |
| 15 | Traffic | screens/mikhmon/traffic_screen.dart | OK - Parsing data.rx/tx corrige |
| 16 | Flash Sale | screens/mikhmon/flash_sale_screen.dart | OK - CORS + postForm |
| 17 | Tickets Liste | screens/tickets/tickets_list_screen.dart | OK - Filtre client-side |
| 18 | Profils Liste | screens/profiles/profiles_list_screen.dart | OK |
| 19 | Ventes | screens/sales/sales_screen.dart | OK - GET handler + filtre periode |
| 20 | Points de Vente | screens/points/points_list_screen.dart | OK - Parsing data corrige |
| 21 | Notifications | screens/notifications/notifications_screen.dart | OK - Actions corrigees |
| 22 | Tunnels VPN | screens/tunnels/tunnels_screen.dart | OK - Parsing peers corrige |
| 23 | Utilisateurs | screens/users/users_list_screen.dart | OK |

### PAGES A TESTER (pas de bug connu, dependant du contexte)
| # | Page | Fichier | API |
|---|------|---------|-----|
| 24 | Site Form (Creer/Edit) | screens/sites/site_form_screen.dart | /api/full-setup.php |
| 25 | Quick Print | screens/mikhmon/quick_print_screen.dart | /api/generate-tickets.php |
| 26 | Generate Tickets | screens/tickets/generate_tickets_screen.dart | /api/generate-tickets.php |
| 27 | Point Form | screens/points/point_form_screen.dart | /api/points.php |
| 28 | User Form | screens/users/user_form_screen.dart | /api/users-bulk.php |
| 29 | User Features | screens/users/user_features_screen.dart | /api/users-bulk.php |
| 30 | Decouverte | screens/discovery/discovery_screen.dart | /api/router-test.php |

---

## TACHES DU SPRINT

### PHASE 1 : Fix Backend (serveur tikadmin.com)
- [x] 1.1 Fix mikhmon-stats.php : remplacer requireLogin() par isLoggedIn() + JSON 401
- [x] 1.2 CORS etendu a /mikhmon/ dans bootstrap.php pour flash-sale
- [x] 1.3 Ajout actions manquantes dans hotspot.php (users, vouchers, hosts, reboot)
- [x] 1.4 Ajout tunnel VPN resolution dans hotspot.php
- [x] 1.5 Ajout GET handler dans sync-sales.php pour liste des ventes
- [x] 1.6 Wrap traffic.php response avec data.rx/tx standard
- [ ] 1.7 Push et deployer

### PHASE 2 : Fix parsing reponses API dans l'app mobile
- [x] 2.1 SitesListScreen : filtre statut ajoute
- [x] 2.2 SiteDetailScreen : unwrap data + remap revenue/sold/available
- [x] 2.3 MikhmonDashboardScreen : remap active.count, users.count, sales_today.revenue
- [x] 2.4 HotspotUsersScreen : OK (backend action ajoutee)
- [x] 2.5 HotspotActiveScreen : OK (backend retourne 'active' au lieu de 'sessions')
- [x] 2.6 HotspotServersScreen : OK (parsing deja correct)
- [x] 2.7 DhcpLeasesScreen : OK (backend action ajoutee)
- [x] 2.8 TrafficScreen : unwrap data + utilise rx/tx
- [x] 2.9 FlashSaleScreen : change postForm + CORS backend
- [x] 2.10 TicketsListScreen : filtre client-side + backend vouchers action
- [x] 2.11 ProfilesListScreen : OK (parsing deja correct)
- [x] 2.12 SalesScreen : GET handler backend + filtre periode client
- [x] 2.13 PointsListScreen : change data['points'] -> data['data']
- [x] 2.14 NotificationsScreen : action=list, read/read_all, parsing data.items
- [x] 2.15 TunnelsScreen : change tunnels -> peers
- [x] 2.16 UsersListScreen : OK (parsing deja correct)

### PHASE 3 : Fix filtres et interactions
- [x] 3.1 Rapports : filtre periode deja fonctionnel
- [x] 3.2 Tickets : filtre par statut (client-side)
- [x] 3.3 Ventes : filtre par periode (today/week/month/all) + total revenue
- [x] 3.4 Sites : filtre par statut (tous/configure/nouveau/maintenance)

### PHASE 4 : Test et polish
- [ ] 4.1 Tester toutes les pages avec donnees reelles
- [ ] 4.2 Fix overflow/layout restants
- [ ] 4.3 Commit et push final
- [ ] 4.4 Build APK release

---

## SERVICES ET LEURS ENDPOINTS

| Service | Methode | Endpoint | Response wrapping |
|---------|---------|----------|-------------------|
| KpiService | fetchRevenue | /api/kpi/revenue.php | {success, data: {total, count, variation_pct, avg_basket}} |
| KpiService | fetchActivationRate | /api/kpi/activation-rate.php | {success, data: {activation_rate, total_sold}} |
| KpiService | fetchSalesMix | /api/kpi/sales-mix.php | {success, data: [{profile_name, count, percent}]} |
| KpiService | fetchTopSites | /api/kpi/top-sites.php | {success, data: [{site_name, total, count}]} |
| KpiService | fetchTopVendors | /api/kpi/top-vendors.php | {success, data: [{site_name, total, count}]} |
| SiteService | fetchAll | /api/sites-list.php | {success, sites: [...]} |
| SiteService | fetchStats | /api/site-stats.php | {success, data: {revenue, sold, available}} |
| MikhmonService | fetchDashboard | /api/mikhmon-stats.php | {success, connected, users, active, sales_today, ...} |
| MikhmonService | fetchHotspotUsers | /api/hotspot.php?action=users | {success, users: [...]} |
| MikhmonService | fetchActiveUsers | /api/hotspot.php?action=active | {success, active: [...]} |
| MikhmonService | fetchHosts | /api/hotspot.php?action=hosts | {success, hosts: [...]} |
| MikhmonService | fetchServers | /api/hotspot-servers.php | {success, servers: [...]} |
| MikhmonService | fetchProfiles | /api/mikhmon-profiles.php | {success, profiles: [...]} |
| MikhmonService | fetchTraffic | /api/traffic.php | {success, data: {rx, tx}} |
| MikhmonService | flashSale | /mikhmon/flash-sale.php | {success, code, password, autologin_url} |
| TicketService | fetchTickets | /api/hotspot.php?action=vouchers | {success, vouchers: [...]} |
| TicketService | generateBatch | /api/generate-tickets.php | {success, generated, synced} |
| SalesScreen | load | /api/sync-sales.php (GET) | {success, sales: [...]} |
| PointServiceApi | fetchBySite | /api/points.php | {success, data: [...]} |
| NotifServiceApi | fetchAll | /api/notifications.php?action=list | {success, data: {items: [...]}} |
| TunnelService | fetchAll | /api/health/vpn.php | {success, peers: [...]} |
| UsersService | fetchAll | /api/users-bulk.php?action=list | {success, users: [...]} |
| AutoGenService | fetchConfigs | /api/auto-generate-config.php | {success, data: [...]} |
