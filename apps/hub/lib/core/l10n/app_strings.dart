enum AppLocale { ptBr, en }

class AppStrings {
  final AppLocale locale;
  const AppStrings(this.locale);

  bool get isPt => locale == AppLocale.ptBr;

  String get appTitle => 'TesterLoop Hub';
  String get discover => isPt ? 'Descobrir' : 'Discover';
  String get myTests => isPt ? 'Meus Testes' : 'My Tests';
  String get wallet => isPt ? 'Carteira' : 'Wallet';
  String get myApps => isPt ? 'Meus Apps' : 'My Apps';
  String get settings => isPt ? 'Ajustes' : 'Settings';

  String get featured => 'Featured';
  String get recent => isPt ? 'Recentes' : 'Recent';
  String get almostFull => isPt ? 'Quase completos' : 'Almost full';
  String get searchApps =>
      isPt ? 'Buscar app ou package...' : 'Search app or package...';

  String get wantToTest => isPt ? 'Quero testar' : 'Join test';
  String get alreadyEnrolled => isPt ? 'Já inscrito' : 'Already enrolled';
  String get activeTestsTitle =>
      isPt ? 'Testes em andamento' : 'Active closed tests';
  String get noTestsYet => isPt
      ? 'Você ainda não está testando nenhum app.'
      : 'You are not testing any apps yet.';
  String get browseDiscover =>
      isPt ? 'Explorar campanhas' : 'Browse campaigns';

  String get availablePoints => isPt ? 'Disponível' : 'Available';
  String get pendingPoints => isPt ? 'Pendente (em custódia)' : 'Pending (escrow)';
  String get pointsExpirationNote => isPt
      ? 'Pontos disponíveis expiram após 360 dias sem atividade.'
      : 'Available points expire after 360 days of inactivity.';

  String get publishCampaign => isPt ? 'Publicar campanha (120 pts)' : 'Publish campaign (120 pts)';
  String get newApp => isPt ? 'Novo app' : 'New app';
  String get generateReport =>
      isPt ? 'Relatório Play Console' : 'Play Console report';

  String get communityTitle => isPt
      ? 'Comunidade de apoio (r/AndroidAppTesters)'
      : 'Support community (r/AndroidAppTesters)';
  String get deleteAccount => isPt ? 'Excluir conta' : 'Delete account';
}
