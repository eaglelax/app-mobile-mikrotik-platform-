class AppConstants {
  static const String appName = 'MikroTik Manager';
  static const String currency = 'XOF';

  static const Map<String, String> siteStatuses = {
    'nouveau': 'Nouveau',
    'configure': 'Configuré',
    'maintenance': 'Maintenance',
    'inactif': 'Inactif',
  };

  static const Map<String, String> ticketStatuses = {
    'available': 'Disponible',
    'used': 'Utilisé',
    'expired': 'Expiré',
    'cancelled': 'Annulé',
  };

  static const Map<String, String> validityUnits = {
    'minutes': 'Minutes',
    'hours': 'Heures',
    'days': 'Jours',
    'weeks': 'Semaines',
    'months': 'Mois',
  };

  static const Map<String, String> siteActivities = {
    'hotel': 'Hôtel',
    'restaurant': 'Restaurant',
    'cafe': 'Café',
    'office': 'Bureau',
    'school': 'École',
    'hospital': 'Hôpital',
    'other': 'Autre',
  };
}
