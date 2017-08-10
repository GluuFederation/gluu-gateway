(function () {
  'use strict';

  angular.module('KongGUI.pages.umaRs', [])
    .config(routeConfig);

  /** @ngInject */
  function routeConfig($stateProvider) {
    $stateProvider
      .state('umaRs', {
        url: '/umaRs',
        title: 'Kong UMA RS',
        templateUrl: 'app/pages/umaRs/umaRs.html',
        controller: 'UMARsController',
        controllerAs: '$ctrl',
        sidebarMeta: {
          icon: 'ion-locked',
          order: 3
        }
      });
  }
})();
