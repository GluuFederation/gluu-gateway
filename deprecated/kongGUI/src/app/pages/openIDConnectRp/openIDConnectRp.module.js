(function () {
  'use strict';

  angular.module('KongGUI.pages.openIDConnectRp', [])
    .config(routeConfig);

  /** @ngInject */
  function routeConfig($stateProvider) {
    $stateProvider
      .state('openIDConnectRp', {
        url: '/openIDConnectRp',
        title: 'Kong OpenID',
        templateUrl: 'app/pages/openIDConnectRp/openIDConnectRp.html',
        controller: 'OpenIDConnectRpController',
        controllerAs: '$ctrl',
        sidebarMeta: {
          icon: 'ion-locked',
          order: 3
        }
      });
  }
})();
