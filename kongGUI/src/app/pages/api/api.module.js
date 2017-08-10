(function () {
  'use strict';

  angular.module('KongGUI.pages.api', [])
    .config(routeConfig);

  /** @ngInject */
  function routeConfig($stateProvider) {
    $stateProvider
      .state('api', {
        url: '/api',
        title: 'Register Resource',
        templateUrl: 'app/pages/api/api.html',
        controller: 'APIController',
        controllerAs: '$ctrl',
        sidebarMeta: {
          icon: 'ion-navicon-round',
          order: 3
        }
      });
  }
})();
